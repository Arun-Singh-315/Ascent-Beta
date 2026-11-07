import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/ascent_dialog.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../money/add_transaction_sheet.dart';

enum CatchUpDomain { hydration, medicine, money }

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

/// Opens a focused, centered check-in when a quick daily action needs attention.
class SmartCatchUpBanner extends ConsumerStatefulWidget {
  const SmartCatchUpBanner({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  ConsumerState<SmartCatchUpBanner> createState() => _SmartCatchUpBannerState();
}

class _SmartCatchUpBannerState extends ConsumerState<SmartCatchUpBanner> {
  final Set<CatchUpDomain> _dismissedDomains = {};
  String? _promptedKey;
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final now = widget.clock?.call() ?? DateTime.now();

    // Wait until each stream has emitted so a loading placeholder cannot trigger
    // the wrong prompt (for example, a hydration check before medicine loads).
    final todayWaterAsync = ref.watch(todayWaterMlStreamProvider);
    final waterLogsAsync = ref.watch(todayWaterLogsStreamProvider);
    final medicineLogsAsync = ref.watch(todayMedicineLogsStreamProvider);
    final activeMedsAsync = ref.watch(activeMedicinesStreamProvider);
    final todaySpendingAsync = ref.watch(todaySpendingStreamProvider);
    if (!todayWaterAsync.hasValue ||
        !waterLogsAsync.hasValue ||
        !medicineLogsAsync.hasValue ||
        !activeMedsAsync.hasValue ||
        !todaySpendingAsync.hasValue) {
      return const SizedBox.shrink();
    }

    // 1. Water live data
    final todayWater = todayWaterAsync.value!;
    final waterLogs = waterLogsAsync.value!;
    final lastWaterLog = waterLogs.isNotEmpty ? waterLogs.first.date : null;

    // 2. Medicine live data
    final medicineLogs = medicineLogsAsync.value!;
    final activeMeds = activeMedsAsync.value!;

    // 3. Money live data
    final todaySpending = todaySpendingAsync.value!;
    final prefs = ref.watch(sharedPreferencesProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final moneyCheckedToday =
        prefs.getString('ascent_money_checked_date') == todayStr;

    // Hydration throttling & frequency capping (max 2 per day, min 4h cooldown)
    final hydrationSnoozeUntilMs =
        prefs.getInt('ascent_hydration_snooze_until') ?? 0;
    final hydrationSnoozed =
        now.millisecondsSinceEpoch < hydrationSnoozeUntilMs;
    final hydrationPromptCount =
        prefs.getInt('ascent_hydration_prompts_$todayStr') ?? 0;

    // Determine pending catch-up candidate
    final items = <CatchUpItem>[];

    // Priority A: Medicine due and not taken
    if (!_dismissedDomains.contains(CatchUpDomain.medicine)) {
      final pendingDoses = medicineLogs.where((log) {
        if (log.isTaken || log.dateStr.compareTo(todayStr) > 0) return false;
        if (log.dateStr != todayStr) return true;
        final time = log.timeSlot.split(':');
        if (time.length != 2) return false;
        final hour = int.tryParse(time[0]);
        final minute = int.tryParse(time[1]);
        return hour != null &&
            minute != null &&
            hour * 60 + minute <= now.hour * 60 + now.minute;
      }).toList();
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
        items.add(
          CatchUpItem(
            domain: CatchUpDomain.medicine,
            title: 'Medicine check',
            prompt:
                '${med.name} is due. Did you take the ${firstDose.timeSlot} dose?',
            icon: Icons.medical_services_outlined,
            accentColor: SharedControlColors.actionBlue,
            targetId: firstDose.id,
          ),
        );
      }
    }

    // Priority B: Hydration behind schedule (waking hours: 9 AM - 10 PM, capped at 2x/day, 4h cooldown)
    if (!_dismissedDomains.contains(CatchUpDomain.hydration) &&
        !hydrationSnoozed &&
        hydrationPromptCount < 2 &&
        now.hour >= 9 &&
        now.hour <= 22) {
      final hoursAwake = (now.hour - 8).clamp(1, 14);
      final expectedMl = hoursAwake * 180; // ~180ml per hour awake
      final isLongSinceLastLog =
          lastWaterLog != null && now.difference(lastWaterLog).inHours >= 3;

      if (todayWater < expectedMl ||
          (isLongSinceLastLog && todayWater < 2500)) {
        final diff = (expectedMl - todayWater).clamp(250, 1000);
        items.add(
          CatchUpItem(
            domain: CatchUpDomain.hydration,
            title: 'Hydration check',
            prompt: todayWater == 0
                ? 'Haven\'t logged water yet today. Had a drink recently?'
                : '$diff mL behind schedule. Did you drink earlier or need water now?',
            icon: Icons.water_drop_outlined,
            accentColor: AscentColors.waterPrimary,
          ),
        );
      }
    }

    // Priority C: Evening money check (after 6 PM)
    if (!_dismissedDomains.contains(CatchUpDomain.money) &&
        now.hour >= 18 &&
        !moneyCheckedToday &&
        todaySpending == 0.0) {
      items.add(
        const CatchUpItem(
          domain: CatchUpDomain.money,
          title: 'Daily Money Check',
          prompt: 'Did you spend any cash or UPI today?',
          icon: Icons.account_balance_wallet_outlined,
          accentColor: AscentColors.financePrimary,
        ),
      );
    }

    if (items.isNotEmpty) _queueDialog(context, items, todayStr);
    return const SizedBox.shrink();
  }

  void _queueDialog(
    BuildContext context,
    List<CatchUpItem> items,
    String today,
  ) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final key =
        '$today:${items.map((item) => '${item.domain.name}:${item.targetId}').join(',')}';
    if (_dialogOpen || _promptedKey == key) return;
    _promptedKey = key;
    // Mark all presented domains as handled for this visit, including back/skip.
    // A stream update during saving must not reopen a second check-in.
    _dismissedDomains.addAll(items.map((item) => item.domain));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDialog(items);
    });
  }

  Future<void> _openDialog(List<CatchUpItem> items) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    try {
      await showAscentCenteredForm<void>(
        context: context,
        maxWidth: 420,
        barrierDismissible: false,
        builder: (_) => _CatchUpDialog(items: items, onLog: _logItem),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  Future<String> _logItem(CatchUpItem item, String action) async {
    final db = ref.read(databaseProvider);
    switch (item.domain) {
      case CatchUpDomain.hydration:
        final amount = int.tryParse(action) ?? 0;
        if (amount > 0) {
          await db.waterDao.addWater(amount);
        }
        final prefs = ref.read(sharedPreferencesProvider);
        final now = DateTime.now();
        final today = DateFormat('yyyy-MM-dd').format(now);
        final count = prefs.getInt('ascent_hydration_prompts_$today') ?? 0;
        await prefs.setInt(
          'ascent_hydration_snooze_until',
          now.add(const Duration(hours: 4)).millisecondsSinceEpoch,
        );
        await prefs.setInt('ascent_hydration_prompts_$today', count + 1);
        final total = await db.waterDao.getWaterForDate(now);
        return amount > 0
            ? 'Logged $amount mL. You have recorded $total mL of water today.'
            : 'Hydration check snoozed for 4 hours.';
      case CatchUpDomain.medicine:
        if (item.targetId != null) {
          await db.medicineDao.setDoseTaken(item.targetId!, true);
        }
        return 'Dose recorded as taken. Your medicine schedule is up to date.';
      case CatchUpDomain.money:
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await ref
            .read(sharedPreferencesProvider)
            .setString('ascent_money_checked_date', today);
        return 'No spending recorded for today. You can update this later.';
    }
  }
}

class _CatchUpDialog extends StatefulWidget {
  const _CatchUpDialog({required this.items, required this.onLog});
  final List<CatchUpItem> items;
  final Future<String> Function(CatchUpItem, String) onLog;
  @override
  State<_CatchUpDialog> createState() => _CatchUpDialogState();
}

class _CatchUpDialogState extends State<_CatchUpDialog> {
  final _water = TextEditingController();
  final _summaries = <CatchUpDomain, String>{};
  int _selected = 0;
  bool _saving = false;
  String? _error;
  CatchUpItem get _item => widget.items[_selected];

  @override
  void dispose() {
    _water.dispose();
    super.dispose();
  }

  Future<void> _log(String value) async {
    if (_saving || _summaries.containsKey(_item.domain)) return;
    if (_item.domain == CatchUpDomain.hydration) {
      final amount = int.tryParse(value);
      if (amount == null || amount <= 0 || amount > 5000) {
        setState(() => _error = 'Enter an amount between 1 and 5000 mL.');
        return;
      }
    }
    final item = _item;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final summary = await widget.onLog(item, value);
      if (mounted) {
        setState(() {
          _summaries[item.domain] = summary;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save that update. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _expense() async {
    setState(() => _saving = true);
    var saved = false;
    await AddTransactionSheet.show(
      context,
      onSaved: (_) async {
        saved = true;
      },
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) {
        _summaries[CatchUpDomain.money] = 'Your expense is saved in Money.';
      }
    });
  }

  Widget _action(String label, VoidCallback action, {IconData? icon}) =>
      AscentButton.tonal(
        label: label,
        icon: icon,
        compact: true,
        onPressed: _saving ? null : action,
      );

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final item = _item;
    final summary = _summaries[item.domain];
    return PopScope(
      canPop: !_saving,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                summary == null
                    ? item.icon
                    : Icons.check_circle_outline_rounded,
                size: 26,
                color: g.actionInk,
              ),
              const SizedBox(height: 12),
              Text(
                summary == null ? item.title : 'A quick summary',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: g.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.items.length > 1) ...[
                const SizedBox(height: 16),
                AscentSegmentedControl<int>(
                  selected: _selected,
                  enabled: !_saving,
                  accented: true,
                  segments: [
                    for (var i = 0; i < widget.items.length; i++)
                      AscentSegment(
                        value: i,
                        label: switch (widget.items[i].domain) {
                          CatchUpDomain.hydration => 'Water',
                          CatchUpDomain.medicine => 'Medicine',
                          CatchUpDomain.money => 'Money',
                        },
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _selected = value;
                    _error = null;
                  }),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                summary == null ? item.prompt : _summaries.values.join('\n\n'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: g.inkSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (summary == null) ...[
                if (item.domain == CatchUpDomain.hydration) ...[
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      _action('Just drank · 250 mL', () => _log('250')),
                      _action('Log 500 mL', () => _log('500')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _water,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Other amount (mL)',
                      isDense: true,
                      filled: true,
                      fillColor: g.fill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: _log,
                  ),
                  const SizedBox(height: 6),
                  _action('Log water', () => _log(_water.text)),
                ] else if (item.domain == CatchUpDomain.medicine)
                  _action(
                    'Taken',
                    () => _log('taken'),
                    icon: Icons.check_rounded,
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      _action('No spending today', () => _log('no_spend')),
                      _action('Log an expense', _expense),
                    ],
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: SharedControlColors.dueRed),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  AscentButton.ghost(
                    label: summary == null ? 'Skip for now' : 'Done',
                    compact: true,
                    onPressed: _saving
                        ? null
                        : () {
                            if (widget.items.any((i) => i.domain == CatchUpDomain.hydration)) {
                              widget.onLog(
                                const CatchUpItem(
                                  domain: CatchUpDomain.hydration,
                                  title: '',
                                  prompt: '',
                                  icon: Icons.water_drop,
                                  accentColor: Colors.blue,
                                ),
                                '0',
                              );
                            }
                            Navigator.pop(context);
                          },
                  ),
                  if (summary != null &&
                      widget.items.any(
                        (i) => !_summaries.containsKey(i.domain),
                      ))
                    _action(
                      'Next check-in',
                      () => setState(() {
                        _selected = widget.items.indexWhere(
                          (i) => !_summaries.containsKey(i.domain),
                        );
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
