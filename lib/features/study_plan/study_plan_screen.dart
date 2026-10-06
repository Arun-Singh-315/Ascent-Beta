import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/learning_hub/learning_hub_models.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import 'add_course_sheet.dart';
import 'lecture_focus_player_sheet.dart';
import 'module_lecture_editor_sheets.dart';

class StudyPlanScreen extends ConsumerStatefulWidget {
  final String? courseId;
  const StudyPlanScreen({super.key, this.courseId});

  @override
  ConsumerState<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends ConsumerState<StudyPlanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.courseId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(learningHubProvider.notifier).switchCourse(widget.courseId!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCourseSwitcher(BuildContext context, LearningHubState state, LearningHubNotifier notifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CourseSwitcherSheet(state: state, notifier: notifier),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningHubProvider);
    final notifier = ref.read(learningHubProvider.notifier);
    final course = state.course;
    final activeLecture = state.activeLecture;

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: context.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: InkWell(
          onTap: () => _showCourseSwitcher(context, state, notifier),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    course.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: context.accentSecondary,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Course',
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: context.accentSecondary,
            onPressed: () => AddCourseSheet.show(context),
          ),
          IconButton(
            tooltip: 'Switch Course',
            icon: const Icon(Icons.swap_horiz_rounded),
            color: context.textPrimary,
            onPressed: () => _showCourseSwitcher(context, state, notifier),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Hero Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.bgSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.divider.withValues(alpha: 0.8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Progress ring + metrics
                          Row(
                            children: [
                              // Circular Progress Ring
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: CircularProgressIndicator(
                                      value: course.progressFraction,
                                      strokeWidth: 6,
                                      backgroundColor: const Color(0xFFF1EFEA),
                                      color: context.accentSecondary,
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${course.progressPercent}%',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${course.completedLectures}/${course.totalLectures}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9.5,
                                          color: context.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),

                              // Metrics chips
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: context.bgBase,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: context.divider),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.calendar_today_rounded, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${course.daysLeft}d left',
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: context.stateWarning.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: context.stateWarning.withValues(alpha: 0.3),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.timer_outlined, size: 12, color: context.stateWarning),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${course.targetMinutesPerDay} min/day target',
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: context.stateWarning,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${(course.totalWatchedSeconds ~/ 60)}m watched',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Description
                          Text(
                            course.description,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: context.textMuted,
                              height: 1.35,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Continue Lecture Button (calm forest sage / composed styling)
                          Builder(
                            builder: (context) {
                              final allLectures = course.modules.expand((m) => m.lectures).toList();
                              final activeIndex = allLectures.indexWhere((l) => l.id == activeLecture.id);
                              final lectureNum = activeIndex >= 0 ? activeIndex + 1 : 1;

                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.accentPrimary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () {
                                    LectureFocusPlayerSheet.show(context);
                                  },
                                  icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                                  label: Text(
                                    'Continue → Lecture $lectureNum: ${activeLecture.title}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tab bar (sleek segmented pill)
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.divider.withValues(alpha: 0.8)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: const EdgeInsets.all(3),
                        indicator: BoxDecoration(
                          color: context.accentPrimary,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: context.textMuted,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        tabs: const [
                          Tab(text: 'Modules'),
                          Tab(text: 'Lectures'),
                          Tab(text: 'Notes'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Modules
            _ModulesListView(
              course: course,
              onSelectLecture: (lecId) {
                notifier.selectLecture(lecId);
                LectureFocusPlayerSheet.show(context);
              },
            ),

            // Tab 2: Lectures
            _AllLecturesListView(
              course: course,
              activeLectureId: state.activeLectureId,
              onSelectLecture: (lecId) {
                notifier.selectLecture(lecId);
                LectureFocusPlayerSheet.show(context);
              },
            ),

            // Tab 3: Notes
            const _CourseNotesView(),
          ],
        ),
      ),
    );
  }
}

class _ModulesListView extends ConsumerWidget {
  final Course course;
  final ValueChanged<int> onSelectLecture;

  const _ModulesListView({
    required this.course,
    required this.onSelectLecture,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${course.modules.length} Modules · ${course.totalLectures} Lectures',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textMuted,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                showAddModuleSheet(
                  context,
                  ref,
                  course.id,
                  nextModuleId: course.modules.length + 1,
                );
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
              label: const Text('Add Module', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...course.modules.map((module) => _ModuleCard(
              courseId: course.id,
              courseModules: course.modules,
              module: module,
              onSelectLecture: onSelectLecture,
              onResume: () {
                final firstIncomplete = module.lectures.firstWhere(
                  (l) => !l.isCompleted,
                  orElse: () => module.lectures.first,
                );
                onSelectLecture(firstIncomplete.id);
              },
            )),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ModuleCard extends ConsumerStatefulWidget {
  final String courseId;
  final List<CourseModule> courseModules;
  final CourseModule module;
  final ValueChanged<int> onSelectLecture;
  final VoidCallback onResume;

  const _ModuleCard({
    required this.courseId,
    required this.courseModules,
    required this.module,
    required this.onSelectLecture,
    required this.onResume,
  });

  @override
  ConsumerState<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends ConsumerState<_ModuleCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final firstLecId = module.lectures.isNotEmpty ? module.lectures.first.id : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tappable Area
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.accentSecondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.folder_outlined, color: context.accentSecondary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.bgBase,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.divider),
                        ),
                        child: Text(
                          'Module ${module.id}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: context.textMuted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${module.completedCount}/${module.lectures.length} done',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: context.textMuted,
                        size: 20,
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, size: 18, color: context.textMuted),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val == 'edit') {
                            showEditModuleSheet(context, ref, widget.courseId, module);
                          } else if (val == 'add_lecture') {
                            showAddLectureSheet(
                              context,
                              ref,
                              widget.courseId,
                              widget.courseModules,
                              defaultModuleId: module.id,
                            );
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Edit Module'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'add_lecture',
                            child: Row(
                              children: [
                                Icon(Icons.playlist_add_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Add Lecture'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    module.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  if (module.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      module.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textMuted,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${module.durationHours} hrs · ${module.lectures.length} lectures',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${module.progressPercent}%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.accentSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    icon: const Icon(Icons.playlist_add_rounded, size: 16),
                    onPressed: () {
                      showAddLectureSheet(
                        context,
                        ref,
                        widget.courseId,
                        widget.courseModules,
                        defaultModuleId: module.id,
                      );
                    },
                    label: Text(
                      '+ Lecture',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    onPressed: widget.onResume,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      'Resume ($firstLecId)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded Lectures List inside Module
          if (_isExpanded) ...[
            Divider(height: 1, color: context.divider),
            if (module.lectures.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No lectures yet in this module. Tap "+ Lecture" to add one.',
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: module.lectures.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: context.divider.withValues(alpha: 0.4)),
                itemBuilder: (context, index) {
                  final lec = module.lectures[index];
                  return InkWell(
                    onTap: () => widget.onSelectLecture(lec.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: lec.isCompleted
                                  ? context.accentPrimary.withValues(alpha: 0.15)
                                  : context.bgBase,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: lec.isCompleted
                                    ? context.accentPrimary.withValues(alpha: 0.4)
                                    : context.divider,
                                width: 0.8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: lec.isCompleted
                                ? Icon(Icons.check_rounded, size: 14, color: context.accentPrimary)
                                : Text(
                                    '${index + 1}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lec.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lec.formattedDuration,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              color: context.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.play_circle_outline_rounded,
                            size: 18,
                            color: context.accentPrimary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _AllLecturesListView extends ConsumerStatefulWidget {
  final Course course;
  final int activeLectureId;
  final ValueChanged<int> onSelectLecture;

  const _AllLecturesListView({
    required this.course,
    required this.activeLectureId,
    required this.onSelectLecture,
  });

  @override
  ConsumerState<_AllLecturesListView> createState() => _AllLecturesListViewState();
}

class _AllLecturesListViewState extends ConsumerState<_AllLecturesListView> {
  int? _selectedModuleId; // null = all modules

  @override
  Widget build(BuildContext context) {
    final allLectures = widget.course.modules.expand((m) => m.lectures).toList();
    final displayedLectures = _selectedModuleId == null
        ? allLectures
        : allLectures.where((l) => l.moduleId == _selectedModuleId).toList();

    return Column(
      children: [
        // Module Filter Chips Horizontal Bar
        Container(
          height: 38,
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChipItem(
                label: 'All (${allLectures.length})',
                isSelected: _selectedModuleId == null,
                onTap: () => setState(() => _selectedModuleId = null),
              ),
              ...widget.course.modules.map(
                (m) => _FilterChipItem(
                  label: 'Mod ${m.id} (${m.lectures.length})',
                  isSelected: _selectedModuleId == m.id,
                  onTap: () => setState(() => _selectedModuleId = m.id),
                ),
              ),
            ],
          ),
        ),

        // Subheader count & Add action
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${displayedLectures.length} Lectures${_selectedModuleId != null ? " (Module $_selectedModuleId)" : ""}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                label: const Text('Add Lecture', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  showAddLectureSheet(
                    context,
                    ref,
                    widget.course.id,
                    widget.course.modules,
                    defaultModuleId: _selectedModuleId,
                  );
                },
              ),
            ],
          ),
        ),

        // Bounded, Rock-Solid Custom Cards List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: displayedLectures.length,
            itemBuilder: (context, index) {
              final lec = displayedLectures[index];
              final isCurrent = lec.id == widget.activeLectureId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? context.accentPrimary.withValues(alpha: 0.10)
                      : context.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent
                        ? context.accentPrimary.withValues(alpha: 0.45)
                        : context.divider.withValues(alpha: 0.7),
                    width: isCurrent ? 1.2 : 0.8,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onSelectLecture(lec.id),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          // 1. Index Pill (Fixed 32x32)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? context.accentPrimary
                                  : (lec.isCompleted
                                      ? context.accentPrimary.withValues(alpha: 0.15)
                                      : context.bgBase),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isCurrent
                                    ? context.accentPrimary
                                    : (lec.isCompleted
                                        ? context.accentPrimary.withValues(alpha: 0.4)
                                        : context.divider),
                                width: 0.8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: lec.isCompleted
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: isCurrent ? Colors.white : context.accentPrimary,
                                  )
                                : Text(
                                    '#${index + 1}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isCurrent ? Colors.white : context.textPrimary,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Title and Metadata Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  lec.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                    color: context.textPrimary,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        lec.moduleTitle,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '• ${lec.formattedDuration}',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isCurrent ? context.accentPrimary : context.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 3. Actions Row: Edit + Play button
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 16, color: context.textMuted),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: 'Edit lecture',
                            onPressed: () {
                              showEditLectureSheet(context, ref, widget.course.id, lec);
                            },
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? context.accentPrimary
                                  : context.accentSecondary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 16,
                              color: isCurrent ? Colors.white : context.accentSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.accentPrimary : context.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? context.accentPrimary : context.divider,
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : context.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CourseNotesView extends StatelessWidget {
  const _CourseNotesView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Kindle Reader Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.bgSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFD97706).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD97706).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: Color(0xFFD97706), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kindle-Style Notes Reader',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          'Read PDF cheatsheets & book chapters',
                          style: TextStyle(fontSize: 12, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Open any study PDF from your phone or study the built-in Spring Boot, Microservices, and MongoDB chapters in Warm Sepia, Dark OLED, or Day mode with page-turn gestures.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: context.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/book-reader');
                  },
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text(
                    'Open Book Reader 📖',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Quick Notes Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.divider.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 24, color: context.accentPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jot Down STAR & Concept Notes',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Access full note management from the main Notes tab.',
                      style: TextStyle(fontSize: 11, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/notes'),
                child: const Text('View Notes', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseSwitcherSheet extends StatelessWidget {
  final LearningHubState state;
  final LearningHubNotifier notifier;

  const _CourseSwitcherSheet({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.divider.withValues(alpha: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: context.accentSecondary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Switch Course',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Course'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      AddCourseSheet.show(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.courses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = state.courses[index];
                    final isSelected = c.id == state.activeCourseId;

                    return InkWell(
                      onTap: () {
                        notifier.switchCourse(c.id);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.accentSecondary.withValues(alpha: 0.10)
                              : context.bgBase,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? context.accentSecondary
                                : context.divider.withValues(alpha: 0.6),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isSelected
                                  ? context.accentSecondary
                                  : context.divider.withValues(alpha: 0.4),
                              child: Icon(
                                isSelected ? Icons.check_rounded : Icons.school_outlined,
                                size: 18,
                                color: isSelected ? Colors.white : context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: context.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${c.modules.length} modules • ${c.totalLectures} lectures • ${c.progressPercent}% completed',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isSelected ? context.accentSecondary : context.textMuted,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (state.courses.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                color: context.stateDanger,
                                onPressed: () {
                                  notifier.deleteCourse(c.id);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

