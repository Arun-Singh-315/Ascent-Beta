import 'dart:io';
import 'care_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import 'care_forms.dart';
import 'medicine_editor_sheet.dart';

class CarePlansView extends ConsumerWidget {
  const CarePlansView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(carePlansProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(carePlansProvider),
            child: const Text('Could not load care plans. Retry'),
          ),
        ),
        data: (plans) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            CareHero(
              eyebrow: 'Your care companion',
              title: plans.isEmpty
                  ? 'A little care.\nA little easier.'
                  : 'Care that stays\nwith you.',
              description: plans.isEmpty
                  ? 'Medicines, reports and the little details. Together, for you and the people you care for.'
                  : 'A space for every concern. A story that stays together.',
              child: AscentButton.primary(
                label: 'Create care plan',
                icon: Icons.add_rounded,
                onPressed: () => showCareForm(context),
              ),
            ),
            if (plans.any((p) => !p.isArchived))
              _heading(context, 'Your care plans'),
            for (final plan in plans.where((p) => !p.isArchived))
              _PlanCard(plan: plan),
            if (plans.any((p) => p.isArchived))
              _heading(context, 'Kept for later'),
            for (final plan in plans.where((p) => p.isArchived))
              _PlanCard(plan: plan),
          ],
        ),
      );
}

