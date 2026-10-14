import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../../core/notifications/notification_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';

// ---------------------------------------------------------------------------
// Onboarding State Model & Provider
// ---------------------------------------------------------------------------

class OnboardingDraftState {
  final int stepIndex; // 0 to 2
  final String name;
  final String targetRole;
  final List<String> targetCompanies;
  final DateTime? interviewDate;
  final bool isJustPreparing;
  final int weeklyHours;
  final bool isSubmitting;

  const OnboardingDraftState({
    this.stepIndex = 0,
    this.name = '',
    this.targetRole = '',
    this.targetCompanies = const [],
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
      interviewDate: interviewDate ?? this.interviewDate,
      isJustPreparing: isJustPreparing ?? this.isJustPreparing,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingDraftState> {
  @override
  OnboardingDraftState build() => const OnboardingDraftState();

  void setStep(int index) => state = state.copyWith(stepIndex: index);

  void updateNameRole(String name, String role) =>
      state = state.copyWith(name: name, targetRole: role);

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
      final cleanRole = state.targetRole.trim();
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
        if (cleanRole.isNotEmpty) {
          final existing = await db.applicationDao.watchAllApplications().first;
          for (final company in state.targetCompanies) {
            if (existing.any(
              (a) => a.company == company && a.role == cleanRole,
            )) {
              continue;
            }
            await db.applicationDao.insertApplication(
              ApplicationTableCompanion.insert(
                company: company,
                role: cleanRole,
                currentStage: const drift.Value('wishlist'),
              ),
            );
          }
        }
      });
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
  final _companyCustomController = TextEditingController();

  static const _totalSteps = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _companyCustomController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    ref.read(onboardingProvider.notifier).setStep(step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
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
          content: Text('Could not save setup. Please try again.'),
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
          leading: currentStep > 0
              ? Padding(
                  padding: const EdgeInsets.all(AppSpace.s8point0),
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
              _StepNameAndRole(
                nameController: _nameController,
                roleController: _roleController,
                onContinue: _nextStep,
              ),
              _StepTargetCompanies(
                customController: _companyCustomController,
                onContinue: _nextStep,
              ),
              _StepDone(onFinish: _finishOnboarding),
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
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
          width: isCurrent ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: AppGeometry.roundedr3,
            color: isCurrent
                ? context.accentPrimary
                : isCompleted
                ? context.accentPrimary.withValues(alpha: 0.4)
                : context.divider,
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 1: Name + Role
// ---------------------------------------------------------------------------

class _StepNameAndRole extends ConsumerStatefulWidget {
  final TextEditingController nameController;
  final TextEditingController roleController;
  final VoidCallback onContinue;

  const _StepNameAndRole({
    required this.nameController,
    required this.roleController,
    required this.onContinue,
  });

  @override
  ConsumerState<_StepNameAndRole> createState() => _StepNameAndRoleState();
}

class _StepNameAndRoleState extends ConsumerState<_StepNameAndRole> {
  static const _roleSuggestions = [
    'Backend Engineer',
    'Frontend Engineer',
    'Full Stack Engineer',
    'Mobile Engineer',
    'DevOps / SRE',
    'Engineering Manager',
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

    final name = widget.nameController.text.trim();
    final role = widget.roleController.text.trim();
    final isNameValid = name.length >= 2;
    final canContinue = isNameValid;

    String buttonLabel = 'Continue';
    if (!isNameValid) {
      buttonLabel = 'Enter your name';
    }

    return _ScrollableSetup(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s22,
          vertical: AppSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Let\'s build your system.',
              style: AscentTextStyles.displayLarge
                  .copyWith(color: textPrimary)
                  .merge(AppTypeRoles.typeRole35),
            ),
            const SizedBox(height: 6),
            Text(
              'Personalize your workspace, or tap Start now to explore. Career details can be added later.',
              style: AscentTextStyles.bodyMedium.copyWith(color: textMuted),
            ),
            const SizedBox(height: 24),

            // Name field
            Row(
              children: [
                Text(
                  'Your Name',
                  style: AscentTextStyles.labelSmall
                      .copyWith(color: textPrimary)
                      .merge(AppTypeRoles.typeRole8),
                ),
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: AppTypeRoles.typeRole9.copyWith(
                    color: context.stateDanger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: widget.nameController,
              textCapitalization: TextCapitalization.words,
              style: AscentTextStyles.bodyMedium.copyWith(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Alex',
                errorText: widget.nameController.text.isNotEmpty && !isNameValid
                    ? 'Name must be at least 2 characters'
                    : null,
              ),
              onChanged: (val) {
                ref
                    .read(onboardingProvider.notifier)
                    .updateNameRole(val, widget.roleController.text);
              },
            ),
            const SizedBox(height: 18),

            Text(
              'Target Role (optional)',
              style: AscentTextStyles.labelSmall
                  .copyWith(color: textPrimary)
                  .merge(AppTypeRoles.typeRole8),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: widget.roleController,
              textCapitalization: TextCapitalization.words,
              style: AscentTextStyles.bodyMedium.copyWith(color: textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Backend Engineer',
              ),
              onChanged: (val) {
                ref
                    .read(onboardingProvider.notifier)
                    .updateNameRole(widget.nameController.text, val);
              },
            ),
            const SizedBox(height: 14),

            // Suggestion chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _roleSuggestions.map((suggestion) {
                return AppPill.action(
                  label: Text(suggestion),
                  backgroundColor: context.bgSurface,
                  side: BorderSide(
                    color: context.divider,
                    width: AppBorderScale.w0point8,
                  ),
                  labelStyle: AscentTextStyles.bodySmall
                      .copyWith(color: textPrimary)
                      .merge(AppTypeRoles.typeRole23),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s8,
                    vertical: AppSpace.s2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppGeometry.roundedr8,
                  ),
                  onPressed: () {
                    widget.roleController.text = suggestion;
                    ref
                        .read(onboardingProvider.notifier)
                        .updateNameRole(widget.nameController.text, suggestion);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            AscentButton.primary(
              label: buttonLabel,
              onPressed: canContinue
                  ? () {
                      ref
                          .read(onboardingProvider.notifier)
                          .updateNameRole(name, role);
                      widget.onContinue();
                    }
                  : null,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 2: Target Companies
// ---------------------------------------------------------------------------

class _StepTargetCompanies extends ConsumerWidget {
  final TextEditingController customController;
  final VoidCallback onContinue;

  const _StepTargetCompanies({
    required this.customController,
    required this.onContinue,
  });

  static const _popularCompanies = [
    'Google',
    'Amazon',
    'Microsoft',
    'Meta',
    'Apple',
    'Netflix',
    'Stripe',
    'Uber',
    'Atlassian',
    'Coinbase',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final selected = state.targetCompanies;
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;

    return _ScrollableSetup(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s22,
          vertical: AppSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Target Companies',
              style: AscentTextStyles.displayLarge
                  .copyWith(color: textPrimary)
                  .merge(AppTypeRoles.typeRole35),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose companies if you are preparing for interviews. You can add them later in Settings.',
              style: AscentTextStyles.bodyMedium.copyWith(color: textMuted),
            ),
            const SizedBox(height: 20),

            // Custom company input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customController,
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Add custom company...',
                    ),
                    onSubmitted: (val) {
                      ref
                          .read(onboardingProvider.notifier)
                          .addCustomCompany(val);
                      customController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                AscentButton.icon(
                  icon: Icons.add_rounded,
                  compact: false,
                  onPressed: () {
                    ref
                        .read(onboardingProvider.notifier)
                        .addCustomCompany(customController.text);
                    customController.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Quick select (choose at least 1):',
              style: AscentTextStyles.labelSmall.copyWith(color: textMuted),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _popularCompanies.map((comp) {
                final isChosen = selected.contains(comp);
                return AppPill.filter(
                  label: Text(comp),
                  selected: isChosen,
                  selectedColor: context.accentPrimary.withValues(alpha: 0.14),
                  checkmarkColor: context.accentPrimary,
                  backgroundColor: context.bgSurface,
                  side: BorderSide(
                    color: isChosen ? context.accentPrimary : context.divider,
                    width: AppBorderScale.w0point8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppGeometry.roundedr8,
                  ),
                  labelStyle: AscentTextStyles.bodySmall
                      .copyWith(
                        color: isChosen ? context.accentPrimary : textPrimary,
                      )
                      .merge(AppStateTypography.stateType10(state0: isChosen)),
                  onSelected: (_) {
                    ref.read(onboardingProvider.notifier).toggleCompany(comp);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            AscentButton.primary(
              label: selected.isEmpty
                  ? 'Continue without companies'
                  : 'Continue (${selected.length} chosen)',
              onPressed: onContinue,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 3: Done — Ready for Takeoff
// ---------------------------------------------------------------------------

class _StepDone extends StatelessWidget {
  final VoidCallback onFinish;

  const _StepDone({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;

    return _ScrollableSetup(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s24,
          vertical: AppSpace.s20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),

            AppCard(
              width: 72,
              height: 72,
              nightDecoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.12),
                borderRadius: AppGeometry.roundedr20,
                border: Border.all(
                  color: context.accentPrimary.withValues(alpha: 0.3),
                  width: AppBorderScale.w0point9,
                ),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: context.accentPrimary,
                size: 36,
              ),
            ),
            const SizedBox(height: 22),

            Text(
              'Your workspace is ready',
              style: AscentTextStyles.displayLarge
                  .copyWith(color: textPrimary)
                  .merge(AppTypeRoles.typeRole11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Track daily study blocks, practice interview questions, solve DSA, and advance your pipeline.',
                style: AscentTextStyles.bodyMedium.copyWith(color: textMuted),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 28),

            // Feature highlights
            AscentCard(
              hasBorder: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s14,
                vertical: AppSpace.s12,
              ),
              child: Column(
                children: [
                  _FeatureRow(
                    icon: Icons.timer_outlined,
                    title: 'Deep Work Timer',
                    subtitle: 'Precision focus tracking without distractions',
                  ),
                  AppDivider(color: context.divider, height: 16),
                  _FeatureRow(
                    icon: Icons.view_kanban_outlined,
                    title: 'Job Pipeline',
                    subtitle: 'Manage applications from wishlist to offer',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            AscentButton.primary(
              label: 'Launch Dashboard →',
              onPressed: onFinish,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.accentPrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AscentTextStyles.labelSmall
                    .copyWith(color: context.textPrimary)
                    .merge(AppTypeRoles.typeRole8),
              ),
              Text(
                subtitle,
                style: AscentTextStyles.bodySmall
                    .copyWith(color: context.textMuted)
                    .merge(AppTypeRoles.typeRole4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScrollableSetup extends StatelessWidget {
  const _ScrollableSetup({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: child,
      ),
    ),
  );
}
