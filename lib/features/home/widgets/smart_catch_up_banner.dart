import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../money/add_transaction_sheet.dart';

enum CatchUpDomain {
  hydration,
  medicine,
  money,
}

class CatchUpItem {
  final CatchUpDomain domain;
  final String title;
  final String prompt;
  final IconData icon;
  final Color accentColor;
  final int? targetId;

  const CatchUpItem({
    required this.domain,
    required this.title,
    required this.prompt,
    required this.icon,
    required this.accentColor,
    this.targetId,
  });
}

/// "Smart Catch-Up Pod" — Non-blocking, 1-tap catch-up card on Home.
/// Proactively prompts the user when hydration, medicines, or daily expenses are pending,
/// allowing 1-tap inline logging so data keeps flowing without annoying modal popups.
class SmartCatchUpBanner extends ConsumerStatefulWidget {
  const SmartCatchUpBanner({super.key});

  @override
  ConsumerState<SmartCatchUpBanner> createState() => _SmartCatchUpBannerState();
}

class _SmartCatchUpBannerState extends ConsumerState<SmartCatchUpBanner> {
  final Set<CatchUpDomain> _dismissedDomains = {};
  String? _inlineSuccessNotice;
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final now = DateTime.now();

    // 1. Water live data
    final todayWater = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterLogs = ref.watch(todayWaterLogsStreamProvider).value ?? [];
    final lastWaterLog = waterLogs.isNotEmpty ? waterLogs.first.date : null;

    // 2. Medicine live data
    final medicineLogs = ref.watch(todayMedicineLogsStreamProvider).value ?? [];
    final activeMeds = ref.watch(activeMedicinesStreamProvider).value ?? [];

