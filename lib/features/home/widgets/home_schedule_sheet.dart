import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../plans/widgets/plan_collection_editor.dart';

/// All thought-to-plan entry points share the structured multi-item editor.
Future<void> showHomeSchedule(
  BuildContext context,
  Thought thought, {
  String? initialText,
}) => showPlanCollectionEditor(
  context,
  source: thought,
  initialText: initialText,
);
