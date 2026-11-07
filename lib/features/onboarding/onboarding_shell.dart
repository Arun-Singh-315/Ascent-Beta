import '../../app/theme/app_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
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

  Future<bool> startWithoutSetup() async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (!await prefs.setBool('ascent_onboarding_complete', true) ||
          !await prefs.setBool('ascent_quick_start_v1', true)) {
        return false;
      }
      ref.invalidate(onboardingCompleteProvider);
      return true;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<bool> submitAndSeedPlan(
    BuildContext context,
    WidgetRef widgetRef,
  ) async {
    if (state.isSubmitting || state.name.trim().length < 2) return false;
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

/// A two-step welcome with one persistent primary action. Setup is optional.
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
  String? _error;
  static const ink = Color(0xFF202D3F);
  static const muted = Color(0xFF607087);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final notifier = ref.read(onboardingProvider.notifier);
    if (ref.read(onboardingProvider).stepIndex == 0) {
      HapticFeedback.selectionClick();
      notifier.setStep(1);
      return;
    }
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    if (name.isNotEmpty && name.runes.length < 2) {
      setState(
        () => _error = 'Use at least two characters, or leave this blank.',
      );
      return;
    }
    notifier.updateNameRole(name, 'Mindful Growth');
    final saved = name.isEmpty
        ? await notifier.startWithoutSetup()
        : await notifier.submitAndSeedPlan(context, ref);
    if (!mounted) return;
    if (saved) {
      context.go(NotificationService.consumePendingDestination() ?? '/home');
    } else {
      setState(() => _error = 'Could not save your choice. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final first = state.stepIndex == 0;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: first,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.isSubmitting) {
          ref.read(onboardingProvider.notifier).setStep(0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        if (!first)
                          IconButton(
                            tooltip: 'Back',
                            onPressed: state.isSubmitting
                                ? null
                                : () => ref
                                      .read(onboardingProvider.notifier)
                                      .setStep(0),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: ink,
                            ),
                          )
                        else
                          const AscentLogo(size: 32),
                        const SizedBox(width: 8),
                        Text(
                          'Ascent',
                          style: AscentTextStyles.homeTitle.copyWith(
                            fontSize: 18,
                            color: ink,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          first ? '01 / 02' : '02 / 02',
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: reducedMotion ? 0 : 280),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .025),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: SingleChildScrollView(
                        key: ValueKey(first),
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: first ? _intro() : _personalize(state),
                      ),
                    ),
                  ),
                  // The next step never lives inside the scrollable content.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: SharedControlColors.dueRed,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                first
                                    ? 'Less setup. More living.'
                                    : 'Everything else can wait.',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: muted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            AscentButton.primary(
                              key: const ValueKey('onboarding_next'),
                              label: first ? 'Continue' : 'Open Ascent',
                              icon: Icons.arrow_forward_rounded,
                              loading: state.isSubmitting,
                              expanded: false,
                              compact: true,
                              onPressed: state.isSubmitting ? null : _continue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'A LITTLE ROOM FOR YOU',
        style: AscentTextStyles.labelSmall.copyWith(
          color: muted,
          letterSpacing: 1.4,
          fontSize: 10.5,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Small steps.\nClearer days.',
        style: AscentTextStyles.homeTitle.copyWith(
          color: ink,
          fontSize: 34,
          height: 1.12,
          letterSpacing: -1.2,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'A place for what you want to do, what’s on your mind, and the little routines that matter.',
        style: AscentTextStyles.body.copyWith(color: muted, height: 1.5),
      ),
      const SizedBox(height: 24),
      Container(
        key: const ValueKey('onboarding_preview'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9F0FD), Color(0xFFF0F5F2), Color(0xFFFBF0E8)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.wb_twilight_outlined,
                  size: 20,
                  color: SharedControlColors.actionBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A day with a little more space',
                    style: AscentTextStyles.labelMedium.copyWith(color: ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _previewRow(
              Icons.radio_button_unchecked,
              'One thing worth doing',
              'Things Hub',
              const Color(0xFFFFFFFF),
            ),
            const SizedBox(height: 10),
            _previewRow(
              Icons.edit_note_rounded,
              'An idea worth keeping',
              'Thought Wall',
              const Color(0xFFFFFAF6),
            ),
            const SizedBox(height: 16),
            Text(
              'Your own plans and thoughts will live here.',
              style: AscentTextStyles.labelSmall.copyWith(
                color: muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _previewRow(IconData icon, String title, String label, Color fill) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: SharedControlColors.actionBlue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AscentTextStyles.labelSmall.copyWith(color: muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: AscentTextStyles.labelMedium.copyWith(color: ink),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _personalize(OnboardingDraftState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'YOUR SPACE, YOUR PACE',
        style: AscentTextStyles.labelSmall.copyWith(
          color: muted,
          letterSpacing: 1.4,
          fontSize: 10.5,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Make yourself\nat home.',
        style: AscentTextStyles.homeTitle.copyWith(
          color: ink,
          fontSize: 32,
          height: 1.15,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'A name is a nice place to start. Leave it blank if you’d rather settle in first.',
        style: AscentTextStyles.body.copyWith(color: muted, height: 1.45),
      ),
      const SizedBox(height: 24),
      TextField(
        key: const ValueKey('onboarding_name'),
        controller: _name,
        enabled: !state.isSubmitting,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _continue(),
        onChanged: (_) => setState(() => _error = null),
        decoration: InputDecoration(
          labelText: 'Your name · optional',
          hintText: 'What should we call you?',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE0E7F0)),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Your companion',
        style: AscentTextStyles.labelMedium.copyWith(color: ink),
      ),
      const SizedBox(height: 8),
      AscentSegmentedControl<String>(
        segments: const [
          AscentSegment(value: 'Aria', label: 'Aria'),
          AscentSegment(value: 'Riya', label: 'Riya'),
        ],
        selected: state.companionName,
        enabled: !state.isSubmitting,
        onChanged: (value) =>
            ref.read(onboardingProvider.notifier).setCompanion(value),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF3F0),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.spa_outlined, color: Color(0xFF4F7563), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start with something small.',
                    style: AscentTextStyles.cardTitle.copyWith(
                      color: ink,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Begin with one thing, and let your day take shape. Your first step is yours to choose.',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
