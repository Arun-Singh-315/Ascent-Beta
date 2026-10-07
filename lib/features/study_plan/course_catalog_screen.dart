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
import 'study_plan_screen.dart';

class CourseCatalogScreen extends ConsumerWidget {
  const CourseCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(learningHubProvider);
    final notifier = ref.read(learningHubProvider.notifier);
    final courses = state.courses;

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learning Hub',
              style: GoogleFonts.plusJakartaSans(
                color: context.textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${courses.length} Active Course${courses.length == 1 ? "" : "s"} · Structured Syllabus',
              style: GoogleFonts.jetBrainsMono(
                color: context.textMuted,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kindle Book Reader',
            icon: const Icon(Icons.auto_stories_rounded),
            color: context.accentSecondary,
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/book-reader');
            },
          ),
          IconButton(
            tooltip: 'Add Course',
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: context.accentPrimary,
            onPressed: () {
              HapticFeedback.lightImpact();
              AddCourseSheet.show(context);
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            // Top Summary Hero
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.divider.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.accentPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.school_rounded, color: context.accentPrimary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Learning Curriculum',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Pick a course to explore its modules, track lectures, or resume your player.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ENROLLED COURSES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: context.textMuted,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => AddCourseSheet.show(context),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Course', style: TextStyle(fontSize: 11.5)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: context.accentPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Courses List
            ...courses.map((course) {
              final isCurrent = course.id == state.activeCourseId;

              return _CourseHubCard(
                course: course,
                isActiveCourse: isCurrent,
                onSelectCourse: () {
                  notifier.switchCourse(course.id);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => StudyPlanScreen(courseId: course.id),
                    ),
                  );
                },
                onResumeLearning: () {
                  notifier.switchCourse(course.id);
                  LectureFocusPlayerSheet.show(context);
                },
              );
            }),

            const SizedBox(height: 16),

            // Kindle / Book Reader Quick Tile
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/book-reader');
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.bgSurface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.divider.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Color(0xFFD97706), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kindle-Style Notes & Book Reader',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Read local PDF cheat sheets in Sepia, Dark OLED, or Day mode.',
                            style: TextStyle(fontSize: 11, color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMuted),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _CourseHubCard extends StatelessWidget {
  final Course course;
  final bool isActiveCourse;
  final VoidCallback onSelectCourse;
  final VoidCallback onResumeLearning;

  const _CourseHubCard({
    required this.course,
    required this.isActiveCourse,
    required this.onSelectCourse,
    required this.onResumeLearning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActiveCourse
              ? context.accentPrimary.withValues(alpha: 0.5)
              : context.divider.withValues(alpha: 0.8),
          width: isActiveCourse ? 1.2 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelectCourse,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Row: Active indicator + target
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isActiveCourse)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.accentPrimary.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.accentPrimary,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'CURRENTLY STUDYING',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: context.accentPrimary,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.bgBase,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.divider, width: 0.8),
                        ),
                        child: Text(
                          '${course.modules.length} MODULES',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: context.textMuted,
                          ),
                        ),
                      ),
                    Text(
                      '${course.daysLeft}d left · ${course.targetMinutesPerDay}m/day',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Course Title
                Text(
                  course.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),

                // Instructor & curriculum meta
                Text(
                  'By ${course.author} • ${course.totalLectures} lectures (${(course.totalDurationSeconds / 3600).toStringAsFixed(1)} hrs total)',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 14),

                // Progress Bar & Stats
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: course.progressFraction,
                    minHeight: 6,
                    backgroundColor: context.bgBase,
                    valueColor: AlwaysStoppedAnimation<Color>(context.accentPrimary),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${course.completedLectures} of ${course.totalLectures} completed',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: context.textMuted,
                      ),
                    ),
                    Text(
                      '${course.progressPercent}%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.accentPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Actions row: "Syllabus" + "Resume Learning"
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.divider),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: onSelectCourse,
                        icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
                        label: Text(
                          'View Syllabus',
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
                          backgroundColor: context.accentPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: onResumeLearning,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text(
                          'Start / Resume',
                          style: TextStyle(
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
          ),
        ),
      ),
    );
  }
}
