import 'learning_next_step_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/glass_theme.dart';
import '../../core/learning_hub/learning_hub_models.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/glass_surface.dart';
import 'add_course_sheet.dart';
import 'lecture_focus_player_sheet.dart';
import 'study_plan_screen.dart';

class CourseCatalogScreen extends ConsumerStatefulWidget {
  const CourseCatalogScreen({super.key});

  @override
  ConsumerState<CourseCatalogScreen> createState() =>
      _CourseCatalogScreenState();
}

class _CourseCatalogScreenState extends ConsumerState<CourseCatalogScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningHubProvider);
    final notifier = ref.read(learningHubProvider.notifier);
    final courses = state.courses;
    final g = context.glass;
    final query = _search.text.trim().toLowerCase();
    final visibleCourses = courses.where((c) {
      final completed =
          c.totalLectures > 0 && c.completedLectures == c.totalLectures;
      return ('${c.title} ${c.author} ${c.category}').toLowerCase().contains(
            query,
          ) &&
          (_filter == 'All' ||
              (_filter == 'Completed' ? completed : !completed));
    }).toList();

    return AscentScaffold(
      title: 'Learning Hub',
      subtitle: '${courses.length} courses · Choose your next step',
      glow2: g.slate,
      actions: [
        IconButton(
          tooltip: 'Kindle Book Reader',
          icon: const Icon(Icons.auto_stories_rounded),
          color: g.amber,
          onPressed: () {
            HapticFeedback.lightImpact();
            context.push('/book-reader');
          },
        ),
        IconButton(
          tooltip: 'Add Course',
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: g.clay,
          onPressed: () {
            HapticFeedback.lightImpact();
            AddCourseSheet.show(context);
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          LearningNextStepCard(
            course: state.course,
            activeLecture: state.activeLecture,
            elapsed: state.currentElapsedSeconds,
            playing: state.isPlaying,
            onPlayer: () {
              if (state.activeLecture.isCompleted &&
                  state.course.nextLecture != null) {
                notifier.selectLecture(state.course.nextLecture!.id);
              }
              LectureFocusPlayerSheet.show(context);
            },
            onSyllabus: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudyPlanScreen(courseId: state.activeCourseId),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR COURSES',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: g.inkMuted,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  AddCourseSheet.show(context);
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Add Course',
                  style: TextStyle(fontSize: 11.5),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: g.clay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextField(
            key: const ValueKey('course-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Search courses',
              hintText: 'Title, instructor or topic',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _search.clear()),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'In progress', 'Completed']
                .map(
                  (label) => ChoiceChip(
                    label: Text(label),
                    selected: _filter == label,
                    onSelected: (_) => setState(() => _filter = label),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          if (visibleCourses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Text('No courses match your search.'),
                  TextButton(
                    onPressed: () => setState(() {
                      _search.clear();
                      _filter = 'All';
                    }),
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
            ),
          // Courses List
          ...visibleCourses.map((course) {
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
          GlassSurface(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/book-reader');
            },
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: g.amberSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: g.amber.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: g.amber,
                    size: 22,
                  ),
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
                          color: g.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Read local PDF cheat sheets in Sepia, Dark OLED, or Day mode.',
                        style: TextStyle(fontSize: 11, color: g.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: g.inkMuted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
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
    final g = context.glass;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassSurface(
        onTap: onSelectCourse,
        radius: 20,
        customBorder: Border.all(
          color: isActiveCourse ? g.slate.withValues(alpha: 0.5) : g.edge,
          width: isActiveCourse ? 1.2 : 0.9,
        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: g.slateSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: g.slate.withValues(alpha: 0.35),
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
                            color: g.slate,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'CURRENTLY STUDYING',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: g.slate,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: g.fill,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: g.edge, width: 0.8),
                    ),
                    child: Text(
                      '${course.modules.length} MODULES',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: g.inkMuted,
                      ),
                    ),
                  ),
                Text(
                  '${course.daysLeft}d left · ${course.targetMinutesPerDay}m/day',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: g.inkMuted,
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
                color: g.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),

            // Instructor & curriculum meta
            Text(
              'By ${course.author} • ${course.totalLectures} lectures (${(course.totalDurationSeconds / 3600).toStringAsFixed(1)} hrs total)',
              style: TextStyle(fontSize: 12, color: g.inkMuted),
            ),
            const SizedBox(height: 14),

            // Progress Bar & Stats
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: course.progressFraction,
                minHeight: 6,
                backgroundColor: g.track,
                valueColor: AlwaysStoppedAnimation<Color>(g.slate),
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
                    color: g.inkMuted,
                  ),
                ),
                Text(
                  '${course.progressPercent}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: g.slate,
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
                      side: BorderSide(color: g.edge),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: g.ink,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onSelectCourse();
                    },
                    icon: const Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 16,
                    ),
                    label: Text(
                      'View Syllabus',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: g.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: g.clay,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onResumeLearning();
                    },
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
    );
  }
}
