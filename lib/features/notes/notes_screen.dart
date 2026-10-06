import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/chat_bubble_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTag = 'All';

  final _commonTags = const [
    'All',
    'system-design',
    'behavioral',
    'cheatsheet',
    'interview-qa',
    'salary-negotiation',
    'company-research',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddEditSheet([Note? existing, List<String>? existingTags]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddEditNoteSheet(
        existing: existing,
        existingTags: existingTags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesDao = ref.watch(notesDaoProvider);
    final notesStream = notesDao.watchAllNotes();

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notes & Cheatsheets',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: context.accentPrimary, size: 28),
            tooltip: 'New Note',
            onPressed: () => _openAddEditSheet(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Note>>(
        stream: notesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SkeletonShimmer(height: 220),
            );
          }

          final allNotes = snapshot.data ?? [];

          // Filter by search query
          final filteredNotes = allNotes.where((note) {
            if (_searchQuery.isNotEmpty) {
              final titleMatch = (note.title ?? '').toLowerCase().contains(_searchQuery);
              final contentMatch = note.content.toLowerCase().contains(_searchQuery);
              final companyMatch = (note.linkedCompany ?? '').toLowerCase().contains(_searchQuery);
              final topicMatch = (note.linkedTopic ?? '').toLowerCase().contains(_searchQuery);
              if (!titleMatch && !contentMatch && !companyMatch && !topicMatch) {
                return false;
              }
            }
            return true;
          }).toList();

          return Column(
            children: [
              // ── Search Field ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _searchController,
                  style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search notes, topics, keywords...',
                    hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                    prefixIcon: Icon(Icons.search_rounded, color: context.textMuted, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: context.bgSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.accentPrimary, width: 1.5),
                    ),
                  ),
                ),
              ),

              // ── Quick Filter Tags ────────────────────────────────────
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _commonTags.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tag = _commonTags[index];
                    final isSelected = tag == _selectedTag;
                    return ChoiceChip(
                      label: Text(tag == 'All' ? 'All' : '#$tag'),
                      selected: isSelected,
                      selectedColor: context.accentPrimary,
                      backgroundColor: context.bgSurface,
                      labelStyle: AscentTextStyles.bodySmall.copyWith(
                        color: isSelected ? Colors.white : context.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? context.accentPrimary : context.divider,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTag = tag);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // ── Note List / Empty State ──────────────────────────────
              Expanded(
                child: filteredNotes.isEmpty
                    ? _buildEmptyState(context, allNotes.isEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          return _NoteCard(
                            note: note,
                            selectedTag: _selectedTag,
                            onEdit: (tags) => _openAddEditSheet(note, tags),
                            onDelete: () => _confirmDeleteNote(note.id),
                            onTouch: () => notesDao.touchNote(note.id),
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

  Widget _buildEmptyState(BuildContext context, bool isTotalEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sticky_note_2_outlined,
                color: context.accentPrimary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isTotalEmpty ? 'No Notes Added Yet' : 'No Notes Match Query',
              style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              isTotalEmpty
                  ? 'Capture company research, behavioral stories, system design trade-offs, and quick interview cheatsheets.'
                  : 'Try searching for different keywords or select the "All" tag.',
              textAlign: TextAlign.center,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
            ),
            if (isTotalEmpty) ...[
              const SizedBox(height: 20),
              AscentButton.primary(
                label: 'Create First Note',
                icon: Icons.add_rounded,
                onPressed: () => _openAddEditSheet(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteNote(int id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete Note?',
                style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete this note and its associated tags.',
                textAlign: TextAlign.center,
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.outlined(
                      label: 'Cancel',
                      compact: true,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.destructive(
                      label: 'Delete',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(notesDaoProvider).deleteNote(id);
                      },
                    ),
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

// ---------------------------------------------------------------------------
// Note Card
// ---------------------------------------------------------------------------

class _NoteCard extends ConsumerWidget {
  final Note note;
  final String selectedTag;
  final Function(List<String> tags) onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTouch;

  const _NoteCard({
    required this.note,
    required this.selectedTag,
    required this.onEdit,
    required this.onDelete,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesDao = ref.watch(notesDaoProvider);

    return FutureBuilder<List<String>>(
      future: notesDao.getTagsForNote(note.id),
      builder: (context, snapshot) {
        final tags = snapshot.data ?? [];

        // If a specific tag is selected and this note doesn't have it, skip
        if (selectedTag != 'All' && !tags.contains(selectedTag)) {
          return const SizedBox.shrink();
        }

        // Check freshness: if lastInteractedAt > 14 days ago or never
        final isStale = note.lastInteractedAt == null ||
            DateTime.now().difference(note.lastInteractedAt!).inDays >= 14;

        Color tint = context.accentPrimary;
        if (note.linkedCompany?.isNotEmpty == true) {
          tint = context.accentSecondary;
        } else if (note.linkedTopic?.isNotEmpty == true) {
          tint = context.accentInfo;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChatBubbleCard(
            tailPosition: BubbleTailPosition.bottomLeft,
            accentTint: tint,
            isPulsing: isStale,
            padding: const EdgeInsets.all(16),
            onTap: () => onEdit(tags),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Company, freshness indicator, options menu
              Row(
                children: [
                  if (note.linkedCompany?.isNotEmpty == true) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.accentPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        note.linkedCompany!,
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: context.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (isStale)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.stateWarning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 12, color: context.stateWarning),
                          const SizedBox(width: 4),
                          Text(
                            'Needs Review',
                            style: AscentTextStyles.labelSmall.copyWith(
                              color: context.stateWarning,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 18, color: context.textMuted),
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      if (val == 'edit') onEdit(tags);
                      if (val == 'touch') onTouch();
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit Note')),
                      const PopupMenuItem(value: 'touch', child: Text('Mark Reviewed')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Title
              if (note.title?.isNotEmpty == true)
                Text(
                  note.title!,
                  style: AscentTextStyles.headlineMedium.copyWith(
                    color: context.textPrimary,
                    fontSize: 16,
                  ),
                ),

              const SizedBox(height: 6),

              // Content snippet
              Text(
                note.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              // Tags row & Timestamp
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.bgBase,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: context.divider),
                          ),
                          child: Text(
                            '#$t',
                            style: AscentTextStyles.labelSmall.copyWith(
                              color: context.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Text(
                    DateFormat.MMMd().format(note.updatedAt),
                    style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit Note Sheet
// ---------------------------------------------------------------------------

class _AddEditNoteSheet extends ConsumerStatefulWidget {
  final Note? existing;
  final List<String>? existingTags;

  const _AddEditNoteSheet({this.existing, this.existingTags});

  @override
  ConsumerState<_AddEditNoteSheet> createState() => _AddEditNoteSheetState();
}

class _AddEditNoteSheetState extends ConsumerState<_AddEditNoteSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _companyController = TextEditingController();
  final _tagInputController = TextEditingController();
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _titleController.text = widget.existing!.title ?? '';
      _contentController.text = widget.existing!.content;
      _companyController.text = widget.existing!.linkedCompany ?? '';
      if (widget.existingTags != null) {
        _tags.addAll(widget.existingTags!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _companyController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final clean = raw.replaceAll('#', '').trim().toLowerCase();
    if (clean.isNotEmpty && !_tags.contains(clean)) {
      setState(() {
        _tags.add(clean);
        _tagInputController.clear();
      });
    }
  }

  void _insertTemplate(String template) {
    final current = _contentController.text;
    final prefix = current.isEmpty ? '' : '$current\n\n';
    setState(() {
      _contentController.text = '$prefix$template';
    });
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note content cannot be empty')),
      );
      return;
    }

    final notesDao = ref.read(notesDaoProvider);
    final title = _titleController.text.trim().isEmpty ? null : _titleController.text.trim();
    final company = _companyController.text.trim().isEmpty ? null : _companyController.text.trim();

    if (widget.existing != null) {
      await notesDao.updateNote(
        NoteTableCompanion(
          id: drift.Value(widget.existing!.id),
          title: drift.Value(title),
          content: drift.Value(content),
          linkedCompany: drift.Value(company),
          updatedAt: drift.Value(DateTime.now()),
          lastInteractedAt: drift.Value(DateTime.now()),
        ),
        tags: _tags,
      );
    } else {
      final noteId = await notesDao.insertNote(
        NoteTableCompanion.insert(
          title: drift.Value(title),
          content: content,
          linkedCompany: drift.Value(company),
          lastInteractedAt: drift.Value(DateTime.now()),
        ),
      );
      // Save tags
      if (_tags.isNotEmpty) {
        await notesDao.updateNote(
          NoteTableCompanion(id: drift.Value(noteId)),
          tags: _tags,
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existing != null ? 'Edit Note' : 'New Note',
                  style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              style: AscentTextStyles.bodyMedium.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Title (e.g. Distributed Caching Trade-offs)',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Company
            TextField(
              controller: _companyController,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Linked Company (Optional, e.g. Amazon)',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Quick templates
            Row(
              children: [
                Text(
                  'Insert template:',
                  style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text('STAR'),
                  labelStyle: AscentTextStyles.labelSmall,
                  onPressed: () => _insertTemplate(
                    '### Situation\n- Context:\n\n### Task\n- Goal:\n\n### Action\n- Steps taken:\n\n### Result\n- Impact / Metrics:',
                  ),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('System Design'),
                  labelStyle: AscentTextStyles.labelSmall,
                  onPressed: () => _insertTemplate(
                    '### 1. Requirements\n- Functional:\n- Non-functional:\n\n### 2. High-Level Architecture\n- Components:\n\n### 3. Bottlenecks & Scale\n- Trade-offs:',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Body
            TextField(
              controller: _contentController,
              maxLines: 6,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type your study notes, cheat sheets, or talking points...',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tags input
            Text(
              'Tags (press Enter or Add)',
              style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInputController,
                    style: AscentTextStyles.bodySmall.copyWith(color: context.textPrimary),
                    onSubmitted: _addTag,
                    decoration: InputDecoration(
                      hintText: 'e.g. system-design, behavioral',
                      hintStyle: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                      filled: true,
                      fillColor: context.bgBase,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: context.divider),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded, color: context.accentPrimary),
                  onPressed: () => _addTag(_tagInputController.text),
                ),
              ],
            ),

            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text('#$tag'),
                    labelStyle: AscentTextStyles.labelSmall.copyWith(color: context.textPrimary),
                    backgroundColor: context.bgBase,
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: AscentButton.outlined(
                    label: 'Cancel',
                    compact: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AscentButton.primary(
                    label: widget.existing != null ? 'Update Note' : 'Save Note',
                    compact: true,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
