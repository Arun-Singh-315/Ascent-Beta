import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/actions/checkin_actions.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/daily_checkin_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/home_layout_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/note_draft_binding.dart';
import '../../shared/widgets/ascent_card.dart';
import '../money/add_transaction_sheet.dart';

class DailyCheckInCard extends ConsumerStatefulWidget {
  const DailyCheckInCard({super.key});
  @override
  ConsumerState<DailyCheckInCard> createState() => _DailyCheckInCardState();
}

class _DailyCheckInCardState extends ConsumerState<DailyCheckInCard> {
  final _water = TextEditingController(text: '250');
  NoteDraftBinding? _draft;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _draft = NoteDraftBinding(
      _water,
      ref.read(sharedPreferencesProvider),
      'checkin_water',
    );
  }

  @override
  void dispose() {
    _draft?.dispose();
    _water.dispose();
    super.dispose();
  }

  Future<void> _configure() async {
    var settings = ref.read(dailyCheckInProvider);
    var saving = false;
    String? error;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !saving,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your optional check-in',
                    style: AscentTextStyles.displaySmall.copyWith(
                      color: context.glass.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A quiet Home card. Nothing is logged until you choose to save.',
                  ),
                  CheckboxListTile(
                    title: const Text('Spending'),
                    value: settings.spending,
                    onChanged: saving
                        ? null
                        : (v) => update(
                            () => settings = settings.copyWith(spending: v),
                          ),
                  ),
                  CheckboxListTile(
                    title: const Text('Water'),
                    value: settings.water,
                    onChanged: saving
                        ? null
                        : (v) => update(
                            () => settings = settings.copyWith(water: v),
                          ),
                  ),
                  SwitchListTile(
                    title: const Text('Weekly check-in'),
                    subtitle: const Text('Otherwise shown daily'),
                    value: settings.weekly,
                    onChanged: saving
                        ? null
                        : (v) => update(
                            () => settings = settings.copyWith(weekly: v),
                          ),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: settings.afterHour,
                    decoration: const InputDecoration(labelText: 'Show after'),
                    items: List.generate(
                      24,
                      (hour) => DropdownMenuItem(
                        value: hour,
                        child: Text('${hour.toString().padLeft(2, '0')}:00'),
                      ),
                    ),
                    onChanged: saving
                        ? null
                        : (hour) => update(
                            () => settings = settings.copyWith(afterHour: hour),
                          ),
                  ),
                  if (error != null) Text(error!),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: saving || (!settings.spending && !settings.water)
                        ? null
                        : () async {
                            update(() => saving = true);
                            try {
                              await ref
                                  .read(dailyCheckInProvider.notifier)
                                  .change(
                                    (_) => settings.copyWith(enabled: true),
                                  );
                              if (context.mounted) Navigator.pop(context);
                            } catch (_) {
                              if (context.mounted) {
                                update(() {
                                  saving = false;
                                  error = 'Could not save. Try again.';
                                });
                              }
                            }
                          },
                    child: Text(saving ? 'Saving…' : 'Save check-in'),
                  ),
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changePreference(Future<void> Function() change) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await change();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your preference. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(dailyCheckInProvider);
    final g = context.glass;
    final now = DateTime.now();
    final period = settings.period(now);
    final waterSaved = ref.watch(checkInWaterSavedProvider(period));
    if (!settings.enabled) {
      return AscentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily check-in',
              style: AscentTextStyles.displaySmall.copyWith(color: g.ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose details you would like to log, when it suits you.',
            ),
            TextButton(
              onPressed: _configure,
              child: const Text('Choose what to log'),
            ),
          ],
        ),
      );
    }
    if (!settings.due(now)) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _configure,
          child: const Text('Check-in preferences'),
        ),
      );
    }
    return AscentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A quick check-in',
            style: AscentTextStyles.displaySmall.copyWith(color: g.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Fill only what you want. Skipping does not create a record.',
            style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
          ),
          if (settings.spending &&
              settings.spendingPeriod != settings.period(now))
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await AddTransactionSheet.show(
                          context,
                          onSaved: (_) async => ref
                              .read(dailyCheckInProvider.notifier)
                              .change(
                                (s) => s.copyWith(
                                  spendingPeriod: settings.period(now),
                                ),
                              ),
                        );
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Log spending'),
            ),
          if (settings.water &&
              settings.waterPeriod != period &&
              waterSaved.asData?.value == false)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _water,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Water · ml'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final ml = int.tryParse(_water.text.trim());
                          if (ml == null || ml <= 0 || ml > 3000) {
                            setState(() => _error = 'Use 1–3000 ml.');
                            return;
                          }
                          setState(() {
                            _busy = true;
                            _error = null;
                          });
                          bool saved = false;
                          try {
                            await CheckInActions(
                              ref.read(databaseProvider),
                            ).saveWater(period: period, amountMl: ml);
                            ref.invalidate(checkInWaterSavedProvider(period));
                            saved = true;
                            await ref
                                .read(dailyCheckInProvider.notifier)
                                .change(
                                  (s) => s.copyWith(
                                    waterPeriod: settings.period(now),
                                  ),
                                );
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => _error = saved
                                    ? 'Water saved. Check-in preference could not be updated.'
                                    : 'Water could not be saved. Try again.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Save water'),
                ),
              ],
            ),
          if (_error != null)
            Text(
              _error!,
              style: AscentTextStyles.bodySmall.copyWith(color: g.coral),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _changePreference(
                        () => ref
                            .read(dailyCheckInProvider.notifier)
                            .change(
                              (s) => s.copyWith(dismissedPeriod: s.period(now)),
                            ),
                      ),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _changePreference(() async {
                        final layout = ref.read(homeLayoutProvider);
                        await ref
                            .read(homeLayoutProvider.notifier)
                            .save(
                              layout.copyWith(
                                visible: {...layout.visible}..remove('checkin'),
                              ),
                            );
                      }),
                child: const Text('Hide check-in'),
              ),
              TextButton(
                onPressed: _busy ? null : _configure,
                child: const Text('Preferences'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
