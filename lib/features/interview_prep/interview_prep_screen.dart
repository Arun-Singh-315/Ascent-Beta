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
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';

class InterviewPrepScreen extends ConsumerStatefulWidget {
  final int? linkedApplicationId;

  const InterviewPrepScreen({super.key, this.linkedApplicationId});

  @override
  ConsumerState<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends ConsumerState<InterviewPrepScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  int? _filterApplicationId;
  final Set<int> _expandedQuestionIds = {};

  final _categories = const [
    'All',
    'Behavioral',
    'System Design',
    'DSA',
    'Technical / Core',
    'Culture & Leadership',
  ];

  @override
  void initState() {
    super.initState();
    _filterApplicationId = widget.linkedApplicationId;
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

  void _openAddEditDialog([InterviewPrep? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddEditQuestionSheet(
        existing: existing,
        defaultApplicationId: _filterApplicationId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prepDao = ref.watch(interviewPrepDaoProvider);
    final questionsStream = _filterApplicationId != null
        ? prepDao.watchQuestionsForApplication(_filterApplicationId!)
        : prepDao.watchAllQuestions();

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
          'Interview Prep',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: context.accentPrimary, size: 28),
            tooltip: 'Add Question',
            onPressed: () => _openAddEditDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<InterviewPrep>>(
        stream: questionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SkeletonShimmer(height: 200),
            );
          }

          final allQuestions = snapshot.data ?? [];

          // Filter by category and search
          final filtered = allQuestions.where((q) {
            if (_selectedCategory != 'All') {
              if ((q.category ?? '').toLowerCase() != _selectedCategory.toLowerCase()) {
                return false;
              }
            }
            if (_searchQuery.isNotEmpty) {
              final matchQuestion = q.questionAsked.toLowerCase().contains(_searchQuery);
              final matchCompany = (q.company ?? '').toLowerCase().contains(_searchQuery);
              final matchNotes = (q.answerNotes ?? '').toLowerCase().contains(_searchQuery);
              if (!matchQuestion && !matchCompany && !matchNotes) return false;
            }
            return true;
          }).toList();

          // Calculate stats
          final totalCount = allQuestions.length;
          final practicedCount = allQuestions.where((q) => q.lastInteractedAt != null).length;
          final nailedCount = allQuestions.where((q) => q.outcome == 'Nailed it').length;

          return Column(
            children: [
              // ── Linked Application Banner ────────────────────────────
              if (_filterApplicationId != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.accentPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.business_center_rounded, size: 18, color: context.accentPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Filtered by linked application',
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _filterApplicationId = null),
                        child: Icon(Icons.close_rounded, size: 18, color: context.textMuted),
                      ),
                    ],
                  ),
                ),

              // ── Search & Filter Bar ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _searchController,
                  style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search questions, companies, topics...',
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

