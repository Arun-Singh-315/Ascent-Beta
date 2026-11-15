import 'dart:ui' as ui;
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
import '../../core/services/cosmic_profile_service.dart';
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

// Canonical Apple iOS Hues
const _appleBlue = Color(0xFF0A84FF);
const _appleRed = Color(0xFFFF375F);
const _appleEmerald = Color(0xFF30D158);
const _appleAmber = Color(0xFFFF9F0A);

/// Ascent Onboarding Experience — Apple-touch frosted glass design with smooth animations.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({super.key});
  @override
  Widget build(BuildContext context) => const _WelcomeFlow();
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
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProvider);
    if (draft.name.isNotEmpty) {
      _name.text = draft.name;
    }
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
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
        backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF2F4F7),
        body: Stack(
          children: [
            // Ambient Top-Right Electric Blue Glow Orb
            Positioned(
              top: -60,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _appleBlue.withValues(alpha: isDark ? 0.20 : 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Ambient Bottom-Left Rose Glow Orb
            Positioned(
              bottom: -60,
              left: -60,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _appleRed.withValues(alpha: isDark ? 0.16 : 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // SafeArea & Glass Surface
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Navigation & Step Header Bar
                        _buildHeaderBar(context, state, first, isDark),
                        const SizedBox(height: 10),

                        // Smooth iOS Slide + Fade Animated Card
                        AnimatedSwitcher(
                          duration: Duration(
                            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 300,
                          ),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final slideIn = Tween<Offset>(
                              begin: const Offset(0.04, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ));
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slideIn,
                                child: child,
                              ),
                            );
                          },
                          child: first
                              ? _buildVisionCard(context, state, isDark)
                              : _buildPersonalizeCard(context, state, isDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    OnboardingDraftState state,
    bool first,
    bool isDark,
  ) {
    final g = context.glass;
    return SizedBox(
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x33FFFFFF) : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
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
                const AscentLogo(size: 22),
                const SizedBox(width: 8),
                Text(
                  'Ascent',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: g.ink,
                  ),
                ),
              ],
            ),

          // Subtle Stage Indicator Capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x22FFFFFF) : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: first ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: first ? _appleBlue : g.inkMuted.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: !first ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: !first ? _appleBlue : g.inkMuted.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  first ? '01 Vision' : '02 Identity',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: g.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 0: The Vision Card ────────────────────────────────────────────────
  Widget _buildVisionCard(BuildContext context, OnboardingDraftState state, bool isDark) {
    final g = context.glass;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          key: const ValueKey('welcome_intro'),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xCC161B24) : Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Apple Blue Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _appleBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _appleBlue.withValues(alpha: 0.28), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 12, color: _appleBlue),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Your Personal Sanctuary',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _appleBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'A quiet space for your mind & daily rhythm.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.5,
                  color: g.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ascent brings plans, focus, daily routines, and gentle AI companionship together in one calm surface.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  height: 1.4,
                  color: g.inkSecondary,
                ),
              ),

              const SizedBox(height: 14),

              // 4 Refined Apple Vision Pillars
              _buildPillarTile(
                context,
                icon: Icons.wb_sunny_rounded,
                tintColor: _appleAmber,
                title: 'Daily Rhythm & Focus',
                subtitle: 'Dayboard, scheduled activities, and timers designed for flow.',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildPillarTile(
                context,
                icon: Icons.school_rounded,
                tintColor: _appleBlue,
                title: 'Study & Meal Plans',
                subtitle: 'Structured syllabus milestones and healthy nutrition routines.',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildPillarTile(
                context,
                icon: Icons.favorite_rounded,
                tintColor: _appleEmerald,
                title: 'Personal Companion',
                subtitle: 'Riya AI reflects on your schedule, keeping you on track.',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildPillarTile(
                context,
                icon: Icons.shield_rounded,
                tintColor: _appleRed,
                title: 'Care & Mindful Wealth',
                subtitle: 'Medication tracking, smart snooze care, and mindful spend limits.',
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // Classic Well-Placed Apple Pill Button
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
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Private, local, and crafted for your peace of mind.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: g.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarTile(
    BuildContext context, {
    required IconData icon,
    required Color tintColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final g = context.glass;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x33FFFFFF) : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tintColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tintColor.withValues(alpha: 0.28), width: 0.8),
            ),
            child: Center(
              child: Icon(icon, size: 15, color: tintColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: g.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: g.inkSecondary,
                    height: 1.3,
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
  Widget _buildPersonalizeCard(BuildContext context, OnboardingDraftState state, bool isDark) {
    final g = context.glass;
    final nameTrimmed = _name.text.trim();
    final isNameValid = nameTrimmed.runes.length >= 2;
    final zodiac = state.dateOfBirth != null
        ? const CosmicProfileService().getZodiac(state.dateOfBirth!)
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          key: const ValueKey('welcome_details'),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xCC161B24) : Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cute Amber Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _appleAmber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _appleAmber.withValues(alpha: 0.28), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wb_twilight_rounded, size: 12, color: _appleAmber),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Step 2 of 2 · Customization',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _appleAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Make Ascent yours.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: g.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your name for warm greetings, and your birthday for calibrated astrological rhythms.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.35,
                    color: g.inkSecondary,
                  ),
                ),

                const SizedBox(height: 14),

                // Single-Enclosure Glass Name Input with Live Checkmark
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: g.ink,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    labelText: 'Your Name',
                    hintText: 'What should we call you?',
                    labelStyle: GoogleFonts.plusJakartaSans(color: g.inkSecondary, fontSize: 12),
                    hintStyle: GoogleFonts.plusJakartaSans(color: g.inkMuted, fontSize: 12),
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: _appleBlue),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isNameValid)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.check_circle_rounded, size: 16, color: _appleEmerald),
                          ),
                        if (nameTrimmed.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 16),
                            color: g.inkMuted,
                            onPressed: state.isSubmitting ? null : () => _name.clear(),
                          ),
                      ],
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0x33FFFFFF) : Colors.black.withValues(alpha: 0.025),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isNameValid
                            ? _appleEmerald.withValues(alpha: 0.5)
                            : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08)),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _appleBlue, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _appleRed, width: 1),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _appleRed, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Single-Enclosure Glass Date of Birth Selector
                Semantics(
                  button: true,
                  label: 'Date of birth, required',
                  child: KeyedSubtree(
                    key: const ValueKey('onboarding_dob_picker'),
                    child: InkWell(
                      key: const ValueKey('onboarding_dob'),
                      onTap: state.isSubmitting ? null : _pickBirthday,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x33FFFFFF) : Colors.black.withValues(alpha: 0.025),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _showDobError
                                ? _appleRed
                                : (state.dateOfBirth != null
                                    ? _appleEmerald.withValues(alpha: 0.5)
                                    : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08))),
                            width: _showDobError ? 1.2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 18, color: _appleBlue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date of Birth',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: g.inkSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    state.dateOfBirth == null
                                        ? 'Select your birthday'
                                        : DateFormat.yMMMd().format(state.dateOfBirth!),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: state.dateOfBirth == null ? g.inkMuted : g.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (state.dateOfBirth != null)
                              const Icon(Icons.check_circle_rounded, size: 16, color: _appleEmerald)
                            else
                              Icon(Icons.arrow_drop_down_rounded, color: g.inkMuted, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if (_showDobError) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Choose your date of birth.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _appleRed,
                      ),
                    ),
                  ),
                ],

                // Real-Time Astrological Cosmic Profile Preview Pill
                if (zodiac != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _appleBlue.withValues(alpha: isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _appleBlue.withValues(alpha: isDark ? 0.35 : 0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(zodiac.symbol, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${zodiac.name} · ${zodiac.vedicRashi} (${zodiac.vedicHindi}) · ${zodiac.element.icon} ${zodiac.archetype}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: g.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Primary Focus Area Selector
                Text(
                  'Primary Focus Area',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: g.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'Inner Peace',
                    'Focus & Flow',
                    'Study & Growth',
                    'Daily Vitality',
                  ].map((focus) {
                    final isSelected = state.focusArea == focus;
                    return ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      label: Text(
                        focus,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : g.ink,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: _appleBlue,
                      backgroundColor: isDark ? const Color(0x22FFFFFF) : Colors.black.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(
                        color: isSelected ? _appleBlue : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08)),
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
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: _appleRed,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Classic Well-Placed Action Footer
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
        ),
      ),
    );
  }
}
