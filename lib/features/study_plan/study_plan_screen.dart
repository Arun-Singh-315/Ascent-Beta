import 'package:flutter/material.dart';
import '../../shared/widgets/coming_soon_screen.dart';

class StudyPlanScreen extends StatelessWidget {
  final String? courseId;
  const StudyPlanScreen({super.key, this.courseId});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Study Plan',
      subtitle:
          'Structured curriculum planning and lecture progression. Use the Learning Hub on Home to continue your active lectures!',
      icon: Icons.school_rounded,
    );
  }
}
