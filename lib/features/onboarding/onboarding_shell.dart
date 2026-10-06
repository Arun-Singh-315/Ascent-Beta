import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
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

  Future<void> submitAndSeedPlan(BuildContext context, WidgetRef ref) async {
    state = state.copyWith(isSubmitting: true);

    try {
      final profileDao = ref.read(userProfileDaoProvider);

      // 1. Upsert Profile
      await profileDao.upsertProfile(
        UserProfileTableCompanion(
          name: drift.Value(state.name.isEmpty ? 'Learner' : state.name),
          targetRole: drift.Value(state.targetRole.isEmpty ? 'Software Engineer' : state.targetRole),
          targetCompanies: drift.Value(jsonEncode(state.targetCompanies)),
          interviewDate: drift.Value(state.interviewDate),
          weeklyHoursAvailable: drift.Value(state.weeklyHours),
          onboardingComplete: const drift.Value(true),
          lastOpenedAt: drift.Value(DateTime.now()),
        ),
      );

      // 2. Seed initial pipeline applications from target companies
      final appDao = ref.read(applicationDaoProvider);
      for (final comp in state.targetCompanies) {
        await appDao.insertApplication(
          ApplicationTableCompanion.insert(
            company: comp,
            role: state.targetRole.isEmpty ? 'Software Engineer' : state.targetRole,
            currentStage: const drift.Value('wishlist'),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
      }

      // Mark SharedPreferences complete
      await markOnboardingComplete(ref);
    } catch (e) {
      debugPrint('Error saving onboarding data: $e');
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
    await ref.read(onboardingProvider.notifier).submitAndSeedPlan(context, ref);
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PlanReadyDialog(
        targetRole: ref.read(onboardingProvider).targetRole,
        companiesCount: ref.read(onboardingProvider).targetCompanies.length,
      ),
    );

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final currentStep = state.stepIndex;
    final canSkip = currentStep == 1;

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
                  padding: const EdgeInsets.all(8.0),
                  child: AscentButton.icon(
                    icon: Icons.arrow_back_rounded,
                    compact: true,
                    onPressed: _prevStep,
                  ),
                )
              : null,
          title: _ProgressDots(
            total: _totalSteps,
            current: currentStep,
          ),
          centerTitle: true,
          actions: [
            if (canSkip)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: AscentButton.ghost(
                  label: 'Skip',
                  compact: true,
                  onPressed: _nextStep,
                ),
              )
            else
              const SizedBox(width: 48),
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
              _StepDone(
                onFinish: _finishOnboarding,
              ),
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
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isCurrent ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
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

class _StepNameAndRole extends ConsumerWidget {
  final TextEditingController nameController;
  final TextEditingController roleController;
  final VoidCallback onContinue;

  const _StepNameAndRole({
    required this.nameController,
    required this.roleController,
    required this.onContinue,
  });

  static const _roleSuggestions = [
    'Backend Engineer',
    'Frontend Engineer',
    'Full Stack Engineer',
    'Mobile Engineer',
    'DevOps / SRE',
    'Engineering Manager',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Let\'s build your system.',
            style: AscentTextStyles.displayLarge.copyWith(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'What should we call you, and what role are you aiming for?',
            style: AscentTextStyles.bodyMedium.copyWith(color: textMuted),
          ),
          const SizedBox(height: 24),

          // Name field
          Text(
            'Your Name',
            style: AscentTextStyles.labelSmall.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            style: AscentTextStyles.bodyMedium.copyWith(color: textPrimary),
            decoration: const InputDecoration(
              hintText: 'e.g. Alex',
            ),
            onChanged: (val) {
              ref.read(onboardingProvider.notifier).updateNameRole(val, roleController.text);
            },
          ),
          const SizedBox(height: 18),

          // Target Role field
          Text(
            'Target Role',
            style: AscentTextStyles.labelSmall.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: roleController,
            textCapitalization: TextCapitalization.words,
            style: AscentTextStyles.bodyMedium.copyWith(color: textPrimary),
            decoration: const InputDecoration(
              hintText: 'e.g. Backend Engineer',
            ),
            onChanged: (val) {
              ref.read(onboardingProvider.notifier).updateNameRole(nameController.text, val);
            },
          ),
          const SizedBox(height: 14),

          // Suggestion chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _roleSuggestions.map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                backgroundColor: context.bgSurface,
                side: BorderSide(color: context.divider, width: 0.8),
                labelStyle: AscentTextStyles.bodySmall.copyWith(
                  color: textPrimary,
                  fontSize: 11.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onPressed: () {
                  roleController.text = suggestion;
                  ref.read(onboardingProvider.notifier).updateNameRole(nameController.text, suggestion);
                },
              );
            }).toList(),
          ),

          const Spacer(),

          AscentButton.primary(
            label: 'Continue',
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                nameController.text = 'Learner';
              }
              if (roleController.text.trim().isEmpty) {
                roleController.text = 'Software Engineer';
              }
              ref.read(onboardingProvider.notifier).updateNameRole(
                nameController.text.trim(),
                roleController.text.trim(),
              );
              onContinue();
            },
          ),
          const SizedBox(height: 12),
        ],
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
    'Google', 'Amazon', 'Microsoft', 'Meta', 'Apple',
    'Netflix', 'Stripe', 'Uber', 'Atlassian', 'Coinbase',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final selected = state.targetCompanies;
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Target Companies',
            style: AscentTextStyles.displayLarge.copyWith(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select or add target companies to seed your application pipeline.',
            style: AscentTextStyles.bodyMedium.copyWith(color: textMuted),
          ),
          const SizedBox(height: 20),

          // Custom company input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customController,
                  style: AscentTextStyles.bodyMedium.copyWith(color: textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Add custom company...',
                  ),
                  onSubmitted: (val) {
                    ref.read(onboardingProvider.notifier).addCustomCompany(val);
                    customController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              AscentButton.icon(
                icon: Icons.add_rounded,
                compact: false,
                onPressed: () {
                  ref.read(onboardingProvider.notifier).addCustomCompany(customController.text);
                  customController.clear();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Quick select:',
            style: AscentTextStyles.labelSmall.copyWith(color: textMuted),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _popularCompanies.map((comp) {
              final isChosen = selected.contains(comp);
              return FilterChip(
                label: Text(comp),
                selected: isChosen,
                selectedColor: context.accentPrimary.withValues(alpha: 0.14),
                checkmarkColor: context.accentPrimary,
                backgroundColor: context.bgSurface,
                side: BorderSide(
                  color: isChosen ? context.accentPrimary : context.divider,
                  width: 0.8,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                labelStyle: AscentTextStyles.bodySmall.copyWith(
                  color: isChosen ? context.accentPrimary : textPrimary,
                  fontWeight: isChosen ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  ref.read(onboardingProvider.notifier).toggleCompany(comp);
                },
              );
            }).toList(),
          ),

          const Spacer(),

          AscentButton.primary(
            label: selected.isEmpty ? 'Continue' : 'Continue (${selected.length} chosen)',
            onPressed: onContinue,
          ),
          const SizedBox(height: 12),
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),

          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.accentPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.accentPrimary.withValues(alpha: 0.3), width: 0.9),
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
            style: AscentTextStyles.displayLarge.copyWith(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                _FeatureRow(
                  icon: Icons.timer_outlined,
                  title: 'Deep Work Timer',
                  subtitle: 'Precision focus tracking without distractions',
                ),
                Divider(color: context.divider, height: 16),
                _FeatureRow(
                  icon: Icons.view_kanban_outlined,
                  title: 'Job Pipeline',
                  subtitle: 'Manage applications from wishlist to offer',
                ),
                Divider(color: context.divider, height: 16),
                _FeatureRow(
                  icon: Icons.bolt_outlined,
                  title: 'Daily Momentum',
                  subtitle: 'Continuous consistency and streak analytics',
                ),
              ],
            ),
          ),

          const Spacer(),

          AscentButton.primary(
            label: 'Launch Dashboard →',
            onPressed: onFinish,
          ),
          const SizedBox(height: 12),
        ],
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
                style: AscentTextStyles.labelSmall.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: AscentTextStyles.bodySmall.copyWith(
                  color: context.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transition Dialog
// ---------------------------------------------------------------------------

class _PlanReadyDialog extends StatelessWidget {
  final String targetRole;
  final int companiesCount;

  const _PlanReadyDialog({
    required this.targetRole,
    required this.companiesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: context.accentPrimary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Workspace Ready',
              style: AscentTextStyles.displaySmall.copyWith(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Configured for $targetRole with $companiesCount target companies ready in your pipeline.',
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AscentButton.primary(
              label: 'Enter Ascent',
              compact: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
