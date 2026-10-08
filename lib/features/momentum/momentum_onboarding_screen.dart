import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/momentum/momentum_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_scaffold.dart';

class MomentumOnboardingScreen extends ConsumerStatefulWidget {
  const MomentumOnboardingScreen({super.key});

  @override
  ConsumerState<MomentumOnboardingScreen> createState() => _MomentumOnboardingScreenState();
}

class _MomentumOnboardingScreenState extends ConsumerState<MomentumOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isGenerating = false;

  // Step 1: Physical Baseline
  String _biologicalSex = 'male';
  final _ageController = TextEditingController(text: '25');
  final _heightController = TextEditingController(text: '175');
  final _weightController = TextEditingController(text: '78.5');
  final _targetWeightController = TextEditingController(text: '73.0');

  // Step 2: Circadian Baseline
  TimeOfDay _baselineWakeTime = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _baselineBedTime = const TimeOfDay(hour: 23, minute: 30);
  bool _notificationsAllowed = false;

  // Step 3: Gym & Training Split
  String _fitnessExperience = 'intermediate'; // beginner, intermediate, advanced
  int _gymDaysPerWeek = 4; // 3, 4, 5
  String _gymSplit = 'upper_lower'; // upper_lower, full_body
  int _workoutDurationMinutes = 45; // 30, 45, 60

  // Step 4: Walking & Recovery
  String _walkingBaseline = 'moderate'; // light, moderate, active
  final _limitationsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final granted = await NotificationService.instance.areNotificationsEnabled();
    if (mounted) setState(() => _notificationsAllowed = granted);
  }

  Future<void> _requestPermissions() async {
    HapticFeedback.lightImpact();
    final granted = await NotificationService.instance.requestPermissions();
    if (mounted) {
      setState(() => _notificationsAllowed = granted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted ? 'Alarms & notifications enabled!' : 'Permission denied. Please enable in settings.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _limitationsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _generatePlan();
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _generatePlan() async {
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    try {
      final weight = double.tryParse(_weightController.text) ?? 75.0;
      final targetWeight = double.tryParse(_targetWeightController.text);
      final age = int.tryParse(_ageController.text) ?? 25;
      final height = double.tryParse(_heightController.text) ?? 175.0;

      final baselineWakeMin = (_baselineWakeTime.hour * 60) + _baselineWakeTime.minute;
      final baselineBedMin = (_baselineBedTime.hour * 60) + _baselineBedTime.minute;

      final service = ref.read(momentumServiceProvider);
      await service.startChallenge(
        currentWeightKg: weight,
        targetWeightKg: targetWeight,
        age: age,
        heightCm: height,
        biologicalSex: _biologicalSex,
        targetWakeMinutes: 360, // 06:00 AM
        baselineWakeMinutes: baselineWakeMin,
        targetWindDownMinutes: baselineBedMin.clamp(1260, 1380), // 9:00 PM to 11:00 PM
        gymSplit: _gymSplit,
        gymDaysPerWeek: _gymDaysPerWeek,
        workoutDurationMinutes: _workoutDurationMinutes,
        walkingBaselineLevel: _walkingBaseline,
        fitnessExperience: _fitnessExperience,
        physicalLimitations: _limitationsController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Momentum protocol initialized!'),
            duration: Duration(seconds: 2),
          ),
        );
        context.go('/momentum');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate challenge: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return AscentScaffold(
      title: 'Momentum',
      subtitle: 'Personalized protocol assessment',
      glow2: g.claySoft,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _previousStep,
      ),
      body: Column(
        children: [
          // Step Indicator Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: List.generate(4, (index) {
                final isPassed = index <= _currentStep;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isPassed ? g.clay : g.fill,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPhysicalBaselineStep(context),
                _buildCircadianStep(context),
                _buildTrainingSplitStep(context),
                _buildWalkingAndSummaryStep(context),
              ],
            ),
          ),

          // Bottom Navigation Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: g.bg.withValues(alpha: 0.9),
              border: Border(top: BorderSide(color: g.edge)),
            ),
            child: Row(
              children: [
                if (_currentStep > 0) ...[
                  Expanded(
                    flex: 1,
                    child: AscentButton.outlined(
                      label: 'Back',
                      onPressed: _previousStep,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: AscentButton.primary(
                    label: _currentStep == 3 ? (_isGenerating ? 'Building Plan...' : 'Generate Plan ⚡') : 'Next Step',
                    loading: _isGenerating,
                    onPressed: _nextStep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 1: PHYSICAL BASELINE ─────────────────────────────────────────────
  Widget _buildPhysicalBaselineStep(BuildContext context) {
    final g = context.glass;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '1. Baseline Assessment',
          style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          'To calculate personalized MET caloric burn and progressive walking volume.',
          style: AscentTextStyles.bodyMedium.copyWith(color: g.inkMuted),
        ),
        const SizedBox(height: 20),

        AscentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Biological Sex', style: AscentTextStyles.labelSmall.copyWith(color: g.inkMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Male')),
                      selected: _biologicalSex == 'male',
                      selectedColor: g.clay,
                      onSelected: (val) {
                        if (val) setState(() => _biologicalSex = 'male');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Female')),
                      selected: _biologicalSex == 'female',
                      selectedColor: g.clay,
                      onSelected: (val) {
                        if (val) setState(() => _biologicalSex = 'female');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        suffixText: 'yrs',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        suffixText: 'cm',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Current Weight',
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _targetWeightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Target Weight (Opt)',
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STEP 2: CIRCADIAN & NOTIFICATIONS ─────────────────────────────────────
  Widget _buildCircadianStep(BuildContext context) {
    final g = context.glass;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '2. Circadian Rhythm & Alarms',
          style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          'We transition your body gradually towards a locked 6:00 AM wake-up target.',
          style: AscentTextStyles.bodyMedium.copyWith(color: g.inkMuted),
        ),
        const SizedBox(height: 20),

        AscentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Sleep Schedule', style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bedtime_rounded, color: g.clay),
                title: const Text('Current Bedtime'),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(context: context, initialTime: _baselineBedTime);
                    if (time != null) setState(() => _baselineBedTime = time);
                  },
                  child: Text(_baselineBedTime.format(context), style: TextStyle(color: g.clay, fontWeight: FontWeight.bold)),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.wb_sunny_rounded, color: g.clay),
                title: const Text('Current Wake-Up Time'),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(context: context, initialTime: _baselineWakeTime);
                    if (time != null) setState(() => _baselineWakeTime = time);
                  },
                  child: Text(_baselineWakeTime.format(context), style: TextStyle(color: g.clay, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        AscentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.alarm_on_rounded, color: g.sage, size: 20),
                  const SizedBox(width: 8),
                  Text('Target 6:00 AM Wake & Evening Alert', style: TextStyle(color: g.ink, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• 10:00 PM: Evening wind-down & sleep recovery protection.\n• 06:00 AM: Exact wake-up alarm with persistent vibration.\n• Transition: Wake-up steps 15-20 mins earlier each day during Week 1.',
                style: AscentTextStyles.bodySmall.copyWith(color: g.inkSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              AscentButton.outlined(
                label: _notificationsAllowed ? '✓ Alarms & Notifications Enabled' : 'Enable Alarms & Notifications',
                compact: true,
                onPressed: _requestPermissions,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STEP 3: TRAINING SPLIT ────────────────────────────────────────────────
  Widget _buildTrainingSplitStep(BuildContext context) {
    final g = context.glass;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '3. Gym Training Structure',
          style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          'Balanced resistance training calibrated to your weekly availability.',
          style: AscentTextStyles.bodyMedium.copyWith(color: g.inkMuted),
        ),
        const SizedBox(height: 20),

        AscentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Training Experience', style: AscentTextStyles.labelSmall.copyWith(color: g.inkMuted)),
              const SizedBox(height: 8),
              Row(
                children: ['beginner', 'intermediate', 'advanced'].map((exp) {
                  final isSel = _fitnessExperience == exp;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(exp[0].toUpperCase() + exp.substring(1), style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        selectedColor: g.clay,
                        onSelected: (val) {
                          if (val) setState(() => _fitnessExperience = exp);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              Text('Workout Split', style: AscentTextStyles.labelSmall.copyWith(color: g.inkMuted)),
              const SizedBox(height: 8),
              _buildSelectableTile(
                title: '4-Day Upper / Lower Split (Recommended)',
                subtitle: 'Mon/Tue & Thu/Fri workouts with active recovery wednesdays.',
                isSelected: _gymSplit == 'upper_lower',
                onTap: () => setState(() {
                  _gymSplit = 'upper_lower';
                  _gymDaysPerWeek = 4;
                }),
                g: g,
              ),
              const SizedBox(height: 8),
              _buildSelectableTile(
                title: '3-Day Full Body Split',
                subtitle: 'Mon/Wed/Fri compound lifting with recovery days between.',
                isSelected: _gymSplit == 'full_body',
                onTap: () => setState(() {
                  _gymSplit = 'full_body';
                  _gymDaysPerWeek = 3;
                }),
                g: g,
              ),
              const SizedBox(height: 16),

              Text('Workout Duration', style: AscentTextStyles.labelSmall.copyWith(color: g.inkMuted)),
              const SizedBox(height: 8),
              Row(
                children: [30, 45, 60].map((mins) {
                  final isSel = _workoutDurationMinutes == mins;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$mins Mins', style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        selectedColor: g.clay,
                        onSelected: (val) {
                          if (val) setState(() => _workoutDurationMinutes = mins);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STEP 4: WALKING & SUMMARY ─────────────────────────────────────────────
  Widget _buildWalkingAndSummaryStep(BuildContext context) {
    final g = context.glass;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '4. Walking Baseline & Constraints',
          style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          'Progression scales up weekly to drive steady, sustainable fat loss.',
          style: AscentTextStyles.bodyMedium.copyWith(color: g.inkMuted),
        ),
        const SizedBox(height: 20),

        AscentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Walking Baseline', style: AscentTextStyles.labelSmall.copyWith(color: g.inkMuted)),
              const SizedBox(height: 8),
              _buildSelectableTile(
                title: 'Light (< 4,000 steps/day)',
                subtitle: 'Starts at 2.0 km / 20 mins brisk walk.',
                isSelected: _walkingBaseline == 'light',
                onTap: () => setState(() => _walkingBaseline = 'light'),
                g: g,
              ),
              const SizedBox(height: 8),
              _buildSelectableTile(
                title: 'Moderate (4,000–8,000 steps/day)',
                subtitle: 'Starts at 3.0 km / 30 mins brisk walk.',
                isSelected: _walkingBaseline == 'moderate',
                onTap: () => setState(() => _walkingBaseline = 'moderate'),
                g: g,
              ),
              const SizedBox(height: 8),
              _buildSelectableTile(
                title: 'Active (8,000+ steps/day)',
                subtitle: 'Starts at 4.5 km / 45 mins brisk walk.',
                isSelected: _walkingBaseline == 'active',
                onTap: () => setState(() => _walkingBaseline = 'active'),
                g: g,
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _limitationsController,
                decoration: const InputDecoration(
                  labelText: 'Physical Limitations / Injuries (Optional)',
                  hintText: 'e.g. Lower back stiffness, minor left knee tweak...',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        AscentCard(
          color: g.clay.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: g.clay, size: 20),
                  const SizedBox(width: 8),
                  Text('Momentum Blueprint Ready', style: TextStyle(color: g.ink, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• 30 Days of synchronized daily commitments.\n• Direct integration with Ascent GPS Walk & live timers.\n• Adaptive Rescheduling: adjust or swap sessions if your schedule shifts.\n• Strict but Supportive Coach: zero guilt, honest tracking.',
                style: AscentTextStyles.bodySmall.copyWith(color: g.inkSecondary, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required dynamic g,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? g.clay.withValues(alpha: 0.15) : g.fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? g.clay : g.edge,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? g.clay : g.inkMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? g.clay : g.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: g.inkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