    // 3. Money live data
    final todaySpending = ref.watch(todaySpendingStreamProvider).value ?? 0.0;
    final prefs = ref.watch(sharedPreferencesProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final moneyCheckedToday = prefs.getString('ascent_money_checked_date') == todayStr;

    // Determine pending catch-up candidate
    CatchUpItem? activeItem;

    // Priority A: Medicine due and not taken
    if (!_dismissedDomains.contains(CatchUpDomain.medicine)) {
      final pendingDoses = medicineLogs.where((l) => !l.isTaken).toList();
      if (pendingDoses.isNotEmpty) {
        final firstDose = pendingDoses.first;
        final med = activeMeds.firstWhere(
          (m) => m.id == firstDose.medicineId,
          orElse: () => Medicine(
            id: firstDose.medicineId,
            name: 'Medicine',
            dosage: '1 Dose',
            scheduledTimes: '["08:00"]',
            durationDays: 7,
            startDate: now,
            instructions: 'After food',
            type: 'tablet',
            isActive: true,
            createdAt: now,
          ),
        );
        activeItem = CatchUpItem(
          domain: CatchUpDomain.medicine,
          title: 'Medicine check',
          prompt: '${med.name} is due. Did you take your dose?',
          icon: Icons.medical_services_outlined,
          accentColor: SharedControlColors.actionBlue,
          targetId: firstDose.id,
        );
      }
    }

    // Priority B: Hydration behind schedule (waking hours: 9 AM - 10 PM)
    if (activeItem == null &&
        !_dismissedDomains.contains(CatchUpDomain.hydration) &&
        now.hour >= 9 &&
        now.hour <= 22) {
      final hoursAwake = (now.hour - 8).clamp(1, 14);
      final expectedMl = hoursAwake * 180; // ~180ml per hour awake
      final isLongSinceLastLog = lastWaterLog != null &&
          now.difference(lastWaterLog).inHours >= 3;

      if (todayWater < expectedMl || (isLongSinceLastLog && todayWater < 2500)) {
        final diff = (expectedMl - todayWater).clamp(250, 1000);
        activeItem = CatchUpItem(
          domain: CatchUpDomain.hydration,
          title: 'Hydration check',
          prompt: todayWater == 0
              ? 'Haven\'t logged water yet today. Had a drink recently?'
              : '$diff mL behind schedule. Did you drink earlier or need water now?',
          icon: Icons.water_drop_outlined,
          accentColor: AscentColors.waterPrimary,
        );
      }
    }

    // Priority C: Evening money check (after 6 PM)
    if (activeItem == null &&
        !_dismissedDomains.contains(CatchUpDomain.money) &&
        now.hour >= 18 &&
        !moneyCheckedToday &&
        todaySpending == 0.0) {
      activeItem = const CatchUpItem(
        domain: CatchUpDomain.money,
        title: 'Daily Money Check',
        prompt: 'Did you spend any cash or UPI today?',
        icon: Icons.account_balance_wallet_outlined,
        accentColor: AscentColors.financePrimary,
      );
    }

    if (activeItem == null && _inlineSuccessNotice == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        customBorder: Border.all(
          color: (activeItem?.accentColor ?? g.clay).withValues(alpha: 0.35),
          width: 1.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_inlineSuccessNotice != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: SharedControlColors.successInk(context.isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _inlineSuccessNotice!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: g.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (activeItem != null) ...[
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: activeItem.accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activeItem.icon,
                      size: 14,
                      color: activeItem.accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeItem.title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: activeItem.accentColor,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _dismissedDomains.add(activeItem!.domain);
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: g.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                activeItem.prompt,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: g.ink,
                ),
              ),
              const SizedBox(height: 10),

              // 1-Tap Action Chips (Wrap-safe for 320px width & 2.0x font scaling)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _buildActionChips(context, activeItem),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionChips(BuildContext context, CatchUpItem item) {
    switch (item.domain) {
      case CatchUpDomain.hydration:
        return [
          _buildChip(
            label: '+250 mL',
            icon: Icons.local_drink_rounded,
            color: item.accentColor,
            onTap: () async {
              HapticFeedback.lightImpact();
              await ref.read(databaseProvider).waterDao.addWater(250);
              _showSuccess('Logged 250 mL! 💧');
            },
          ),
          _buildChip(
            label: '+500 mL',
            icon: Icons.water_drop_rounded,
            color: item.accentColor,
            onTap: () async {
              HapticFeedback.lightImpact();
              await ref.read(databaseProvider).waterDao.addWater(500);
              _showSuccess('Logged 500 mL! 💧');
            },
          ),
          _buildChip(
            label: 'Just drank',
            icon: Icons.check_rounded,
            color: item.accentColor,
            onTap: () async {
              HapticFeedback.lightImpact();
              await ref.read(databaseProvider).waterDao.addWater(250);
              _showSuccess('Hydration updated! 💧');
            },
          ),
        ];

      case CatchUpDomain.medicine:
        return [
          _buildChip(
            label: 'Taken ✓',
            icon: Icons.check_circle_outline_rounded,
            color: SharedControlColors.successInk(context.isDark),
            onTap: () async {
              HapticFeedback.lightImpact();
              if (item.targetId != null) {
                await ref
                    .read(databaseProvider)
                    .medicineDao
                    .setDoseTaken(item.targetId!, true);
              }
              _showSuccess('Dose recorded as taken! 💊');
            },
          ),
          _buildChip(
            label: 'Snooze 30m',
            icon: Icons.alarm_rounded,
            color: item.accentColor,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _dismissedDomains.add(CatchUpDomain.medicine);
              });
            },
          ),
        ];

      case CatchUpDomain.money:
        return [
          _buildChip(
            label: '₹0 Spent Today',
            icon: Icons.done_all_rounded,
            color: item.accentColor,
            onTap: () async {
              HapticFeedback.lightImpact();
              final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
              await ref
                  .read(sharedPreferencesProvider)
                  .setString('ascent_money_checked_date', todayStr);
              _showSuccess('Recorded: ₹0 spent today. 👏');
            },
          ),
          _buildChip(
            label: 'Log Expense',
            icon: Icons.add_circle_outline_rounded,
            color: item.accentColor,
            onTap: () {
              HapticFeedback.lightImpact();
              AddTransactionSheet.show(context);
            },
          ),
        ];
    }
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final g = context.glass;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: g.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    _successTimer?.cancel();
    setState(() {
      _inlineSuccessNotice = message;
    });
    _successTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _inlineSuccessNotice = null;
        });
      }
    });
  }
}