Widget _heading(BuildContext context, String title) => CareSectionHeading(
  title,
  icon: title.contains('journal')
      ? Icons.history_edu_outlined
      : title.contains('Medicines')
      ? Icons.medication_outlined
      : Icons.favorite_border_rounded,
);

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});
  final CarePlan plan;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines =
        ref
            .watch(allMedicinesStreamProvider)
            .value
            ?.where((m) => m.carePlanId == plan.id)
            .length ??
        0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CarePanel(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CarePlanScreen(planId: plan.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CareIcon(
                  plan.isArchived
                      ? Icons.inventory_2_outlined
                      : Icons.favorite_border_rounded,
                  muted: plan.isArchived,
                ),
                const SizedBox(width: 12),
                Expanded(child: CareEyebrow(plan.person)),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 20,
                  color: context.glass.inkMuted,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              plan.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CarePill(
                  '$medicines medicine${medicines == 1 ? '' : 's'}',
                  icon: Icons.medication_outlined,
                ),
                if (plan.isArchived) const CarePill('Archived'),
              ],
            ),
            if (plan.nextVisit != null) ...[
              const SizedBox(height: 18),
              Divider(height: 1, color: context.glass.line),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 17,
                    color: context.glass.inkSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next visit · ${DateFormat.yMMMd().format(plan.nextVisit!)}',
                      style: TextStyle(
                        color: context.glass.inkSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CarePlanScreen extends ConsumerWidget {
  const CarePlanScreen({super.key, required this.planId});
  final int planId;

  Future<void> _open(BuildContext context, CareRecord record) async {
    try {
      if (!await File(record.filePath!).exists()) {
        throw StateError('Missing file');
      }
      final result = await OpenFilex.open(record.filePath!);
      if (result.type != ResultType.done) throw StateError('Cannot open file');
    } catch (_) {
      if (context.mounted) {
        AscentSnackBar.error(
          context,
          message:
              'Could not open this report. Check that the file and a compatible viewer are available.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(carePlansProvider);
    final plan = plans.value?.where((p) => p.id == planId).firstOrNull;
    final medicines = ref.watch(allMedicinesStreamProvider);
    final records = ref.watch(careRecordsProvider(planId));
    return AscentScaffold(
      title: plan?.title ?? 'Care plan',
      subtitle: plan?.person,
      showFeatureHelp: false,
      actions: [
        if (plan != null)
          IconButton(
            tooltip: 'Edit care plan',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showCareForm(context, plan: plan),
          ),
      ],
      body: plan == null
          ? Center(
              child: Text(
                plans.hasError
                    ? 'Could not load this care plan.'
                    : plans.isLoading
                    ? 'Loading care plan…'
                    : 'This care plan is no longer available.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                CareHero(
                  compact: true,
                  eyebrow: plan.isArchived ? 'Kept for later' : plan.person,
                  title: 'Your care,\nall together.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (plan.clinician.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.medical_services_outlined,
                              size: 19,
                              color: context.glass.inkSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                plan.clinician,
                                style: TextStyle(
                                  color: context.glass.inkSecondary,
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (plan.nextVisit != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.glass.surface.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: context.glass.ink.withValues(
                                    alpha: .05,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('dd').format(plan.nextVisit!),
                                      style: TextStyle(
                                        color: context.glass.ink,
                                        fontSize: 23,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'MMM',
                                      ).format(plan.nextVisit!).toUpperCase(),
                                      style: TextStyle(
                                        color: context.glass.inkSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const CareEyebrow('Next visit'),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat.yMMMd().format(
                                        plan.nextVisit!,
                                      ),
                                      style: TextStyle(
                                        color: context.glass.ink,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _heading(context, 'Medicines in this plan'),
                medicines.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(allMedicinesStreamProvider),
                    child: const Text('Could not load medicines. Retry'),
                  ),
                  data: (all) {
                    final linked = all
                        .where((m) => m.carePlanId == planId)
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final medicine in linked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CarePanel(
                              onTap: () => showMedicineEditor(
                                context,
                                medicine: medicine,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CareIcon(careMedicineIcon(medicine.type)),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              medicine.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 17,
                                                    letterSpacing: -.3,
                                                    height: 1.3,
                                                  ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              medicine.dosage,
                                              style: TextStyle(
                                                color:
                                                    context.glass.inkSecondary,
                                                fontSize: 14,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_outward_rounded,
                                        size: 18,
                                        color: context.glass.inkMuted,
                                      ),
                                    ],
                                  ),
                                  if (medicine.purpose.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Divider(
                                      height: 1,
                                      color: context.glass.line,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      medicine.purpose,
                                      style: TextStyle(
                                        color: context.glass.inkSecondary,
                                        fontSize: 13,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                  if (!medicine.isActive)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: CarePill('Archived schedule'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (linked.isEmpty)
                          Text(
                            'Add a prescribed medicine here, or link an existing one from its editor.',
                            style: TextStyle(
                              color: context.glass.inkMuted,
                              height: 1.5,
                            ),
                          ),
                        const SizedBox(height: 8),
                        AscentButton.outlined(
                          label: 'Add medicine',
                          icon: Icons.add_rounded,
                          onPressed: () =>
                              showMedicineEditor(context, carePlanId: planId),
                        ),
                      ],
                    );
                  },
                ),
                if (plan.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: CarePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CareEyebrow('Things to remember'),
                          const SizedBox(height: 10),
                          SelectableText(
                            plan.notes,
                            style: TextStyle(
                              color: context.glass.inkSecondary,
                              fontSize: 14,
                              height: 1.65,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _heading(context, 'Reports & care journal'),
                Text(
                  'Small updates. A clearer picture over time.',
                  style: TextStyle(color: context.glass.inkMuted, height: 1.5),
                ),
                const SizedBox(height: 12),
                AscentButton.primary(
                  label: 'Add report or note',
                  icon: Icons.note_add_outlined,
                  onPressed: () => showCareForm(context, recordPlanId: planId),
                ),
                const SizedBox(height: 16),
                records.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => TextButton(
                    onPressed: () =>
                        ref.invalidate(careRecordsProvider(planId)),
                    child: const Text('Could not load records. Retry'),
                  ),
                  data: (items) => Column(
                    children: [
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Your care story can start with a report, a visit or a simple note.',
                            style: TextStyle(
                              color: context.glass.inkMuted,
                              height: 1.5,
                            ),
                          ),
                        ),
                      for (final record in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CarePanel(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    CareIcon(
                                      record.filePath == null
                                          ? Icons.history_edu_outlined
                                          : Icons.description_outlined,
                                      size: 36,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: CareEyebrow(
                                        record.filePath == null
                                            ? 'Care note'
                                            : 'Medical report',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  DateFormat.yMMMd().format(record.recordedAt),
                                  style: TextStyle(
                                    color: context.glass.inkMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  record.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (record.notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SelectableText(
                                      record.notes,
                                      style: const TextStyle(height: 1.6),
                                    ),
                                  ),
                                if (record.filePath != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: OutlinedButton.icon(
                                      onPressed: () => _open(context, record),
                                      icon: const Icon(
                                        Icons.description_outlined,
                                      ),
                                      label: Text(
                                        record.fileName ?? 'Open report',
                                      ),
                                    ),
                                  ),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => showCareForm(
                                        context,
                                        recordPlanId: planId,
                                        record: record,
                                      ),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Edit record'),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove care record',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      onPressed: () async {
                                        final repo = ref.read(
                                          careRepositoryProvider,
                                        );
                                        try {
                                          final restore = await repo
                                              .removeRecordWithUndo(record.id);
                                          if (context.mounted) {
                                            AscentSnackBar.undo(
                                              context,
                                              message: 'Care record removed',
                                              onUndo: () async {
                                                try {
                                                  await restore();
                                                } catch (_) {
                                                  if (context.mounted) {
                                                    AscentSnackBar.error(
                                                      context,
                                                      message:
                                                          'Could not restore this record.',
                                                    );
                                                  }
                                                }
                                              },
                                            );
                                          }
                                        } catch (_) {
                                          if (context.mounted) {
                                            AscentSnackBar.error(
                                              context,
                                              message:
                                                  'Could not remove this record.',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  icon: Icon(
                    plan.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  label: Text(
                    plan.isArchived ? 'Restore care plan' : 'Archive care plan',
                  ),
                  onPressed: () async {
                    final repo = ref.read(careRepositoryProvider);
                    final revision = repo.db.workspaceRevision;
                    try {
                      await repo.archive(planId, !plan.isArchived);
                      if (context.mounted) {
                        AscentSnackBar.undo(
                          context,
                          message: plan.isArchived
                              ? 'Care plan restored'
                              : 'Plan archived. Medicine reminders stay as scheduled.',
                          onUndo: () async {
                            try {
                              if (revision != repo.db.workspaceRevision) {
                                throw StateError('Workspace changed');
                              }
                              await repo.archive(planId, plan.isArchived);
                            } catch (_) {
                              if (context.mounted) {
                                AscentSnackBar.error(
                                  context,
                                  message:
                                      'Could not restore the care plan state.',
                                );
                              }
                            }
                          },
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        AscentSnackBar.error(
                          context,
                          message: 'Could not update this care plan.',
                        );
                      }
                    }
                  },
                ),
              ],
            ),
    );
  }
}
