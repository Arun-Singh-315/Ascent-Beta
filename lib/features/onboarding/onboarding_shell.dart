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
  final int dsaRating; // 1-5
  final int systemDesignRating; // 1-5
  final int coreStackRating; // 1-5
  final int weeklyHours;
  final String? resumeFileName;
  final String? resumeFilePath;
  final bool isSubmitting;

  const OnboardingDraftState({
    this.stepIndex = 0,
    this.name = '',
    this.targetRole = '',
    this.targetCompanies = const [],
    this.interviewDate,
    this.isJustPreparing = true,
    this.dsaRating = 3,
    this.systemDesignRating = 2,
    this.coreStackRating = 3,
    this.weeklyHours = 12,
    this.resumeFileName,
    this.resumeFilePath,
    this.isSubmitting = false,
  });

  OnboardingDraftState copyWith({
    int? stepIndex,
    String? name,
    String? targetRole,
    List<String>? targetCompanies,
    DateTime? interviewDate,
    bool? isJustPreparing,
    int? dsaRating,
    int? systemDesignRating,
    int? coreStackRating,
    int? weeklyHours,
    String? resumeFileName,
    String? resumeFilePath,
    bool? isSubmitting,
  }) {
    return OnboardingDraftState(
      stepIndex: stepIndex ?? this.stepIndex,
      name: name ?? this.name,
      targetRole: targetRole ?? this.targetRole,
      targetCompanies: targetCompanies ?? this.targetCompanies,
      interviewDate: interviewDate ?? this.interviewDate,
      isJustPreparing: isJustPreparing ?? this.isJustPreparing,
      dsaRating: dsaRating ?? this.dsaRating,
      systemDesignRating: systemDesignRating ?? this.systemDesignRating,
      coreStackRating: coreStackRating ?? this.coreStackRating,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      resumeFileName: resumeFileName ?? this.resumeFileName,
      resumeFilePath: resumeFilePath ?? this.resumeFilePath,
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

  void setInterviewDate(DateTime? date) =>
      state = state.copyWith(interviewDate: date, isJustPreparing: false);

  void setJustPreparing() =>
      state = state.copyWith(interviewDate: null, isJustPreparing: true);

  void setSkillRatings({int? dsa, int? systemDesign, int? coreStack}) =>
      state = state.copyWith(
        dsaRating: dsa ?? state.dsaRating,
        systemDesignRating: systemDesign ?? state.systemDesignRating,
        coreStackRating: coreStack ?? state.coreStackRating,
      );

  void setWeeklyHours(int hours) => state = state.copyWith(weeklyHours: hours);

  void setResume(String name, String path) =>
      state = state.copyWith(resumeFileName: name, resumeFilePath: path);

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
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextStep() {
    final current = ref.read(onboardingProvider).stepIndex;
    if (current < _totalSteps - 1) {
      _goToStep(current + 1);
    } else {
      _showPayoffAndFinish();
    }
  }

  void _prevStep() {
    final current = ref.read(onboardingProvider).stepIndex;
    if (current > 0) {
      _goToStep(current - 1);
    }
  }

  Future<void> _showPayoffAndFinish() async {
    // Show transition "Your plan is ready" dialog / screen
    await ref.read(onboardingProvider.notifier).submitAndSeedPlan(context, ref);

    if (!mounted) return;

    // Show emotional payoff modal/screen
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

    // Step 0: Name + Role (Required - Hide skip)
    // Step 1: Target companies (Optional - Show skip)
    // Step 2: Done (no skip needed)
    final canSkip = currentStep == 1;

    return PopScope(
      canPop: currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
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
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: context.textPrimary,
                  onPressed: _prevStep,
                )
              : null,
          title: _ProgressDots(
            total: _totalSteps,
            current: currentStep,
          ),
          centerTitle: true,
          actions: [
            if (canSkip)
              TextButton(
                onPressed: _nextStep,
                child: Text(
                  'Skip for now',
                  style: AscentTextStyles.bodyMedium.copyWith(
                    color: context.textMuted,
                  ),
                ),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // Managed via Continue/Back
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
              onFinish: _showPayoffAndFinish,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress Dots Indicator
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
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isCurrent ? 24 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Let\'s build your plan.',
            style: AscentTextStyles.displayLarge.copyWith(color: context.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'What should we call you, and what target role are you preparing for?',
            style: AscentTextStyles.bodyLarge.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: 32),
          Text('Your Name', style: AscentTextStyles.labelLarge.copyWith(color: context.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Alex',
            ),
            onChanged: (val) {
              ref.read(onboardingProvider.notifier).updateNameRole(val, roleController.text);
            },
          ),
          const SizedBox(height: 24),
          Text('Target Role', style: AscentTextStyles.labelLarge.copyWith(color: context.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: roleController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Backend Engineer',
            ),
            onChanged: (val) {
              ref.read(onboardingProvider.notifier).updateNameRole(nameController.text, val);
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _roleSuggestions.map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                backgroundColor: context.bgSurface,
                side: BorderSide(color: context.divider),
                labelStyle: AscentTextStyles.bodySmall.copyWith(color: context.textPrimary),
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
          const SizedBox(height: 16),
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Target companies',
            style: AscentTextStyles.displayLarge.copyWith(color: context.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Add companies on your radar. This seeds your Application Pipeline board.',
            style: AscentTextStyles.bodyLarge.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customController,
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
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: context.accentPrimary,
                  foregroundColor: context.textOnPrimary,
                ),
                icon: const Icon(Icons.add_rounded),
                onPressed: () {
                  ref.read(onboardingProvider.notifier).addCustomCompany(customController.text);
                  customController.clear();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Popular choices:', style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularCompanies.map((comp) {
              final isChosen = selected.contains(comp);
              return FilterChip(
                label: Text(comp),
                selected: isChosen,
                selectedColor: context.accentPrimary.withValues(alpha: 0.18),
                checkmarkColor: context.accentPrimary,
                backgroundColor: context.bgSurface,
                side: BorderSide(
                  color: isChosen ? context.accentPrimary : context.divider,
                ),
                labelStyle: AscentTextStyles.bodyMedium.copyWith(
                  color: isChosen ? context.accentPrimary : context.textPrimary,
                  fontWeight: isChosen ? FontWeight.w600 : FontWeight.w400,
                ),
                onSelected: (_) {
                  ref.read(onboardingProvider.notifier).toggleCompany(comp);
                },
              );
            }).toList(),
          ),
          const Spacer(),
          AscentButton.primary(
            label: selected.isEmpty ? 'Continue' : 'Continue with ${selected.length} companies',
            onPressed: onContinue,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Screen 3: Done — Let's Go!
// ---------------------------------------------------------------------------

class _StepDone extends StatelessWidget {
  final VoidCallback onFinish;

  const _StepDone({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.accentPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              color: context.accentPrimary,
              size: 40,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'You\'re all set!',
            style: AscentTextStyles.displayLarge.copyWith(color: context.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Ascent is ready to help you land your next role.\nTrack tasks, log sessions, and crush interviews.',
            style: AscentTextStyles.bodyLarge.copyWith(color: context.textMuted),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          AscentButton.primary(
            label: 'Launch Dashboard →',
            onPressed: onFinish,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Your Plan Is Ready" Transition Dialog
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: context.accentPrimary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your plan is ready.',
              style: AscentTextStyles.displayMedium.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              'Ready for takeoff, $targetRole candidate! Your application board is set with $companiesCount target companies. Let\'s land that offer.',
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            AscentButton.primary(
              label: 'Launch Home Dashboard',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
