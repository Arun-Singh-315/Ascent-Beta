import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../models/promise_model.dart';

/// Contextual 1-tap direct action button for promises.
/// Uses sleek glass styling with tactile haptic response.
class PromiseActionButton extends StatelessWidget {
  const PromiseActionButton({
    super.key,
    required this.promise,
    required this.onPressed,
    this.isLoading = false,
  });

  final PromiseModel promise;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    if (promise.isCompleted || promise.isDoneToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: g.sage.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: g.sage.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 15, color: g.sage),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                promise.isCompleted ? 'Completed' : 'Done today',
                style: TextStyle(
                  color: g.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isFutureStart = promise.schedule != null &&
        promiseDay(DateTime.now()).isBefore(promiseDay(promise.schedule!.startDate));

    if (isFutureStart) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              content: Text(
                'This commitment starts on ${DateFormat.MMMd().format(promise.schedule!.startDate)}. Tracking unlocks on that day.',
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: g.fill.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: g.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: g.inkSecondary),
              const SizedBox(width: 5),
              Text(
                'Starts ${DateFormat.MMMd().format(promise.schedule!.startDate)}',
                style: TextStyle(
                  color: g.inkSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final canAct = !isLoading && promise.canActAt(DateTime.now());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('home_promise_primary_action'),
        onTap: canAct
            ? () {
                HapticFeedback.lightImpact();
                onPressed();
              }
            : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: canAct
                ? g.ink.withValues(alpha: 0.88)
                : g.ink.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: canAct ? g.line : g.line.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: g.bg),
                )
              else ...[
                Icon(
                  promise.contextualActionIcon,
                  size: 15,
                  color: canAct ? g.bg : g.inkMuted,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  promise.contextualActionLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: canAct ? g.bg : g.inkMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
