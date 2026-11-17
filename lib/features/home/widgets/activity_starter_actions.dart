import 'package:flutter/material.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../today/add_activity_sheet.dart';

/// Soft empty-state actions for Things / Activity Hub:
/// - "Add a task": `primaryContainer` filled with `onPrimaryContainer` text.
/// - "Add a timer": outlined with 1px border + `secondary` text.
class ActivityStarterActions extends StatelessWidget {
  const ActivityStarterActions({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final c = context.c;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        // "Add a task" = primaryContainer filled
        Material(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            key: const ValueKey('starter_add_task'),
            borderRadius: BorderRadius.circular(999),
            onTap: () =>
                AddActivitySheet.show(context, initialKind: ActivityKind.todo),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add a task',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // "Add a timer" = outlined with 1px border + secondary text
        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: c.border, width: 1.0),
          ),
          child: InkWell(
            key: const ValueKey('starter_add_timer'),
            borderRadius: BorderRadius.circular(999),
            onTap: () => AddActivitySheet.show(
              context,
              initialKind: ActivityKind.duration,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: c.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add a timer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
