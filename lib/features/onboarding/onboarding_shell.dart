import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/app_surfaces.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
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

// ---------------------------------------------------------------------------
// Main Onboarding Shell Widget
// ---------------------------------------------------------------------------

class OnboardingShell extends ConsumerStatefulWidget {
  const OnboardingShell({super.key});

  @override
  ConsumerState<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends ConsumerState<OnboardingShell> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();

  static const _totalSteps = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    ref.read(onboardingProvider.notifier).setStep(step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextStep() {
    final current = ref.read(onboardingProvider).stepIndex;
    if (current < _totalSteps - 1) {
      _goToStep(current + 1);
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    final current = ref.read(onboardingProvider).stepIndex;
    if (current > 0) {
      _goToStep(current - 1);
    }
  }

  Future<void> _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    final saved = await ref
        .read(onboardingProvider.notifier)
        .submitAndSeedPlan(context, ref);
    if (!mounted) return;
    if (saved) {
      context.go(NotificationService.consumePendingDestination() ?? '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your setup. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final currentStep = state.stepIndex;

    return PopScope(
      canPop: currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentStep > 0) {
          _prevStep();
        }
      },
      child: Scaffold(
        backgroundColor: context.bgBase,
        appBar: AppBar(
          backgroundColor: context.bgBase,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: currentStep > 0
              ? Padding(
                  padding: const EdgeInsets.all(AppSpace.s8),
                  child: AscentButton.icon(
                    icon: Icons.arrow_back_rounded,
                    compact: true,
                    onPressed: _prevStep,
                  ),
                )
              : null,
          title: _ProgressDots(total: _totalSteps, current: currentStep),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: state.isSubmitting
                  ? null
                  : () async {
                      final saved = await ref
                          .read(onboardingProvider.notifier)
                          .startWithoutSetup();
                      if (!context.mounted) return;
                      if (saved) {
                        context.go(
                          NotificationService.consumePendingDestination() ??
                              '/home',
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not save your choice. Please try again.',
                            ),
                          ),
                        );
                      }
                    },
              child: const Text('Start now'),
            ),
          ],
        ),
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StepVision(onContinue: _nextStep),
              _StepSanctuarySetup(
                nameController: _nameController,
                roleController: _roleController,
                onContinue: _nextStep,
              ),
              _StepSanctuarySealed(onFinish: _finishOnboarding),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated Progress Dots Indicator
// ---------------------------------------------------------------------------

class _ProgressDots extends StatelessWidget {
  final int total;
  final int current;

