import 'package:flutter/material.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../today/add_activity_sheet.dart';

/// Suggestions open an unsaved form; existing inline drafts stay untouched.
class ActivityStarterActions extends StatelessWidget {
  const ActivityStarterActions({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 10,
    runSpacing: 8,
    children: [
      AscentButton.outlined(
        key: const ValueKey('starter_add_task'),
        label: 'Add a task',
        icon: Icons.add_rounded,
        compact: true,
        strongOutline: true,
        onPressed: () =>
            AddActivitySheet.show(context, initialKind: ActivityKind.todo),
      ),
      AscentButton.outlined(
        key: const ValueKey('starter_add_timer'),
        label: 'Add a timer',
        icon: Icons.timer_outlined,
        compact: true,
        strongOutline: true,
        onPressed: () =>
            AddActivitySheet.show(context, initialKind: ActivityKind.duration),
      ),
    ],
  );
}
