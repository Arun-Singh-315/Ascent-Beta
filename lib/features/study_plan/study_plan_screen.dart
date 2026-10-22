import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'learning_next_step_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/learning_hub/learning_hub_models.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import 'add_course_sheet.dart';
import 'lecture_focus_player_sheet.dart';
import 'module_lecture_editor_sheets.dart';

class StudyPlanScreen extends ConsumerStatefulWidget {
  final String? courseId;
  const StudyPlanScreen({super.key, this.courseId});

  @override
  ConsumerState<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends ConsumerState<StudyPlanScreen>
    with SingleTickerProviderStateMixin {
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

  void _showCourseSwitcher(
    BuildContext context,
    LearningHubState state,
    LearningHubNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppPalette.transparent,
      builder: (ctx) => _CourseSwitcherSheet(state: state, notifier: notifier),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningHubProvider);
    final notifier = ref.read(learningHubProvider.notifier);
    final course = state.course;
    final activeLecture = state.activeLecture;

    return AscentScaffold(
      titleWidget: AppTapArea(
        onTap: () => _showCourseSwitcher(context, state, notifier),
        borderRadius: AppGeometry.roundedr10,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s6,
            vertical: AppSpace.s4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  course.title,
                  style: AppTypography.plusJakartaSans155W70030(
                    color: context.textPrimary,
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16,
                  vertical: AppSpace.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LearningNextStepCard(
                      compact: true,
                      course: course,
                      activeLecture: activeLecture,
                      elapsed: state.currentElapsedSeconds,
                      playing: state.isPlaying,
                      onPlayer: () {
                        if (activeLecture.isCompleted &&
                            course.nextLecture != null) {
                          notifier.selectLecture(course.nextLecture!.id);
                        }
                        LectureFocusPlayerSheet.show(context);
                      },
                      onSyllabus: () => _tabController.animateTo(0),
                    ),
                    const SizedBox(height: 16),
                    // Tab bar (sleek segmented pill)
                    AppCard(
                      height: 44,
                      nightDecoration: BoxDecoration(
                        color: context.bgSurface,
                        borderRadius: AppGeometry.roundedr14,
                        border: Border.all(
                          color: context.divider.withValues(alpha: 0.8),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: const EdgeInsets.all(AppSpace.s3),
                        indicator: BoxDecoration(
                          color: context.accentPrimary,
                          borderRadius: AppGeometry.roundedr11,
                        ),
                        dividerColor: AppPalette.transparent,
                        labelColor: AppPalette.white,
                        unselectedLabelColor: context.textMuted,
                        labelStyle: AppTypography.plusJakartaSans13W70031(),
                        unselectedLabelStyle:
                            AppTypography.plusJakartaSans13W60032(),
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

  const _ModulesListView({required this.course, required this.onSelectLecture});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${course.modules.length} Modules · ${course.totalLectures} Lectures',
              style: AppTypography.jetBrainsMono12W60033(
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
              label: const Text('Add Module', style: AppTypeRoles.typeRole27),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...course.modules.map(
          (module) => _ModuleCard(
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
          ),
        ),
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
    final firstLecId = module.lectures.isNotEmpty
        ? module.lectures.first.id
        : 1;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      nightDecoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: AppGeometry.roundedr18,
        border: Border.all(color: context.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tappable Area
          AppTapArea(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: AppGeometry.roundedr18,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppTag(
                        width: 32,
                        height: 32,
                        nightDecoration: BoxDecoration(
                          color: context.accentSecondary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: AppGeometry.roundedr8,
                        ),
                        child: Icon(
                          Icons.folder_outlined,
                          color: context.accentSecondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppTag(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s8,
                          vertical: AppSpace.s2,
                        ),
                        nightDecoration: BoxDecoration(
                          color: context.bgBase,
                          borderRadius: AppGeometry.roundedr10,
                          border: Border.all(color: context.divider),
                        ),
                        child: Text(
                          'Module ${module.id}',
                          style: AppTypography.jetBrainsMono105W70034(
                            color: context.textMuted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${module.completedCount}/${module.lectures.length} done',
                        style: AppTypography.jetBrainsMono11W60011(
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: context.textMuted,
                        size: 20,
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: context.textMuted,
                        ),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr12,
                        ),
                        onSelected: (val) {
                          if (val == 'edit') {
                            showEditModuleSheet(
                              context,
                              ref,
                              widget.courseId,
                              module,
                            );
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
                    style: AppTypography.plusJakartaSans15W70035(
                      color: context.textPrimary,
                    ),
                  ),
                  if (module.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      module.description,
                      style: AppTypeRoles.typeRole27.copyWith(
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
                        style: AppTypography.jetBrainsMono11Regular36(
                          color: context.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${module.progressPercent}%',
                        style: AppTypography.jetBrainsMono11W7002(
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
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s0,
              AppSpace.s16,
              AppSpace.s14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: context.surfaces.buttonStyle(
                      OutlinedButton.styleFrom(
                        side: BorderSide(color: context.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s9,
                        ),
                      ),
                      filled: false,
                      icon: false,
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
                      style: AppTypeRoles.typeRole17.copyWith(
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: context.surfaces.buttonStyle(
                      ElevatedButton.styleFrom(
                        backgroundColor: context.accentPrimary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s9,
                        ),
                      ),
                      filled: true,
                      icon: false,
                    ),
                    onPressed: widget.onResume,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      'Resume ($firstLecId)',
                      style: AppTypeRoles.typeRole38,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded Lectures List inside Module
          if (_isExpanded) ...[
            AppDivider(height: 1, color: context.divider),
            if (module.lectures.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpace.s16point0),
                child: Center(
                  child: Text(
                    'No lectures yet in this module. Tap "+ Lecture" to add one.',
                    style: AppTypeRoles.typeRole27.copyWith(
                      color: context.textMuted,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                itemCount: module.lectures.length,
                separatorBuilder: (context, index) => AppDivider(
                  height: 1,
                  color: context.divider.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final lec = module.lectures[index];
                  return AppTapArea(
                    onTap: () => widget.onSelectLecture(lec.id),
                    borderRadius: AppGeometry.roundedr10,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s8,
                        vertical: AppSpace.s8,
                      ),
                      child: Row(
                        children: [
                          AppTag(
                            width: 26,
                            height: 26,
                            nightDecoration: BoxDecoration(
                              color: lec.isCompleted
                                  ? context.accentPrimary.withValues(
                                      alpha: 0.15,
                                    )
                                  : context.bgBase,
                              borderRadius: AppGeometry.roundedr7,
                              border: Border.all(
                                color: lec.isCompleted
                                    ? context.accentPrimary.withValues(
                                        alpha: 0.4,
                                      )
                                    : context.divider,
                                width: AppBorderScale.w0point8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: lec.isCompleted
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: context.accentPrimary,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: AppTypography.jetBrainsMono105W70034(
                                      color: context.textPrimary,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lec.title,
                              style: AppTypography.plusJakartaSans125W60037(
                                color: lec.isCompleted
                                    ? context.textMuted
                                    : context.textPrimary,
                                decoration: lec.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: context.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lec.formattedDuration,
                            style: AppTypography.jetBrainsMono105Regular38(
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
  ConsumerState<_AllLecturesListView> createState() =>
      _AllLecturesListViewState();
}

class _AllLecturesListViewState extends ConsumerState<_AllLecturesListView> {
  int? _selectedModuleId; // null = all modules

  @override
  Widget build(BuildContext context) {
    final allLectures = widget.course.modules
        .expand((m) => m.lectures)
        .toList();
    final displayedLectures = _selectedModuleId == null
        ? allLectures
        : allLectures.where((l) => l.moduleId == _selectedModuleId).toList();

    return CustomScrollView(
      slivers: [
        // Module Filter Chips Horizontal Bar
        SliverToBoxAdapter(
          child: Container(
            height: 38,
            margin: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s10,
              AppSpace.s16,
              AppSpace.s4,
            ),
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
        ),

        // Subheader count & Add action
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s4,
              AppSpace.s16,
              AppSpace.s6,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${displayedLectures.length} Lectures${_selectedModuleId != null ? " (Module $_selectedModuleId)" : ""}',
                  style: AppTypography.jetBrainsMono115W60039(
                    color: context.textMuted,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                  label: const Text(
                    'Add Lecture',
                    style: AppTypeRoles.typeRole27,
                  ),
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
        ),

        // Bounded, Rock-Solid Custom Cards List
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s4,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final lec = displayedLectures[index];
              final isCurrent = lec.id == widget.activeLectureId;

              return AppCard(
                selected: isCurrent,
                margin: const EdgeInsets.only(bottom: AppSpace.s8),
                nightDecoration: BoxDecoration(
                  color: isCurrent
                      ? context.accentPrimary.withValues(alpha: 0.10)
                      : context.bgSurface,
                  borderRadius: AppGeometry.roundedr14,
                  border: Border.all(
                    color: isCurrent
                        ? context.accentPrimary.withValues(alpha: 0.45)
                        : context.divider.withValues(alpha: 0.7),
                    width: isCurrent ? 1.2 : 0.8,
                  ),
                ),
                child: Material(
                  color: AppPalette.transparent,
                  child: AppTapArea(
                    onTap: () => widget.onSelectLecture(lec.id),
                    borderRadius: AppGeometry.roundedr14,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s14,
                        vertical: AppSpace.s11,
                      ),
                      child: Row(
                        children: [
                          // 1. Index Pill (Fixed 32x32)
                          AppTag(
                            width: 32,
                            height: 32,
                            nightDecoration: BoxDecoration(
                              color: isCurrent
                                  ? context.accentPrimary
                                  : (lec.isCompleted
                                        ? context.accentPrimary.withValues(
                                            alpha: 0.15,
                                          )
                                        : context.bgBase),
                              borderRadius: AppGeometry.roundedr9,
                              border: Border.all(
                                color: isCurrent
                                    ? context.accentPrimary
                                    : (lec.isCompleted
                                          ? context.accentPrimary.withValues(
                                              alpha: 0.4,
                                            )
                                          : context.divider),
                                width: AppBorderScale.w0point8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: lec.isCompleted
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: isCurrent
                                        ? AppPalette.white
                                        : context.accentPrimary,
                                  )
                                : Text(
                                    '#${index + 1}',
                                    style: AppTypography.jetBrainsMono11W7002(
                                      color: isCurrent
                                          ? AppPalette.white
                                          : context.textPrimary,
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
                                  style: AppStateTypography.stateType11(
                                    state0: isCurrent,
                                    color: context.surfaces.contentForeground(isCurrent, lec.isCompleted
                                        ? context.textMuted
                                        : context.textPrimary),
                                    decoration: lec.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: context.textMuted,
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
                                        style: AppTypeRoles.typeRole4.copyWith(
                                          color: context.surfaces.contentForeground(isCurrent, context.textMuted),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '• ${lec.formattedDuration}',
                                      style:
                                          AppTypography.jetBrainsMono105W60041(
                                            color: context.surfaces.contentForeground(isCurrent, isCurrent
                                                ? context.accentPrimary
                                                : context.textMuted),
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
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: context.textMuted,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            tooltip: 'Edit lecture',
                            onPressed: () {
                              showEditLectureSheet(
                                context,
                                ref,
                                widget.course.id,
                                lec,
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          AppTag(
                            width: 28,
                            height: 28,
                            nightDecoration: BoxDecoration(
                              color: isCurrent
                                  ? context.accentPrimary
                                  : context.accentSecondary.withValues(
                                      alpha: 0.12,
                                    ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 16,
                              color: isCurrent
                                  ? AppPalette.white
                                  : context.accentSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }, childCount: displayedLectures.length),
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
    return AppGestureTap(
      onTap: onTap,
      child: AppPill(
        selected: isSelected,
        margin: const EdgeInsets.only(right: AppSpace.s6),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s6,
        ),
        nightDecoration: BoxDecoration(
          color: isSelected ? context.accentPrimary : context.bgSurface,
          borderRadius: AppGeometry.roundedr10,
          border: Border.all(
            color: isSelected ? context.accentPrimary : context.divider,
            width: AppBorderScale.w0point8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppStateTypography.stateType12(
            state0: isSelected,
            color: isSelected ? AppPalette.white : context.textPrimary,
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
      padding: const EdgeInsets.all(AppSpace.s20),
      children: [
        // Kindle Reader Hero Card
        AppCard(
          padding: const EdgeInsets.all(AppSpace.s20),
          nightDecoration: BoxDecoration(
            color: context.bgSurface,
            borderRadius: AppGeometry.roundedr22,
            border: Border.all(
              color: AppPalette.colorFFD97706.withValues(alpha: 0.35),
              width: AppBorderScale.w1point2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.colorFFD97706.withValues(alpha: 0.08),
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
                  AppCard(
                    width: 44,
                    height: 44,
                    nightDecoration: BoxDecoration(
                      color: AppPalette.colorFFD97706.withValues(alpha: 0.15),
                      borderRadius: AppGeometry.roundedr12,
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppPalette.colorFFD97706,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kindle-Style Notes Reader',
                          style: AppTypography.plusJakartaSans16W70012(
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          'Read PDF cheatsheets & book chapters',
                          style: AppTypeRoles.typeRole27.copyWith(
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Open any study PDF from your phone or study the built-in Spring Boot, Microservices, and MongoDB chapters in Warm Sepia, Dark OLED, or Day mode with page-turn gestures.',
                style: AppTypography.plusJakartaSans125Regular43(
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: context.surfaces.buttonStyle(
                    ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.colorFFD97706,
                      foregroundColor: AppPalette.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.s12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppGeometry.roundedr12,
                      ),
                    ),
                    filled: true,
                    icon: false,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/book-reader');
                  },
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text(
                    'Open Book Reader 📖',
                    style: AppTypeRoles.typeRole39,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Quick Notes Info
        AppCard(
          padding: const EdgeInsets.all(AppSpace.s16),
          nightDecoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.5),
            borderRadius: AppGeometry.roundedr16,
            border: Border.all(color: context.divider.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 24,
                color: context.accentPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jot Down STAR & Concept Notes',
                      style: AppTypography.plusJakartaSans13W70044(
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Keep course notes in Mind Space.',
                      style: AppTypeRoles.typeRole4.copyWith(
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/thought-wall'),
                child: const Text('View Notes', style: AppTypeRoles.typeRole27),
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
    return AppCard(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      nightDecoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: AppGeometry.radiusr24),
        border: Border.all(color: context.divider.withValues(alpha: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s20,
            AppSpace.s16,
            AppSpace.s20,
            AppSpace.s20,
          ),
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
                    borderRadius: AppGeometry.roundedr2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        color: context.accentSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Switch Course',
                        style: AppTypography.plusJakartaSans18W70045(
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

                    return AppTapArea(
                      onTap: () {
                        notifier.switchCourse(c.id);
                        Navigator.of(context).pop();
                      },
                      borderRadius: AppGeometry.roundedr14,
                      child: AppCard(
                        selected: isSelected,
                        padding: const EdgeInsets.all(AppSpace.s12),
                        nightDecoration: BoxDecoration(
                          color: isSelected
                              ? context.accentSecondary.withValues(alpha: 0.10)
                              : context.bgBase,
                          borderRadius: AppGeometry.roundedr14,
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
                                isSelected
                                    ? Icons.check_rounded
                                    : Icons.school_outlined,
                                size: 18,
                                color: isSelected
                                    ? AppPalette.white
                                    : context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.title,
                                    style:
                                        AppTypography.plusJakartaSans14W70021(
                                          color: context.surfaces.contentForeground(isSelected, context.textPrimary),
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${c.modules.length} modules • ${c.totalLectures} lectures • ${c.progressPercent}% completed',
                                    style:
                                        AppStateTypography.stateType13(
                                          state0: isSelected,
                                        ).copyWith(
                                          color: context.surfaces.contentForeground(isSelected, isSelected
                                              ? context.accentSecondary
                                              : context.textMuted),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (state.courses.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                color: context.stateDanger,
                                onPressed: () async {
                                  try {
                                    await notifier.deleteCourse(c.id);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not delete the course. Try again.',
                                          ),
                                        ),
                                      );
                                    }
                                  }
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
