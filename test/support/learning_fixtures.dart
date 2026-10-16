import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/learning_hub/learning_catalog.dart';

/// Seeds persisted engagement, never a production bypass of the completion gate.
Future<void> seedLectureStudyEvidence(
  ProviderContainer container,
  int lectureId,
) async {
  await container.read(learningHubProvider.notifier).ready;
  final state = container.read(learningHubProvider);
  final courses = state.courses
      .map(
        (course) => course.id == state.activeCourseId
            ? course.copyWith(
                modules: course.modules
                    .map(
                      (module) => module.copyWith(
                        lectures: module.lectures
                            .map(
                              (lecture) => lecture.id == lectureId
                                  ? lecture.copyWith(
                                      studySeconds: lecture.durationSeconds,
                                    )
                                  : lecture,
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              )
            : course,
      )
      .toList();
  await LearningCatalog(
    container.read(databaseProvider),
    container.read(sharedPreferencesProvider),
  ).saveJson(jsonEncode(courses.map((c) => c.toJson()).toList()));
  container.invalidate(learningHubProvider);
  await container.read(learningHubProvider.notifier).ready;
}
