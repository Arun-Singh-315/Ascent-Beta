import '../../app/theme/app_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_logo.dart';

// ---------------------------------------------------------------------------
// Onboarding State Model & Provider
// ---------------------------------------------------------------------------

class OnboardingDraftState {
  final int stepIndex; // 0: Vision, 1: Sanctuary Setup, 2: Sealed
  final String name;
  final String targetRole; // Used for focus / intention
  final List<String> targetCompanies; // Kept for backward compatibility
  final String companionName; // 'Aria' or 'Riya'
  final DayThemePreset themePreset;
  final String focusArea;
  final DateTime? interviewDate;
  final DateTime? dateOfBirth;
  final bool isJustPreparing;
  final int weeklyHours;
  final bool isSubmitting;

  const OnboardingDraftState({
    this.stepIndex = 0,
    this.name = '',
    this.targetRole = '',
    this.targetCompanies = const [],
    this.companionName = 'Aria',
    this.themePreset = DayThemePreset.merlotLinen,
    this.focusArea = 'Inner Peace',
    this.interviewDate,
    this.dateOfBirth,
    this.isJustPreparing = true,
    this.weeklyHours = 12,
    this.isSubmitting = false,
  });

  OnboardingDraftState copyWith({
    int? stepIndex,
    String? name,
    String? targetRole,
    List<String>? targetCompanies,
    String? companionName,
    DayThemePreset? themePreset,
    String? focusArea,
    DateTime? interviewDate,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    bool? isJustPreparing,
    int? weeklyHours,
    bool? isSubmitting,
  }) {
    return OnboardingDraftState(
      stepIndex: stepIndex ?? this.stepIndex,
      name: name ?? this.name,
      targetRole: targetRole ?? this.targetRole,
      targetCompanies: targetCompanies ?? this.targetCompanies,
      companionName: companionName ?? this.companionName,
      themePreset: themePreset ?? this.themePreset,
      focusArea: focusArea ?? this.focusArea,
      interviewDate: interviewDate ?? this.interviewDate,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      isJustPreparing: isJustPreparing ?? this.isJustPreparing,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingDraftState> {
  @override
  OnboardingDraftState build() {
    final currentTheme = ref.read(dayThemePresetProvider);
    final currentAssistant = ref.read(assistantNameProvider);
    return OnboardingDraftState(
      companionName: currentAssistant.isNotEmpty ? currentAssistant : 'Aria',
      themePreset: currentTheme,
    );
  }

  void setStep(int index) => state = state.copyWith(stepIndex: index);

  void updateNameRole(String name, String role) =>
      state = state.copyWith(name: name, targetRole: role);

  void setDateOfBirth(DateTime? dob) {
    if (dob == null) {
      state = state.copyWith(clearDateOfBirth: true);
    } else {
      state = state.copyWith(dateOfBirth: dob);
    }
  }

  void setCompanion(String companion) {
    state = state.copyWith(companionName: companion);
    ref.read(assistantNameProvider.notifier).setName(companion);
  }

  void setThemePreset(DayThemePreset preset) {
    state = state.copyWith(themePreset: preset);
    ref.read(dayThemePresetProvider.notifier).setPreset(preset);
  }

  void setFocusArea(String focus) {
    state = state.copyWith(focusArea: focus, targetRole: focus);
  }

  void toggleCompany(String company) {
    final list = List<String>.from(state.targetCompanies);
    if (list.contains(company)) {
      list.remove(company);
    } else {
      list.add(company);
    }
    state = state.copyWith(targetCompanies: list);
  }

  void addCustomCompany(String company) {
    final trimmed = company.trim();
    if (trimmed.isEmpty) return;
    final list = List<String>.from(state.targetCompanies);
    if (!list.contains(trimmed)) {
      list.add(trimmed);
      state = state.copyWith(targetCompanies: list);
    }
  }

  // Kept for callers from older flows; required identity cannot be bypassed.
  Future<bool> startWithoutSetup() async => false;

  Future<bool> submitAndSeedPlan(
    BuildContext context,
    WidgetRef widgetRef,
  ) async {
    if (state.isSubmitting ||
        state.name.trim().runes.length < 2 ||
        state.dateOfBirth == null ||
        state.dateOfBirth!.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      return false;
    }
    state = state.copyWith(isSubmitting: true);
    try {
      final db = ref.read(databaseProvider);
      final cleanName = state.name.trim();
      final cleanRole = state.targetRole.trim().isNotEmpty
          ? state.targetRole.trim()
          : (state.focusArea.isNotEmpty ? state.focusArea : 'Mindful Growth');

      await db.transaction(() async {
        final existingProfile = await db.userProfileDao.getProfile();
        await db.userProfileDao.upsertProfile(
          UserProfileTableCompanion(
            id: drift.Value(existingProfile?.id ?? 1),
            name: drift.Value(cleanName),
            targetRole: drift.Value(cleanRole),
            targetCompanies: drift.Value(jsonEncode(state.targetCompanies)),
            interviewDate: drift.Value(state.interviewDate),
            dateOfBirth: drift.Value(state.dateOfBirth),
            weeklyHoursAvailable: drift.Value(state.weeklyHours),
            onboardingComplete: const drift.Value(true),
            lastOpenedAt: drift.Value(DateTime.now()),
          ),
        );
      });

      // Synchronize chosen AI companion name and theme atmosphere
      await ref
          .read(assistantNameProvider.notifier)
          .setName(state.companionName);
      await ref
          .read(dayThemePresetProvider.notifier)
          .setPreset(state.themePreset);

      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('ascent_quick_start_v1', true);
      await prefs.setBool('ascent_first_moment_pending_v1', true);
      await markOnboardingComplete(widgetRef);
      return true;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingDraftState>(
      OnboardingNotifier.new,
    );

/// A compact welcome followed by the two required personal details.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({super.key});
  @override
  Widget build(BuildContext context) => Theme(
    data: AscentTheme.light(preset: DayThemePreset.nordicSky),
    child: const _WelcomeFlow(),
  );
}

class _WelcomeFlow extends ConsumerStatefulWidget {
  const _WelcomeFlow();
  @override
  ConsumerState<_WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends ConsumerState<_WelcomeFlow> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _showDobError = false;
  String? _error;
  static const ink = Color(0xFF20232A);
  static const muted = Color(0xFF606872);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    FocusScope.of(context).unfocus();
    final now = DateUtils.dateOnly(DateTime.now());
    final state = ref.read(onboardingProvider);
    final value = await showDatePicker(
      context: context,
      helpText: 'Your date of birth',
      initialDate:
          state.dateOfBirth ?? DateTime(now.year - 22, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (value != null && mounted) {
      ref.read(onboardingProvider.notifier).setDateOfBirth(value);
      setState(() {
        _showDobError = false;
        _error = null;
      });
    }
  }

  Future<void> _continue() async {
    final notifier = ref.read(onboardingProvider.notifier);
    final state = ref.read(onboardingProvider);
    if (state.isSubmitting) return;
    if (state.stepIndex == 0) {
      HapticFeedback.selectionClick();
      notifier.setStep(1);
      return;
    }
    final valid = _form.currentState!.validate();
    setState(() => _showDobError = state.dateOfBirth == null);
    if (!valid || state.dateOfBirth == null) return;
    FocusScope.of(context).unfocus();
    notifier.updateNameRole(_name.text.trim(), 'Mindful Growth');
    final saved = await notifier.submitAndSeedPlan(context, ref);
    if (!mounted) return;
    if (saved) {
      context.go(NotificationService.consumePendingDestination() ?? '/home');
    } else {
      setState(
        () => _error = 'Could not save. Your details are still here—try again.',
      );
    }
  }

  Widget _action(OnboardingDraftState state, String label) =>
      AscentButton.primary(
        key: const ValueKey('onboarding_next'),
        label: label,
        icon: Icons.arrow_forward_rounded,
        expanded: false,
        compact: true,
        loading: state.isSubmitting,
        onPressed: state.isSubmitting ? null : _continue,
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final first = state.stepIndex == 0;
    return PopScope(
      canPop: first,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.isSubmitting) {
          ref.read(onboardingProvider.notifier).setStep(0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFCF8),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/welcome_horizon.png'),
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFCF8), Color(0xFFF0F5F4), Color(0xFFF9EEE4)],
            ),
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!first)
                            IconButton(
                              tooltip: 'Back',
                              onPressed: state.isSubmitting
                                  ? null
                                  : () => ref
                                        .read(onboardingProvider.notifier)
                                        .setStep(0),
                              icon: const Icon(Icons.arrow_back_rounded),
                            )
                          else
                            const AscentLogo(size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'Ascent',
                            style: AscentTextStyles.cardTitle.copyWith(
                              color: ink,
                            ),
                          ),
                          const Spacer(),
                          if (MediaQuery.textScalerOf(context).scale(14) < 21)
                            Text(
                              first ? 'WELCOME' : 'MAKE IT YOURS',
                              style: AscentTextStyles.labelSmall.copyWith(
                                color: muted,
                                letterSpacing: 1,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      AnimatedSwitcher(
                        duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(context)
                              ? 0
                              : 280,
                        ),
                        child: first ? _intro(state) : _personalize(state),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(OnboardingDraftState state) => Column(
    key: const ValueKey('welcome_intro'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'A little more room\nfor your day.',
        style: AscentTextStyles.homeTitle.copyWith(
          color: ink,
          fontSize: 32,
          height: 1.15,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Plans, thoughts, and everyday rituals. Together.',
        style: AscentTextStyles.body.copyWith(color: muted),
      ),
      const SizedBox(height: 22),
      const _WelcomeArtwork(),
      const SizedBox(height: 18),
      Text(
        'A glimpse of what you can make.',
        style: AscentTextStyles.labelSmall.copyWith(color: muted),
      ),
      const SizedBox(height: 20),
      _action(state, 'Let’s begin'),
      const SizedBox(height: 14),
      Text(
        'Your space. At your pace.',
        style: AscentTextStyles.labelSmall.copyWith(color: muted),
      ),
    ],
  );
  Widget _personalize(OnboardingDraftState state) => Container(
    key: const ValueKey('welcome_details'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFE1E4E1)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C273B36),
          blurRadius: 26,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.wb_twilight_rounded,
            size: 32,
            color: Color(0xFFA97D52),
          ),
          const SizedBox(height: 16),
          Text(
            'Make it yours.',
            style: AscentTextStyles.homeTitle.copyWith(
              fontSize: 28,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your name for a warm welcome. Your birthday for your Rashi.',
            style: AscentTextStyles.body.copyWith(color: muted),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey('onboarding_name'),
            controller: _name,
            enabled: !state.isSubmitting,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            onFieldSubmitted: (_) => _pickBirthday(),
            validator: (value) => (value ?? '').trim().runes.length < 2
                ? 'Enter your name (at least two characters).'
                : null,
            decoration: InputDecoration(
              labelText: 'Your name',
              hintText: 'What should we call you?',
              filled: false,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Date of birth, required',
            child: InkWell(
              key: const ValueKey('onboarding_dob'),
              onTap: state.isSubmitting ? null : _pickBirthday,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date of birth',
                  errorText: _showDobError
                      ? 'Choose your date of birth.'
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  suffixIcon: const Icon(
                    Icons.calendar_month_rounded,
                    size: 21,
                  ),
                ),
                child: Text(
                  state.dateOfBirth == null
                      ? 'Choose your birthday'
                      : DateFormat.yMMMd().format(state.dateOfBirth!),
                  style: AscentTextStyles.body.copyWith(
                    color: state.dateOfBirth == null ? muted : ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Both details are required. You can change them in your profile.',
            style: AscentTextStyles.labelSmall.copyWith(color: muted),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: SharedControlColors.dueRed),
              ),
            ),
          const SizedBox(height: 22),
          _action(state, 'Continue'),
        ],
      ),
    ),
  );
}

/// Native layered paper, so the illustration stays crisp without an image load.
class _WelcomeArtwork extends StatelessWidget {
  const _WelcomeArtwork();
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(14) > 21;
    Widget card(IconData icon, String text, Color fill) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x192C3C35),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5A7764), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AscentTextStyles.cardTitle.copyWith(
                fontSize: 16,
                color: const Color(0xFF20232A),
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      key: const ValueKey('onboarding_preview'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCECF5), Color(0xFFF9E9D9), Color(0xFFE2ECDE)],
        ),
      ),
      child: Column(
        children: [
          Transform.rotate(
            angle: large ? 0 : -.045,
            child: card(
              Icons.radio_button_unchecked_rounded,
              'Make time for a walk',
              const Color(0xFFFDFEFC),
            ),
          ),
          const SizedBox(height: 18),
          Transform.rotate(
            angle: large ? 0 : .045,
            child: card(
              Icons.auto_awesome_rounded,
              'An idea worth keeping',
              const Color(0xFFFFF8ED),
            ),
          ),
        ],
      ),
    );
  }
}
