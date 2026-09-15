import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/enums.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';

class DsaScreen extends ConsumerStatefulWidget {
  const DsaScreen({super.key});

  @override
  ConsumerState<DsaScreen> createState() => _DsaScreenState();
}

class _DsaScreenState extends ConsumerState<DsaScreen> {
  bool _filterNeedsRevisit = false;
  DsaTopic? _selectedTopic;

  void _openAddProblemSheet(BuildContext context, [DsaLog? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddProblemSheet(existing: existing),
    );
  }

  Color _difficultyColor(BuildContext context, String diff) {
    switch (diff.toLowerCase()) {
      case 'easy':
        return context.stateSuccess;
      case 'medium':
        return context.stateWarning;
      case 'hard':
        return context.stateDanger;
      default:
        return context.accentPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dsaDao = ref.watch(dsaDaoProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        title: Text(
          'DSA Problem Tracker',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        backgroundColor: context.bgBase,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _filterNeedsRevisit ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
              color: _filterNeedsRevisit ? context.accentSecondary : context.textPrimary,
            ),
            tooltip: 'Needs Revisit Filter',
            onPressed: () {
              setState(() => _filterNeedsRevisit = !_filterNeedsRevisit);
            },
          ),
        ],
      ),
      floatingActionButton: AscentButton.fab(
        icon: Icons.add_rounded,
        onPressed: () => _openAddProblemSheet(context),
      ),
      body: StreamBuilder<List<DsaLog>>(
        stream: _filterNeedsRevisit
            ? dsaDao.watchNeedsRevisit()
            : (_selectedTopic != null
                ? dsaDao.watchLogsByTopic(_selectedTopic!)
                : dsaDao.watchAllLogs()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SkeletonShimmer(height: 200),
            );
          }

          final problems = snapshot.data ?? [];

          return Column(
            children: [
              // ── Topic Filter Chips ───────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      selected: _selectedTopic == null && !_filterNeedsRevisit,
                      label: const Text('All Topics'),
                      onSelected: (_) => setState(() {
                        _selectedTopic = null;
                        _filterNeedsRevisit = false;
                      }),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _filterNeedsRevisit,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_rounded, size: 14, color: context.accentSecondary),
                          const SizedBox(width: 4),
                          const Text('Needs Revisit'),
                        ],
                      ),
                      onSelected: (val) => setState(() => _filterNeedsRevisit = val),
                    ),
                    const SizedBox(width: 8),
                    ...DsaTopic.values.map((t) {
                      final isSel = _selectedTopic == t && !_filterNeedsRevisit;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: isSel,
                          label: Text(t.name),
                          onSelected: (_) => setState(() {
                            _selectedTopic = isSel ? null : t;
                            _filterNeedsRevisit = false;
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // ── Problems List ────────────────────────────────────────────
              Expanded(
                child: problems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.code_off_rounded, size: 48, color: context.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              _filterNeedsRevisit
                                  ? 'No problems marked for revisit'
                                  : 'No problems logged yet',
                              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: problems.length,
                        itemBuilder: (context, index) {
                          final item = problems[index];
                          final diffColor = _difficultyColor(context, item.difficulty);

                          return AscentCard(
                            onTap: () => _openAddProblemSheet(context, item),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Difficulty Accent Bar
                                Container(
                                  width: 4,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: diffColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.problemName,
                                        style: AscentTextStyles.labelLarge.copyWith(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: diffColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.difficulty.toUpperCase(),
                                              style: AscentTextStyles.statSmall.copyWith(
                                                fontSize: 10,
                                                color: diffColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            item.topic,
                                            style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                                          ),
                                          if (item.timeTakenMinutes != null) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '· ${item.timeTakenMinutes}m',
                                              style: AscentTextStyles.statSmall.copyWith(
                                                fontSize: 11,
                                                color: context.textMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    item.revisitFlag ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                                    color: item.revisitFlag ? context.accentSecondary : context.textMuted,
                                  ),
                                  onPressed: () async {
                                    await dsaDao.toggleRevisit(item.id);
                                  },
                                ),
                              ],
                            ),
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
// Add Problem Bottom Sheet
// ---------------------------------------------------------------------------

class _AddProblemSheet extends ConsumerStatefulWidget {
  final DsaLog? existing;
  const _AddProblemSheet({this.existing});

  @override
  ConsumerState<_AddProblemSheet> createState() => _AddProblemSheetState();
}

class _AddProblemSheetState extends ConsumerState<_AddProblemSheet> {
  final _nameController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();
  DsaTopic _topic = DsaTopic.arrays;
  DsaDifficulty _difficulty = DsaDifficulty.medium;
  bool _revisitFlag = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final item = widget.existing!;
      _nameController.text = item.problemName;
      _timeController.text = item.timeTakenMinutes?.toString() ?? '';
      _notesController.text = item.notes ?? '';
      _topic = DsaTopic.values.firstWhere(
        (t) => t.name == item.topic,
        orElse: () => DsaTopic.arrays,
      );
      _difficulty = DsaDifficulty.values.firstWhere(
        (d) => d.name == item.difficulty,
        orElse: () => DsaDifficulty.medium,
      );
      _revisitFlag = item.revisitFlag;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final dsaDao = ref.read(dsaDaoProvider);
    final minutes = int.tryParse(_timeController.text.trim());

    if (widget.existing != null) {
      await dsaDao.updateLog(
        DsaLogTableCompanion(
          id: drift.Value(widget.existing!.id),
          problemName: drift.Value(name),
          topic: drift.Value(_topic.name),
          difficulty: drift.Value(_difficulty.name),
          timeTakenMinutes: drift.Value(minutes),
          revisitFlag: drift.Value(_revisitFlag),
          notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
          dateSolved: drift.Value(widget.existing!.dateSolved),
        ),
      );
    } else {
      await dsaDao.insertLog(
        DsaLogTableCompanion.insert(
          problemName: name,
          topic: _topic.name,
          difficulty: _difficulty.name,
          timeTakenMinutes: drift.Value(minutes),
          revisitFlag: drift.Value(_revisitFlag),
          notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
          dateSolved: DateTime.now(),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.existing != null ? 'Edit Problem' : 'Log Solved Problem',
                style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
              ),
              if (widget.existing != null)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: context.stateDanger),
                  tooltip: 'Delete Log',
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await ref.read(dsaDaoProvider).deleteLog(widget.existing!.id);
                    if (mounted) navigator.pop();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Problem Name *',
              hintText: 'e.g. 3Sum, Lowest Common Ancestor',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DsaTopic>(
                  initialValue: _topic,
                  decoration: InputDecoration(
                    labelText: 'Topic',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: DsaTopic.values.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t.name));
                  }).toList(),
                  onChanged: (val) => setState(() => _topic = val ?? _topic),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<DsaDifficulty>(
                  initialValue: _difficulty,
                  decoration: InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: DsaDifficulty.values.map((d) {
                    return DropdownMenuItem(value: d, child: Text(d.name.toUpperCase()));
                  }).toList(),
                  onChanged: (val) => setState(() => _difficulty = val ?? _difficulty),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _timeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Time (Minutes)',
                    hintText: '25',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilterChip(
                  selected: _revisitFlag,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_rounded, size: 16, color: context.accentSecondary),
                      const SizedBox(width: 4),
                      const Text('Revisit Flag'),
                    ],
                  ),
                  onSelected: (val) => setState(() => _revisitFlag = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Approach Notes / Time Complexity',
              hintText: 'Two pointers, O(N log N) sort first',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          AscentButton.primary(
            label: widget.existing != null ? 'Save Changes' : 'Save Problem',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