  const _ProgressDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final isCurrent = index == current;
        final isCompleted = index < current;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
          height: 6,
          width: isCurrent ? 28 : 8,
          decoration: BoxDecoration(
            borderRadius: AppGeometry.roundedr3,
            color: isCurrent
                ? context.accentPrimary
                : isCompleted
                ? context.accentPrimary.withValues(alpha: 0.45)
                : context.divider,
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 1: The Ascent Odyssey (Creative Vision & Pillars)
// ---------------------------------------------------------------------------

class _StepVision extends StatefulWidget {
  final VoidCallback onContinue;

  const _StepVision({required this.onContinue});

  @override
  State<_StepVision> createState() => _StepVisionState();
}

class _StepVisionState extends State<_StepVision>
    with SingleTickerProviderStateMixin {
  late final AnimationController _haloController;

  @override
  void initState() {
    super.initState();
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (!isTest) {
      _haloController.repeat(reverse: true);
    } else {
      _haloController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _haloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final g = context.glass;

    return _ScrollableSetup(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s20,
          vertical: AppSpace.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),

            // Animated breathing emblem with halo
            AnimatedBuilder(
              animation: _haloController,
              builder: (context, child) {
                final pulse = _haloController.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 90 + (pulse * 16),
                      height: 90 + (pulse * 16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            context.accentPrimary.withValues(
                              alpha: 0.24 + (pulse * 0.16),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const AscentLogo(size: 68),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Privacy tag badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s10,
                vertical: AppSpace.s4,
              ),
              decoration: BoxDecoration(
                color: g.fill,
                borderRadius: AppGeometry.roundedr16,
                border: Border.all(
                  color: g.line,
                  width: AppBorderScale.w0point8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 13,
                    color: context.accentPrimary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '100% ON-DEVICE • PRIVATE LIFE OS',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Headline
            Text(
              'Where clarity meets quiet discipline.',
              style: AscentTextStyles.displayLarge.copyWith(
                color: textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                'Ascent is your private space to declutter your mind, honor your word, and move through every day with intention.',
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: textMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // 4 Pillars of Ascent
            _PillarCard(
              icon: Icons.psychology_outlined,
              iconTint: g.coral,
              tag: 'CLARITY',
              title: 'Mind Palace',
              subtitle:
                  'Unfiltered self-talk, sparks & voice reflections. Zero cloud tracking, strictly on-device.',
            ),
            const SizedBox(height: 10),

            _PillarCard(
              icon: Icons.lock_clock_outlined,
              iconTint: g.amber,
              tag: 'INTEGRITY',
              title: 'Sacred Promises',
              subtitle:
                  'Honor commitments made to yourself and others with quiet, unwavering discipline.',
            ),
            const SizedBox(height: 10),

            _PillarCard(
              icon: Icons.spa_outlined,
              iconTint: g.sage,
              tag: 'VITALITY',
              title: 'Daily Rhythms',
              subtitle:
                  'Mindful chai breaks, medicine schedules, hydration & deep focus hours.',
            ),
            const SizedBox(height: 10),

            _PillarCard(
              icon: Icons.stars_rounded,
              iconTint: context.accentPrimary,
              tag: 'PRESENCE',
              title: 'AI Companion (Aria / Riya)',
              subtitle:
                  'A private confidant that listens, structures thoughts, and anchors your focus.',
            ),

            const SizedBox(height: 28),

            // CTA
            AscentButton.primary(
              label: 'Begin Your Ascent →',
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onContinue();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  final IconData icon;
  final Color iconTint;
  final String tag;
  final String title;
  final String subtitle;

  const _PillarCard({
    required this.icon,
    required this.iconTint,
    required this.tag,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final g = context.glass;

    return AscentCard.glass(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s14,
        vertical: AppSpace.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconTint.withValues(alpha: 0.14),
              borderRadius: AppGeometry.roundedr10,
              border: Border.all(
                color: iconTint.withValues(alpha: 0.3),
                width: AppBorderScale.w0point8,
              ),
            ),
            child: Icon(icon, size: 20, color: iconTint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s6,
                          vertical: AppSpace.s2,
                        ),
                        decoration: BoxDecoration(
                          color: g.fill,
                          borderRadius: AppGeometry.roundedr3,
                          border: Border.all(
                            color: g.line,
                            width: AppBorderScale.w0point8,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: iconTint,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: textMuted,
                    fontSize: 12,
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
}

// ---------------------------------------------------------------------------
// Screen 2: Shape Your Sanctuary (No Useless Questions!)
// ---------------------------------------------------------------------------

class _StepSanctuarySetup extends ConsumerStatefulWidget {
  final TextEditingController nameController;
  final TextEditingController roleController;
  final VoidCallback onContinue;

  const _StepSanctuarySetup({
    required this.nameController,
    required this.roleController,
    required this.onContinue,
  });

  @override
  ConsumerState<_StepSanctuarySetup> createState() =>
      _StepSanctuarySetupState();
}

class _StepSanctuarySetupState extends ConsumerState<_StepSanctuarySetup> {
  static const _intentions = [
    'Inner Peace',
    'Deep Focus',
    'Self-Mastery',
    'Creative Flow',
    'Healthy Habits',
  ];

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_rebuild);
    widget.roleController.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_rebuild);
    widget.roleController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final g = context.glass;
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final name = widget.nameController.text.trim();
    final isNameValid = name.length >= 2;

    return _ScrollableSetup(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s20,
          vertical: AppSpace.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Header
            Text(
              'Shape your sanctuary.',
              style: AscentTextStyles.displayLarge.copyWith(
                color: textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No corporate quizzes or endless forms. Just your private space, tailored to your flow.',
              style: AscentTextStyles.bodyMedium.copyWith(
                color: textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // 1. Name Input
            Row(
              children: [
                Text(
                  'Your Name',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: TextStyle(
                    color: context.stateDanger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Unified single-enclosure glass input (Rule 19 compliant)
            TextField(
              controller: widget.nameController,
              textCapitalization: TextCapitalization.words,
              style: AscentTextStyles.bodyMedium.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Alex, Arun',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(
                  color: textMuted.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: g.fill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s14,
                  vertical: AppSpace.s12,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppGeometry.roundedr12,
                  borderSide: BorderSide(
                    color: g.line,
                    width: AppBorderScale.w0point8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppGeometry.roundedr12,
                  borderSide: BorderSide(
                    color: g.line,
                    width: AppBorderScale.w0point8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppGeometry.roundedr12,
                  borderSide: BorderSide(
                    color: context.accentPrimary,
                    width: AppBorderScale.w1point2,
                  ),
                ),
              ),
              onChanged: (val) {
                notifier.updateNameRole(val, widget.roleController.text);
              },
            ),

            const SizedBox(height: 22),

            // 2. AI Companion Identity Choice
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Companion Identity',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Switch anytime in Settings',
                        style: AscentTextStyles.bodySmall.copyWith(
                          color: textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 280;
                return isNarrow
                    ? Column(
                        children: [
                          _CompanionChoiceCard(
                            title: '✦ Aria',
                            description: 'Poetic, thoughtful & reflective',
                            accent: g.coral,
                            isSelected: state.companionName == 'Aria',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              notifier.setCompanion('Aria');
                            },
                          ),
                          const SizedBox(height: 8),
                          _CompanionChoiceCard(
                            title: '✦ Riya',
                            description: 'Sharp, focused & proactive',
                            accent: g.amber,
                            isSelected: state.companionName == 'Riya',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              notifier.setCompanion('Riya');
                            },
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _CompanionChoiceCard(
                              title: '✦ Aria',
                              description: 'Poetic & reflective',
                              accent: g.coral,
                              isSelected: state.companionName == 'Aria',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                notifier.setCompanion('Aria');
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompanionChoiceCard(
                              title: '✦ Riya',
                              description: 'Sharp & proactive',
                              accent: g.amber,
                              isSelected: state.companionName == 'Riya',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                notifier.setCompanion('Riya');
                              },
                            ),
                          ),
                        ],
                      );
              },
            ),

            const SizedBox(height: 22),

            // 3. Visual Atmosphere (Live Theme Switcher)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visual Atmosphere',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to preview live theme atmosphere',
                        style: AscentTextStyles.bodySmall.copyWith(
                          color: textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _AtmosphereCard(
                    title: 'Merlot',
                    subtitle: 'Wine & Linen',
                    color: const Color(0xFF9E2A42),
                    isSelected: state.themePreset == DayThemePreset.merlotLinen,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      notifier.setThemePreset(DayThemePreset.merlotLinen);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AtmosphereCard(
                    title: 'Nordic',
                    subtitle: 'Clear Sky',
                    color: const Color(0xFF2E6B9E),
                    isSelected: state.themePreset == DayThemePreset.nordicSky,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      notifier.setThemePreset(DayThemePreset.nordicSky);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AtmosphereCard(
                    title: 'Obsidian',
                    subtitle: 'Dark Clay',
                    color: const Color(0xFF38433B),
                    isSelected: state.themePreset == DayThemePreset.classicClay,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      notifier.setThemePreset(DayThemePreset.classicClay);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // 4. Primary Intention (Optional)
            Text(
              'Primary Focus (optional)',
              style: AscentTextStyles.labelSmall.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _intentions.map((intention) {
                final isSelected = state.focusArea == intention;
                return AppPill.filter(
                  label: Text(intention),
                  selected: isSelected,
                  selectedColor: context.accentPrimary.withValues(alpha: 0.16),
                  checkmarkColor: context.accentPrimary,
                  backgroundColor: isSelected
                      ? context.accentPrimary.withValues(alpha: 0.12)
                      : g.fill,
                  side: BorderSide(
                    color: isSelected ? context.accentPrimary : g.line,
                    width: AppBorderScale.w0point8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppGeometry.roundedr8,
                  ),
                  labelStyle: AscentTextStyles.bodySmall.copyWith(
                    color: isSelected ? context.accentPrimary : textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    notifier.setFocusArea(intention);
                    widget.roleController.text = intention;
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Continue Button
            AscentButton.primary(
              label: isNameValid ? 'Establish Sanctuary →' : 'Enter your name',
              onPressed: isNameValid
                  ? () {
                      HapticFeedback.lightImpact();
                      notifier.updateNameRole(name, widget.roleController.text);
                      widget.onContinue();
                    }
                  : null,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _CompanionChoiceCard extends StatelessWidget {
  final String title;
  final String description;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompanionChoiceCard({
    required this.title,
    required this.description,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final g = context.glass;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.12) : g.fill,
          borderRadius: AppGeometry.roundedr12,
          border: Border.all(
            color: isSelected ? accent : g.line,
            width: isSelected
                ? AppBorderScale.w1point2
                : AppBorderScale.w0point8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: isSelected ? accent : textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 16, color: accent),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AscentTextStyles.bodySmall.copyWith(
                color: textMuted,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AtmosphereCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AtmosphereCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final g = context.glass;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : g.fill,
          borderRadius: AppGeometry.roundedr12,
          border: Border.all(
            color: isSelected ? color : g.line,
            width: isSelected
                ? AppBorderScale.w1point2
                : AppBorderScale.w0point8,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: AscentTextStyles.labelSmall.copyWith(
                  color: isSelected ? color : textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                style: AscentTextStyles.bodySmall.copyWith(
                  color: textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 3: Sanctuary Sealed (Celebration & Entry)
// ---------------------------------------------------------------------------

class _StepSanctuarySealed extends StatefulWidget {
  final VoidCallback onFinish;

  const _StepSanctuarySealed({required this.onFinish});

  @override
  State<_StepSanctuarySealed> createState() => _StepSanctuarySealedState();
}

class _StepSanctuarySealedState extends State<_StepSanctuarySealed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (!isTest) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _presetTitle(DayThemePreset preset) {
    switch (preset) {
      case DayThemePreset.merlotLinen:
        return 'Vintage Merlot';
      case DayThemePreset.nordicSky:
        return 'Clear Sky';
      case DayThemePreset.classicClay:
        return 'Classic Obsidian';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(onboardingProvider);
        final textPrimary = context.textPrimary;
        final textMuted = context.textMuted;
        final g = context.glass;
        final displayName = state.name.trim().isNotEmpty
            ? state.name.trim()
            : 'Traveler';

        return _ScrollableSetup(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s20,
              vertical: AppSpace.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 18),

                // Animated Concentric Pulse Ring with Shield
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = _pulseController.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 88 + (pulse * 14),
                          height: 88 + (pulse * 14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.accentPrimary.withValues(
                              alpha: 0.12 + (pulse * 0.08),
                            ),
                          ),
                        ),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: g.fill,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.accentPrimary,
                              width: AppBorderScale.w1point2,
                            ),
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            color: context.accentPrimary,
                            size: 34,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                Text(
                  'Sanctuary Sealed.',
                  style: AscentTextStyles.displayLarge.copyWith(
                    color: textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    'Welcome home, $displayName. Your thoughts, promises, and rhythms are encrypted locally on this device.',
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: textMuted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Sanctuary Overview Card
                AscentCard.glass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16,
                    vertical: AppSpace.s14,
                  ),
                  child: Column(
                    children: [
                      _SanctuaryRecapRow(
                        icon: Icons.stars_rounded,
                        label: 'AI Companion',
                        value: '✦ ${state.companionName}',
                        accent: context.accentPrimary,
                      ),
                      AppDivider(color: g.line, height: 16),
                      _SanctuaryRecapRow(
                        icon: Icons.palette_outlined,
                        label: 'Atmosphere',
                        value: _presetTitle(state.themePreset),
                        accent: g.amber,
                      ),
                      AppDivider(color: g.line, height: 16),
                      _SanctuaryRecapRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Security',
                        value: 'Hardware-backed SQLite',
                        accent: g.sage,
                      ),
                      AppDivider(color: g.line, height: 16),
                      _SanctuaryRecapRow(
                        icon: Icons.center_focus_strong_rounded,
                        label: 'Primary Focus',
                        value: state.focusArea.isNotEmpty
                            ? state.focusArea
                            : 'Mindful Growth',
                        accent: g.coral,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Enter Ascent CTA
                AscentButton.primary(
                  label: 'Enter Ascent →',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onFinish();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SanctuaryRecapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _SanctuaryRecapRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;

    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AscentTextStyles.bodyMedium.copyWith(
              color: textMuted,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AscentTextStyles.labelSmall.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Scrollable Defensive Viewport Wrapper (Rule 13 Safeguard)
// ---------------------------------------------------------------------------

class _ScrollableSetup extends StatelessWidget {
  const _ScrollableSetup({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );
}
