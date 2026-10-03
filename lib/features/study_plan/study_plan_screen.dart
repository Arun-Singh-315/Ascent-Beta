import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/learning_hub/learning_hub_models.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import 'lecture_focus_player_sheet.dart';

class StudyPlanScreen extends ConsumerStatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  ConsumerState<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends ConsumerState<StudyPlanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: Text(
          course.title,
          style: GoogleFonts.plusJakartaSans(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            color: context.textPrimary,
            onPressed: () {},
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
                                            color: Colors.redAccent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.redAccent),
                                              const SizedBox(width: 4),
                                              Text(
                                                '-${course.targetMinutesPerDay} min/day',
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.redAccent,
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

                          // Continue Lecture Button (matching video green button)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.accentSecondary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                LectureFocusPlayerSheet.show(context);
                              },
                              icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                              label: Text(
                                'Continue → Lecture ${activeLecture.id}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Tab bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.divider.withValues(alpha: 0.6)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: context.accentSecondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
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

class _ModulesListView extends StatelessWidget {
  final Course course;
  final ValueChanged<int> onSelectLecture;

  const _ModulesListView({
    required this.course,
    required this.onSelectLecture,
  });

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {},
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Module', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...course.modules.map((module) => _ModuleCard(
              module: module,
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

class _ModuleCard extends StatelessWidget {
  final CourseModule module;
  final VoidCallback onResume;

  const _ModuleCard({
    required this.module,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final firstLecId = module.lectures.isNotEmpty ? module.lectures.first.id : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.divider.withValues(alpha: 0.8)),
      ),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {},
                  child: Text(
                    'View Module',
                    style: TextStyle(
                      fontSize: 12.5,
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
                    backgroundColor: context.accentSecondary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: onResume,
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
        ],
      ),
    );
  }
}

class _AllLecturesListView extends StatelessWidget {
  final Course course;
  final int activeLectureId;
  final ValueChanged<int> onSelectLecture;

  const _AllLecturesListView({
    required this.course,
    required this.activeLectureId,
    required this.onSelectLecture,
  });

  @override
  Widget build(BuildContext context) {
    final allLectures = course.modules.expand((m) => m.lectures).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: allLectures.length,
      itemBuilder: (context, index) {
        final lec = allLectures[index];
        final isCurrent = lec.id == activeLectureId;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? context.accentSecondary.withValues(alpha: 0.12)
                : context.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent
                  ? context.accentSecondary.withValues(alpha: 0.5)
                  : context.divider.withValues(alpha: 0.7),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: isCurrent
                  ? context.accentSecondary
                  : (lec.isCompleted
                      ? context.accentPrimary.withValues(alpha: 0.2)
                      : context.bgBase),
              child: lec.isCompleted
                  ? Icon(Icons.check, size: 14, color: context.accentPrimary)
                  : Text(
                      '${lec.id}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? Colors.white : context.textPrimary,
                      ),
                    ),
            ),
            title: Text(
              lec.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: context.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              lec.moduleTitle,
              style: TextStyle(fontSize: 11, color: context.textMuted),
            ),
            trailing: Text(
              lec.formattedDuration,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: isCurrent ? context.accentSecondary : context.textMuted,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            onTap: () => onSelectLecture(lec.id),
          ),
        );
      },
    );
  }
}

class _CourseNotesView extends StatelessWidget {
  const _CourseNotesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notes_rounded, size: 48, color: context.textMuted),
          const SizedBox(height: 12),
          Text(
            'Course Notes',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jot key concepts, code snippets, and review questions here.',
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
        ],
      ),
    );
  }
}
