import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../challenge/challenge_providers.dart';
import 'home_shortcut_summary.dart';

class HomeLifeShelf extends ConsumerStatefulWidget {
  const HomeLifeShelf({super.key});

  @override
  ConsumerState<HomeLifeShelf> createState() => _HomeLifeShelfState();
}

class _HomeLifeShelfState extends ConsumerState<HomeLifeShelf> {
  int _selectedTabIndex = 0;
  bool _saving = false;

  static const _tabTitles = ['Water', 'Move', 'Chai', 'Care', 'Momentum'];
  static const _tabIds = ['hydration', 'walk', 'chai-break', 'medicine', 'momentum'];

  Future<void> _logWater(int amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final dao = ref.read(waterDaoProvider);
      final id = await dao.addWater(amount);
      if (mounted) {
        HapticFeedback.lightImpact();
        AscentSnackBar.show(
          context,
          message: '$amount ml water logged',
          actionLabel: 'Undo',
          onAction: () async {
            try {
              await dao.deleteWater(id);
            } catch (_) {
              if (mounted) {
                AscentSnackBar.error(
                  context,
                  message: 'Could not undo water log. Please retry.',
                );
              }
            }
          },
        );
      }
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not log water. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _customWaterDialog() async {
    final textController = TextEditingController(text: '250');
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Custom water amount'),
          content: TextField(
            controller: textController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              suffixText: 'ml',
              hintText: 'e.g. 350',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final val = int.tryParse(textController.text.trim());
                if (val != null && val > 0) Navigator.of(ctx).pop(val);
              },
              child: const Text('Log'),
            ),
          ],
        );
      },
    );
    if (picked != null && picked > 0) {
      await _logWater(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final waterState = ref.watch(todayWaterMlStreamProvider);
    final goalState = ref.watch(dailyWaterGoalStreamProvider);
    final water = waterState.value ?? 500;
    final goal = goalState.value ?? 2500;

    final doseState = ref.watch(todayMedicineLogsStreamProvider);
    final doses = doseState.value ?? [];
    final takenDoses = doses.where((d) => d.isTaken).length;

    final walkMeters = ref.watch(todayWalkDistanceStreamProvider).value ?? 0;
    final pauseCount = ref.watch(todayPauseCountProvider).value ?? 0;
    final challenge = ref.watch(activeChallengeProvider).value;

    final currentId = _tabIds[_selectedTabIndex];

    return SectionCard(
      key: const ValueKey('home_life_shelf_enclosure'),
      icon: Icons.water_drop_outlined,
      title: 'Daily rhythm',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Scrollable SegmentedTabs
          SegmentedTabs(
            tabs: _tabTitles,
            selectedIndex: _selectedTabIndex,
            onTabSelected: (i) {
              HapticFeedback.selectionClick();
              setState(() => _selectedTabIndex = i);
            },
          ),
          const SizedBox(height: 18),

          // 2. Tab Panel
          if (currentId == 'hydration') ...[
            _buildWaterPanel(c, water, goal),
          ] else if (currentId == 'walk') ...[
            _buildWalkPanel(c, walkMeters),
          ] else if (currentId == 'chai-break') ...[
            _buildChaiPanel(c, pauseCount),
          ] else if (currentId == 'medicine') ...[
            _buildCarePanel(c, doses, takenDoses),
          ] else ...[
            _buildMomentumPanel(c, challenge),
          ],
        ],
      ),
    );
  }

  Widget _buildWaterPanel(AppColors c, int water, int goal) {
    final left = (goal - water).clamp(0, goal);
    final filledSegments = ((water / goal) * 10).round().clamp(0, 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Caption
        Text(
          'DRANK TODAY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 4),

        // Big number + 56px circle drop icon
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  '$water ml',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
              ),
              child: Icon(
                Icons.water_drop_outlined,
                size: 24,
                color: c.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 10 equal progress segments, 8px tall, radius 4
        Row(
          children: [
            for (int i = 0; i < 10; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < filledSegments ? c.accent : c.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                    border: i < filledSegments ? null : Border.all(color: c.border),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Caption: 2000 ml left · Goal 2500 ml
        Text(
          left > 0 ? '$left ml left · Goal $goal ml' : 'Goal reached · $goal ml',
          style: TextStyle(
            fontSize: 12,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Action row: +250 ml, +500 ml, Custom (unified chip style)
        Row(
          children: [
            Expanded(
              child: Material(
                color: c.surfaceAlt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Rd.chip),
                  side: BorderSide(color: c.border, width: 1.0),
                ),
                child: InkWell(
                  key: const ValueKey('water_chip_250'),
                  borderRadius: BorderRadius.circular(Rd.chip),
                  onTap: _saving ? null : () => _logWater(250),
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    child: Text(
                      '+250 ml',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: c.surfaceAlt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Rd.chip),
                  side: BorderSide(color: c.border, width: 1.0),
                ),
                child: InkWell(
                  key: const ValueKey('water_chip_500'),
                  borderRadius: BorderRadius.circular(Rd.chip),
                  onTap: _saving ? null : () => _logWater(500),
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    child: Text(
                      '+500 ml',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: c.surfaceAlt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Rd.chip),
                side: BorderSide(color: c.border, width: 1.0),
              ),
              child: InkWell(
                key: const ValueKey('water_chip_custom'),
                borderRadius: BorderRadius.circular(Rd.chip),
                onTap: _saving ? null : _customWaterDialog,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: Text(
                    'Custom',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalkPanel(AppColors c, num meters) {
    final km = (meters / 1000).toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DISTANCE TODAY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  '$km km',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.directions_walk_rounded, size: 24, color: c.accent),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Keep your movement rhythm steady.',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rd.field),
            ),
          ),
          onPressed: () => context.push('/walk'),
          icon: Icon(Icons.play_arrow_rounded, color: c.accent),
          label: Text('Start a walk', style: TextStyle(color: c.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildChaiPanel(AppColors c, int pauses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAUSES TODAY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  '$pauses ${pauses == 1 ? "pause" : "pauses"}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.coffee_outlined, size: 24, color: c.accent),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Mindful lo-fi study pause & tea brew.',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rd.field),
            ),
          ),
          onPressed: () => context.push('/chai-break'),
          icon: Icon(Icons.self_improvement_rounded, color: c.accent),
          label: Text('Start session', style: TextStyle(color: c.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildCarePanel(AppColors c, List<MedicineLog> doses, int taken) {
    final total = doses.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CARE & MEDICINE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  total > 0 ? '$taken/$total taken' : 'All clear',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.medication_outlined, size: 24, color: c.accent),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          total > 0 ? 'Follow your scheduled doses.' : 'No doses scheduled for today.',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rd.field),
            ),
          ),
          onPressed: () => context.push('/medicine'),
          icon: Icon(Icons.visibility_outlined, color: c.accent),
          label: Text(total > 0 ? 'View your doses' : 'Set up a routine',
              style: TextStyle(color: c.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildMomentumPanel(AppColors c, Challenge? challenge) {
    final title = challenge?.title ?? 'Daily Momentum';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHALLENGE & MOMENTUM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  height: 1.1,
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.military_tech_outlined, size: 24, color: c.accent),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          challenge != null
              ? 'Keep your momentum active for today.'
              : 'Choose a challenge to build momentum.',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Rd.field),
            ),
          ),
          onPressed: () => context.push('/momentum'),
          icon: Icon(Icons.flag_outlined, color: c.accent),
          label: Text('View challenge', style: TextStyle(color: c.textPrimary)),
        ),
      ],
    );
  }
}