              // ── Category Chips ───────────────────────────────────────
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
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
                        if (selected) setState(() => _selectedCategory = cat);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // ── High Level Stats Strip ───────────────────────────────
              if (totalCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      _StatBadge(
                        label: 'Total',
                        count: '$totalCount',
                        color: context.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      _StatBadge(
                        label: 'Practiced',
                        count: '$practicedCount',
                        color: context.accentSecondary,
                      ),
                      const SizedBox(width: 8),
                      _StatBadge(
                        label: 'Nailed it',
                        count: '$nailedCount',
                        color: context.stateSuccess,
                      ),
                    ],
                  ),
                ),

              // ── Question List / Empty State ──────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(context, totalCount == 0)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isExpanded = _expandedQuestionIds.contains(item.id);
                          return _QuestionCard(
                            item: item,
                            isExpanded: isExpanded,
                            onToggleExpand: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedQuestionIds.remove(item.id);
                                } else {
                                  _expandedQuestionIds.add(item.id);
                                }
                              });
                            },
                            onEdit: () => _openAddEditDialog(item),
                            onDelete: () => _confirmDeleteQuestion(item.id),
                            onMarkPracticed: (outcome) async {
                              await prepDao.updateQuestion(
                                InterviewPrepTableCompanion(
                                  id: drift.Value(item.id),
                                  outcome: drift.Value(outcome),
                                  lastInteractedAt: drift.Value(DateTime.now()),
                                ),
                              );
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

  Widget _buildEmptyState(BuildContext context, bool isTotalZero) {
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
                Icons.psychology_outlined,
                color: context.accentPrimary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isTotalZero ? 'No Interview Questions Yet' : 'No Matching Questions',
              style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              isTotalZero
                  ? 'Add questions you expect or have encountered. Practice answers, STAR notes, and track your confidence.'
                  : 'Try changing your search query or selected category filter.',
              textAlign: TextAlign.center,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
            ),
            if (isTotalZero) ...[
              const SizedBox(height: 20),
              AscentButton.primary(
                label: 'Add First Question',
                icon: Icons.add_rounded,
                onPressed: () => _openAddEditDialog(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteQuestion(int id) {
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
                'Delete Question?',
                style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'This question and its practice notes will be permanently removed.',
                textAlign: TextAlign.center,
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.ghost(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.destructive(
                      label: 'Delete',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(interviewPrepDaoProvider).deleteQuestion(id);
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
// Stat Badge
// ---------------------------------------------------------------------------

class _StatBadge extends StatelessWidget {
  final String label;
  final String count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
          ),
          Text(
            count,
            style: AscentTextStyles.monoCode.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Question Card
// ---------------------------------------------------------------------------

class _QuestionCard extends StatelessWidget {
  final InterviewPrep item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onMarkPracticed;

  const _QuestionCard({
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkPracticed,
  });

  Color _outcomeColor(BuildContext context, String? outcome) {
    switch (outcome) {
      case 'Nailed it':
        return context.stateSuccess;
      case 'Solid':
        return context.accentPrimary;
      case 'Needs work':
        return context.stateWarning;
      case 'Stumped':
        return context.stateDanger;
      default:
        return context.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final outcomeColor = _outcomeColor(context, item.outcome);
    final lastPracticed = item.lastInteractedAt != null
        ? 'Practiced ${DateFormat.MMMd().format(item.lastInteractedAt!)}'
        : 'Not practiced yet';

    return AscentCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta tags: Company, Category, Outcome
          Row(
            children: [
              if (item.company?.isNotEmpty == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.company!,
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: context.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (item.category?.isNotEmpty == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.bgBase,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.divider),
                  ),
                  child: Text(
                    item.category!,
                    style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              if (item.outcome?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: outcomeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.outcome!,
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: outcomeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: context.textMuted),
                padding: EdgeInsets.zero,
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Question')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Question Text
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.questionAsked,
                    style: AscentTextStyles.headlineMedium.copyWith(
                      color: context.textPrimary,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: context.textMuted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Practiced time & expand CTA
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: context.textMuted),
              const SizedBox(width: 4),
              Text(
                lastPracticed,
                style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
              ),
            ],
          ),

          // ── Expanded Content: Answer & Practice controls ───────────
          if (isExpanded) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),

            Text(
              'Answer & Key Talking Points:',
              style: AscentTextStyles.labelSmall.copyWith(
                color: context.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.bgBase,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.divider),
              ),
              child: Text(
                item.answerNotes?.isNotEmpty == true
                    ? item.answerNotes!
                    : 'No answer notes added yet. Tap Edit to write key points, metrics, or STAR bullets.',
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: item.answerNotes?.isNotEmpty == true
                      ? context.textPrimary
                      : context.textMuted,
                  height: 1.45,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Quick outcome assessment buttons
            Text(
              'Self-Evaluation Rating:',
              style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ['Nailed it', 'Solid', 'Needs work', 'Stumped'].map((rating) {
                final isSelected = item.outcome == rating;
                final rColor = _outcomeColor(context, rating);
                return ActionChip(
                  label: Text(rating),
                  labelStyle: AscentTextStyles.labelSmall.copyWith(
                    color: isSelected ? Colors.white : rColor,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: isSelected ? rColor : rColor.withValues(alpha: 0.1),
                  side: BorderSide(color: isSelected ? rColor : Colors.transparent),
                  onPressed: () => onMarkPracticed(rating),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit Question Sheet
// ---------------------------------------------------------------------------

class _AddEditQuestionSheet extends ConsumerStatefulWidget {
  final InterviewPrep? existing;
  final int? defaultApplicationId;

  const _AddEditQuestionSheet({this.existing, this.defaultApplicationId});

  @override
  ConsumerState<_AddEditQuestionSheet> createState() => _AddEditQuestionSheetState();
}

class _AddEditQuestionSheetState extends ConsumerState<_AddEditQuestionSheet> {
  final _questionController = TextEditingController();
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  final _answerController = TextEditingController();
  String _category = 'Behavioral';
  String _outcome = 'Solid';
  int? _linkedAppId;

  final _categories = const [
    'Behavioral',
    'System Design',
    'DSA',
    'Technical / Core',
    'Culture & Leadership',
  ];

  final _outcomes = const [
    'Nailed it',
    'Solid',
    'Needs work',
    'Stumped',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final q = widget.existing!;
      _questionController.text = q.questionAsked;
      _companyController.text = q.company ?? '';
      _roleController.text = q.role ?? '';
      _answerController.text = q.answerNotes ?? '';
      if (q.category != null && _categories.contains(q.category)) {
        _category = q.category!;
      }
      if (q.outcome != null && _outcomes.contains(q.outcome)) {
        _outcome = q.outcome!;
      }
      _linkedAppId = q.linkedApplicationId;
    } else {
      _linkedAppId = widget.defaultApplicationId;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the question text')),
      );
      return;
    }

    final prepDao = ref.read(interviewPrepDaoProvider);

    if (widget.existing != null) {
      await prepDao.updateQuestion(
        InterviewPrepTableCompanion(
          id: drift.Value(widget.existing!.id),
          questionAsked: drift.Value(questionText),
          company: drift.Value(_companyController.text.trim().isEmpty
              ? null
              : _companyController.text.trim()),
          role: drift.Value(_roleController.text.trim().isEmpty
              ? null
              : _roleController.text.trim()),
          category: drift.Value(_category),
          answerNotes: drift.Value(_answerController.text.trim().isEmpty
              ? null
              : _answerController.text.trim()),
          outcome: drift.Value(_outcome),
          linkedApplicationId: drift.Value(_linkedAppId),
          lastInteractedAt: drift.Value(DateTime.now()),
        ),
      );
    } else {
      await prepDao.insertQuestion(
        InterviewPrepTableCompanion.insert(
          questionAsked: questionText,
          company: drift.Value(_companyController.text.trim().isEmpty
              ? null
              : _companyController.text.trim()),
          role: drift.Value(_roleController.text.trim().isEmpty
              ? null
              : _roleController.text.trim()),
          category: drift.Value(_category),
          answerNotes: drift.Value(_answerController.text.trim().isEmpty
              ? null
              : _answerController.text.trim()),
          outcome: drift.Value(_outcome),
          linkedApplicationId: drift.Value(_linkedAppId),
          lastInteractedAt: drift.Value(DateTime.now()),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(applicationDaoProvider).watchAllApplications();

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
                  widget.existing != null ? 'Edit Question' : 'New Interview Question',
                  style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question Asked
            Text(
              'Question *',
              style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _questionController,
              maxLines: 2,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Tell me about a time you resolved a team conflict.',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Category & Outcome Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category',
                        style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        dropdownColor: context.bgSurface,
                        style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: context.bgBase,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.divider),
                          ),
                        ),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => setState(() => _category = val ?? _category),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Self-Assessment',
                        style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _outcome,
                        dropdownColor: context.bgSurface,
                        style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: context.bgBase,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.divider),
                          ),
                        ),
                        items: _outcomes
                            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (val) => setState(() => _outcome = val ?? _outcome),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Company & Role Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company (Optional)',
                        style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _companyController,
                        style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Stripe',
                          hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                          filled: true,
                          fillColor: context.bgBase,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.divider),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Role (Optional)',
                        style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _roleController,
                        style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. SDE-2',
                          hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                          filled: true,
                          fillColor: context.bgBase,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.divider),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Link to Application Dropdown
            StreamBuilder<List<ApplicationRow>>(
              stream: applicationsAsync,
              builder: (context, snapshot) {
                final apps = snapshot.data ?? [];
                if (apps.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link to Pipeline Application',
                      style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int?>(
                      initialValue: _linkedAppId,
                      dropdownColor: context.bgSurface,
                      style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.bgBase,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.divider),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None (General Question)'),
                        ),
                        ...apps.map(
                          (a) => DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text('${a.company} — ${a.role}'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _linkedAppId = val;
                          if (val != null) {
                            final matches = apps.where((a) => a.id == val);
                            if (matches.isNotEmpty) {
                              final match = matches.first;
                              if (_companyController.text.isEmpty) {
                                _companyController.text = match.company;
                              }
                              if (_roleController.text.isEmpty) {
                                _roleController.text = match.role;
                              }
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              },
            ),

            // Answer & Talking points (STAR format)
            Text(
              'Answer Notes / Talking Points',
              style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tip: Use STAR framework (Situation, Task, Action, Result) with metrics.',
              style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _answerController,
              maxLines: 4,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'S: At my previous company...\nT: We needed to reduce latency...\nA: I redesigned the caching tier...\nR: Reduced p99 by 42%.',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: AscentButton.ghost(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AscentButton.primary(
                    label: widget.existing != null ? 'Update' : 'Save Question',
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
