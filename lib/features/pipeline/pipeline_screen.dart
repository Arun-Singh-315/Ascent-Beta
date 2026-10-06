import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/enums.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';

class PipelineScreen extends ConsumerStatefulWidget {
  const PipelineScreen({super.key});

  @override
  ConsumerState<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends ConsumerState<PipelineScreen> {
  ApplicationStage? _filterStage;
  final Map<ApplicationStage, bool> _collapsedStages = {
    ApplicationStage.rejected: true,
  };

  static const List<ApplicationStage> _stages = [
    ApplicationStage.wishlist,
    ApplicationStage.applied,
    ApplicationStage.oaScreen,
    ApplicationStage.interview,
    ApplicationStage.offer,
    ApplicationStage.rejected,
  ];

  String _stageLabel(ApplicationStage stage) {
    switch (stage) {
      case ApplicationStage.wishlist:
        return 'Wishlist';
      case ApplicationStage.applied:
        return 'Applied';
      case ApplicationStage.oaScreen:
        return 'OA / Screen';
      case ApplicationStage.interview:
        return 'Interview Round';
      case ApplicationStage.offer:
        return 'Offer';
      case ApplicationStage.rejected:
        return 'Rejected';
    }
  }

  Color _stageColor(BuildContext context, ApplicationStage stage) {
    switch (stage) {
      case ApplicationStage.wishlist:
        return context.textMuted;
      case ApplicationStage.applied:
        return context.accentInfo;
      case ApplicationStage.oaScreen:
        return context.accentSecondary;
      case ApplicationStage.interview:
        return context.accentPrimary;
      case ApplicationStage.offer:
        return context.stateSuccess;
      case ApplicationStage.rejected:
        return context.stateDanger;
    }
  }

  void _openAddApplicationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const AddApplicationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appDao = ref.watch(applicationDaoProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        title: Text(
          'Application Pipeline',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        backgroundColor: context.bgBase,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () {
              showSearch(
                context: context,
                delegate: _ApplicationSearchDelegate(ref),
              );
            },
          ),
        ],
      ),
      floatingActionButton: AscentButton.fab(
        icon: Icons.add_rounded,
        onPressed: () => _openAddApplicationSheet(context),
      ),
      body: StreamBuilder<List<ApplicationRow>>(
        stream: appDao.watchAllApplications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SkeletonShimmer(height: 240),
            );
          }

          final allApps = snapshot.data ?? [];
          final visibleStages = _filterStage != null
              ? [_filterStage!]
              : _stages;

          return Column(
            children: [
              // ── Filter Bar ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _filterStage == null,
                        label: Text('All (${allApps.length})'),
                        onSelected: (_) => setState(() => _filterStage = null),
                        selectedColor: context.accentPrimary.withValues(alpha: 0.2),
                        checkmarkColor: context.accentPrimary,
                      ),
                      const SizedBox(width: 8),
                      ..._stages.map((stage) {
                        final count = allApps
                            .where((a) => a.currentStage == stage.name)
                            .length;
                        final isSelected = _filterStage == stage;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text('${_stageLabel(stage)} ($count)'),
                            onSelected: (_) => setState(() {
                              _filterStage = isSelected ? null : stage;
                            }),
                            selectedColor: _stageColor(context, stage).withValues(alpha: 0.2),
                            checkmarkColor: _stageColor(context, stage),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // ── Stacked Collapsible Stage Sections ───────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: visibleStages.length,
                  itemBuilder: (context, index) {
                    final stage = visibleStages[index];
                    final stageApps = allApps
                        .where((a) => a.currentStage == stage.name)
                        .toList();
                    final isCollapsed = _collapsedStages[stage] ?? false;

                    return _CollapsibleStageSection(
                      stage: stage,
                      title: _stageLabel(stage),
                      color: _stageColor(context, stage),
                      applications: stageApps,
                      isCollapsed: isCollapsed,
                      allStages: _stages,
                      onToggleCollapse: () {
                        setState(() {
                          _collapsedStages[stage] = !isCollapsed;
                        });
                      },
                      onMoveTo: (appId, targetStage) async {
                        await appDao.moveToStage(appId, targetStage);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Moved to ${_stageLabel(targetStage)}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsible Stage Section (Spec §8)
// ---------------------------------------------------------------------------

class _CollapsibleStageSection extends StatelessWidget {
  final ApplicationStage stage;
  final String title;
  final Color color;
  final List<ApplicationRow> applications;
  final bool isCollapsed;
  final List<ApplicationStage> allStages;
  final VoidCallback onToggleCollapse;
  final void Function(int appId, ApplicationStage targetStage) onMoveTo;

  const _CollapsibleStageSection({
    required this.stage,
    required this.title,
    required this.color,
    required this.applications,
    required this.isCollapsed,
    required this.allStages,
    required this.onToggleCollapse,
    required this.onMoveTo,
  });

  @override
  Widget build(BuildContext context) {
    return AscentCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onToggleCollapse,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: AscentTextStyles.headlineMedium.copyWith(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${applications.length}',
                      style: AscentTextStyles.statSmall.copyWith(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: context.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const Divider(height: 1, thickness: 1),
            if (applications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Center(
                  child: Text(
                    'No applications in $title',
                    style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: applications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final app = applications[idx];
                  return _ApplicationStageCard(
                    app: app,
                    currentStage: stage,
                    allStages: allStages,
                    onMoveTo: (target) => onMoveTo(app.id, target),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Application Card with Direct "Move to..." Stage Transition Action
// ---------------------------------------------------------------------------

class _ApplicationStageCard extends StatelessWidget {
  final ApplicationRow app;
  final ApplicationStage currentStage;
  final List<ApplicationStage> allStages;
  final void Function(ApplicationStage targetStage) onMoveTo;

  const _ApplicationStageCard({
    required this.app,
    required this.currentStage,
    required this.allStages,
    required this.onMoveTo,
  });

  String _stageLabel(ApplicationStage stage) {
    switch (stage) {
      case ApplicationStage.wishlist:
        return 'Wishlist';
      case ApplicationStage.applied:
        return 'Applied';
      case ApplicationStage.oaScreen:
        return 'OA / Screen';
      case ApplicationStage.interview:
        return 'Interview Round';
      case ApplicationStage.offer:
        return 'Offer';
      case ApplicationStage.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextActionDate = app.nextActionDate;
    final isUrgent = nextActionDate != null &&
        nextActionDate.isBefore(DateTime.now().add(const Duration(days: 3)));

    return AscentCard(
      color: context.bgBase.withValues(alpha: 0.6),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/pipeline/${app.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.company,
                      style: AscentTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.role,
                      style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<ApplicationStage>(
                tooltip: 'Move to stage',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: context.bgSurface,
                onSelected: onMoveTo,
                itemBuilder: (context) {
                  return allStages
                      .where((s) => s != currentStage)
                      .map((s) => PopupMenuItem(
                            value: s,
                            child: Text(
                              _stageLabel(s),
                              style: AscentTextStyles.bodySmall.copyWith(color: context.textPrimary),
                            ),
                          ))
                      .toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.accentPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.accentPrimary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Move',
                        style: AscentTextStyles.caption.copyWith(
                          color: context.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down_rounded, size: 16, color: context.accentPrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (app.salary != null && app.salary!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.accentSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                app.salary!,
                style: AscentTextStyles.monoCode.copyWith(
                  fontSize: 10,
                  color: context.accentSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (nextActionDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: isUrgent ? context.stateDanger : context.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Action: ${DateFormat('MMM d').format(nextActionDate)}',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: isUrgent ? context.stateDanger : context.textMuted,
                    fontWeight: isUrgent ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit Application Bottom Sheet
// ---------------------------------------------------------------------------

class AddApplicationSheet extends ConsumerStatefulWidget {
  final ApplicationRow? existing;

  const AddApplicationSheet({super.key, this.existing});

  @override
  ConsumerState<AddApplicationSheet> createState() =>
      _AddApplicationSheetState();
}

class _AddApplicationSheetState extends ConsumerState<AddApplicationSheet> {
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  final _salaryController = TextEditingController();
  final _jobUrlController = TextEditingController();
  final _notesController = TextEditingController();
  ApplicationStage _stage = ApplicationStage.wishlist;
  DateTime? _nextActionDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final app = widget.existing!;
      _companyController.text = app.company;
      _roleController.text = app.role;
      _salaryController.text = app.salary ?? '';
      _jobUrlController.text = app.jobUrl ?? '';
      _notesController.text = app.notes ?? '';
      _nextActionDate = app.nextActionDate;
      _stage = ApplicationStage.values.firstWhere(
        (s) => s.name == app.currentStage,
        orElse: () => ApplicationStage.wishlist,
      );
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    _salaryController.dispose();
    _jobUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final company = _companyController.text.trim();
    final role = _roleController.text.trim();
    if (company.isEmpty || role.isEmpty) return;

    setState(() => _saving = true);
    final appDao = ref.read(applicationDaoProvider);
    final nav = Navigator.of(context);

    if (widget.existing != null) {
      await appDao.updateApplication(
        ApplicationTableCompanion(
          id: drift.Value(widget.existing!.id),
          company: drift.Value(company),
          role: drift.Value(role),
          currentStage: drift.Value(_stage.name),
          salary: drift.Value(_salaryController.text.trim().isEmpty ? null : _salaryController.text.trim()),
          jobUrl: drift.Value(_jobUrlController.text.trim().isEmpty ? null : _jobUrlController.text.trim()),
          notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
          nextActionDate: drift.Value(_nextActionDate),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
      if (widget.existing!.currentStage != _stage.name) {
        await appDao.recordStatusChange(
          widget.existing!.id,
          _stage,
          notes: 'Stage updated via editor',
        );
      }
    } else {
      final newId = await appDao.insertApplication(
        ApplicationTableCompanion.insert(
          company: company,
          role: role,
          currentStage: drift.Value(_stage.name),
          salary: drift.Value(_salaryController.text.trim().isEmpty ? null : _salaryController.text.trim()),
          jobUrl: drift.Value(_jobUrlController.text.trim().isEmpty ? null : _jobUrlController.text.trim()),
          notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
          nextActionDate: drift.Value(_nextActionDate),
        ),
      );
      await appDao.recordStatusChange(newId, _stage, notes: 'Application tracked');
    }

    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existing != null;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'Edit Application' : 'Track New Application',
              style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _companyController,
              decoration: InputDecoration(
                labelText: 'Company *',
                hintText: 'e.g. Stripe, Google, Figma',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              decoration: InputDecoration(
                labelText: 'Role *',
                hintText: 'e.g. Senior Backend Engineer',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _salaryController,
                    decoration: InputDecoration(
                      labelText: 'Salary / Compensation',
                      hintText: 'e.g. \$180k - \$210k or 25 LPA',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ApplicationStage>(
                    initialValue: _stage,
                    decoration: InputDecoration(
                      labelText: 'Stage',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ApplicationStage.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _stage = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jobUrlController,
              decoration: InputDecoration(
                labelText: 'Job Posting URL',
                hintText: 'https://...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.divider),
              ),
              leading: Icon(Icons.event_rounded, color: context.accentPrimary),
              title: Text(
                _nextActionDate == null
                    ? 'Set Next Action Date'
                    : 'Action: ${DateFormat.yMMMd().format(_nextActionDate!)}',
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              ),
              trailing: _nextActionDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _nextActionDate = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextActionDate ?? DateTime.now().add(const Duration(days: 3)),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _nextActionDate = picked);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'Referral link, recruiter info, job spec notes',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AscentButton.outlined(
                    label: 'Cancel',
                    compact: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AscentButton.primary(
                    label: isEditing ? 'Save Changes' : 'Add to Pipeline',
                    compact: true,
                    loading: _saving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search Delegate
// ---------------------------------------------------------------------------

class _ApplicationSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  _ApplicationSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final appDao = ref.watch(applicationDaoProvider);

    return StreamBuilder<List<ApplicationRow>>(
      stream: appDao.watchAllApplications(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final filtered = all
            .where((a) =>
                a.company.toLowerCase().contains(query.toLowerCase()) ||
                a.role.toLowerCase().contains(query.toLowerCase()))
            .toList();

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, idx) {
            final app = filtered[idx];
            return ListTile(
              title: Text(app.company),
              subtitle: Text('${app.role} · Stage: ${app.currentStage}'),
              onTap: () {
                close(context, null);
                context.push('/pipeline/${app.id}');
              },
            );
          },
        );
      },
    );
  }
}
