import '../../app/theme/app_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/glass_theme.dart';
import '../../app/theme/color_tokens.dart';
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
  final int stepIndex; // 0: Vision & Welcome, 1: Personalize Space
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

/// Ascent Onboarding Experience — Calm, personal, subtle glass design.
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
      helpText: 'Select your birth date',
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
    notifier.updateNameRole(_name.text.trim(), state.focusArea);
    final saved = await notifier.submitAndSeedPlan(context, ref);
    if (!mounted) return;
    if (saved) {
      context.go(NotificationService.consumePendingDestination() ?? '/home');
    } else {
      setState(
        () => _error = 'Could not save. Your details are preserved—please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        backgroundColor: isDark ? const Color(0xFF0F141C) : const Color(0xFFF7F9FC),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF0C1017),
                      Color(0xFF131822),
                      Color(0xFF0F141D),
                    ]
                  : const [
                      Color(0xFFF9FAFC),
                      Color(0xFFF0F4F8),
                      Color(0xFFE9F0F6),
                    ],
            ),
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Navigation & Step Header Bar
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!first)
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: state.isSubmitting
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        ref.read(onboardingProvider.notifier).setStep(0);
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? g.surface : Colors.white.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: g.line.withValues(alpha: 0.3), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.arrow_back_rounded, size: 14, color: g.ink),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Back',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: g.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const AscentLogo(size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ascent',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: g.ink,
                                    ),
                                  ),
                                ],
                              ),

                            // Subtle Stage Indicator Capsule
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: isDark ? g.surface : Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: g.line.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: first ? 14 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: first ? context.accentPrimary : g.inkMuted.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: !first ? 14 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: !first ? context.accentPrimary : g.inkMuted.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    first ? '01 Vision' : '02 Identity',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: g.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Smooth Card Transition
                      AnimatedSwitcher(
                        duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 300,
                        ),
                        child: first ? _buildVisionCard(context, state) : _buildPersonalizeCard(context, state),
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

  // ── Step 0: The Vision Card ────────────────────────────────────────────────
  Widget _buildVisionCard(BuildContext context, OnboardingDraftState state) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.accentPrimary;

    return Container(
      key: const ValueKey('welcome_intro'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? g.surface.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: g.line.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cute Accent Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.25), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 12, color: accent),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Your Personal Sanctuary',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'A quiet space for your mind & daily rhythm.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.6,
              color: g.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ascent brings plans, focus, daily routines, and gentle AI companionship together in one calm surface.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.45,
              color: g.inkSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // 3 Refined, Subtle Glass Vision Pillars
          _buildPillarTile(
            context,
            icon: Icons.wb_sunny_rounded,
            tintColor: const Color(0xFFD97706),
            title: 'Daily Rhythm & Focus',
            subtitle: 'Dayboard, scheduled activities, and timers designed for flow.',
          ),
          const SizedBox(height: 10),
          _buildPillarTile(
            context,
            icon: Icons.school_rounded,
            tintColor: const Color(0xFF2563EB),
            title: 'Study & Meal Plans',
            subtitle: 'Structured syllabus milestones and healthy nutrition routines.',
          ),
          const SizedBox(height: 10),
          _buildPillarTile(
            context,
            icon: Icons.favorite_rounded,
            tintColor: const Color(0xFF059669),
            title: 'Personal Companion',
            subtitle: 'Riya AI reflects on your schedule, keeping you on track.',
          ),

          const SizedBox(height: 24),

          // Integrated Forward Action
          SizedBox(
            width: double.infinity,
            child: AscentButton.primary(
              key: const ValueKey('onboarding_next'),
              label: 'Let’s begin',
              icon: Icons.arrow_forward_rounded,
              expanded: true,
              loading: state.isSubmitting,
              onPressed: _continue,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Private, local, and crafted for your peace of mind.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: g.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarTile(
    BuildContext context, {
    required IconData icon,
    required Color tintColor,
    required String title,
    required String subtitle,
  }) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? g.surface.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: g.line.withValues(alpha: isDark ? 0.25 : 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tintColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: tintColor.withValues(alpha: 0.25), width: 0.8),
            ),
            child: Center(
              child: Icon(icon, size: 16, color: tintColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: g.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: g.inkSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: The Personalize Card ───────────────────────────────────────────
  Widget _buildPersonalizeCard(BuildContext context, OnboardingDraftState state) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.accentPrimary;

    return Container(
      key: const ValueKey('welcome_details'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? g.surface.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: g.line.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cute Warm Sun Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.25), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wb_twilight_rounded, size: 13, color: Color(0xFFD97706)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Step 2 of 2 · Customization',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'Make Ascent yours.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: g.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your name for warm greetings, and your birthday for calibrated astrological rhythms.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.4,
                color: g.inkSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // Single-Enclosure Glass Name Input
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: g.ink,
              ),
              decoration: InputDecoration(
                labelText: 'Your Name',
                hintText: 'What should we call you?',
                labelStyle: GoogleFonts.plusJakartaSans(color: g.inkSecondary, fontSize: 13),
                hintStyle: GoogleFonts.plusJakartaSans(color: g.inkMuted, fontSize: 13),
                prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: accent),
                filled: true,
                fillColor: isDark ? g.surface.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.025),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: g.line.withValues(alpha: 0.3), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: SharedControlColors.dueRed, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: SharedControlColors.dueRed, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Single-Enclosure Glass Date of Birth Selector
            Semantics(
              button: true,
              label: 'Date of birth, required',
              child: InkWell(
                key: const ValueKey('onboarding_dob'),
                onTap: state.isSubmitting ? null : _pickBirthday,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? g.surface.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.025),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _showDobError
                          ? SharedControlColors.dueRed
                          : g.line.withValues(alpha: 0.3),
                      width: _showDobError ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 18, color: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date of Birth',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: g.inkSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.dateOfBirth == null
                                  ? 'Select your birthday'
                                  : DateFormat.yMMMd().format(state.dateOfBirth!),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: state.dateOfBirth == null ? g.inkMuted : g.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_drop_down_rounded, color: g.inkMuted, size: 22),
                    ],
                  ),
                ),
              ),
            ),

            if (_showDobError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Choose your date of birth.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: SharedControlColors.dueRed,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Cute Focus Intention Selector
            Text(
              'Primary Focus Area',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: g.ink,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Inner Peace',
                'Focus & Flow',
                'Study & Growth',
                'Daily Vitality',
              ].map((focus) {
                final isSelected = state.focusArea == focus;
                return ChoiceChip(
                  label: Text(
                    focus,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : g.ink,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: accent,
                  backgroundColor: isDark ? g.surface : Colors.black.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(
                    color: isSelected ? accent : g.line.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                  onSelected: (val) {
                    if (val) {
                      HapticFeedback.selectionClick();
                      ref.read(onboardingProvider.notifier).setFocusArea(focus);
                    }
                  },
                );
              }).toList(),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: SharedControlColors.dueRed,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Integrated Action Footer
            SizedBox(
              width: double.infinity,
              child: AscentButton.primary(
                key: const ValueKey('onboarding_next'),
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                expanded: true,
                loading: state.isSubmitting,
                onPressed: state.isSubmitting ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
