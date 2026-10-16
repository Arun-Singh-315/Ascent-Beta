import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import 'thought_actions.dart';
import 'thought_conversion_sheet.dart';
import 'thought_merge_sheet.dart';

Future<bool> applyThoughtAction(
  BuildContext context,
  AppDatabase db,
  List<Thought> thoughts,
  String action,
) async {
  if (thoughts.isEmpty) return false;
  if (action == 'merge') {
    return await showThoughtMerge(context, db, thoughts);
  } else {
    return await showThoughtConversion(
      context,
      db,
      thoughts,
      initial: action == 'todo'
          ? ThoughtConversionMode.todo
          : action == 'both'
          ? ThoughtConversionMode.both
          : ThoughtConversionMode.reminder,
      grouped: action == 'list_reminder',
    );
  }
}
