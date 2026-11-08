import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/medicine/medicine_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import 'care_design.dart';

final _doseHistoryProvider = StreamProvider.family<List<MedicineLog>, int>(
  (ref, id) => ref.watch(medicineDaoProvider).watchLogsForMedicine(id),
);

class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({super.key, required this.medicine});
  final Medicine medicine;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AscentScaffold(
    title: 'Dose history',
    subtitle: medicine.name,
    showFeatureHelp: false,
    body: ref
        .watch(_doseHistoryProvider(medicine.id))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () =>
                  ref.invalidate(_doseHistoryProvider(medicine.id)),
              child: const Text('Could not load history. Retry'),
            ),
          ),
          data: (logs) {
            final now = DateTime.now();
            final past =
                logs
                    .where(
                      (log) =>
                          log.isTaken ||
                          DateTime.parse(
                            '${log.dateStr} ${log.timeSlot}:00',
                          ).isBefore(now),
                    )
                    .toList()
                  ..sort(
                    (a, b) => '${b.dateStr}/${b.timeSlot}'.compareTo(
                      '${a.dateStr}/${a.timeSlot}',
                    ),
                  );
            final dates = past.map((l) => l.dateStr).toSet().toList();
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dates.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: CareHero(
                      compact: true,
                      eyebrow: 'Your dose history',
                      title: 'A record of\nyour daily care.',
                      description: past.isEmpty
                          ? 'Your dose history will appear here as scheduled times pass.'
                          : 'Recorded doses and past scheduled times. “Not recorded” means no dose was marked taken.',
                    ),
                  );
                }
                final date = dates[index - 1];
                final slots = past.where((l) => l.dateStr == date).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CarePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CareEyebrow(
                          DateFormat.yMMMEd().format(DateTime.parse(date)),
                        ),
                        const SizedBox(height: 8),
                        for (final log in slots)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CareIcon(
                                  log.isTaken
                                      ? Icons.check_rounded
                                      : Icons.schedule_rounded,
                                  size: 38,
                                  muted: !log.isTaken,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        MedicineService.formatTimeSlot(
                                          log.timeSlot,
                                        ),
                                        style: TextStyle(
                                          color: context.glass.ink,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        log.isTaken
                                            ? 'Taken${log.takenAt == null ? '' : ' · ${DateFormat.yMMMd().add_jm().format(log.takenAt!)}'}'
                                            : 'Not recorded',
                                        style: TextStyle(
                                          color: context.glass.inkSecondary,
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
  );
}
