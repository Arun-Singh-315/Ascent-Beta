import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/glass_theme.dart';
import '../models/promise_model.dart';

/// Contextual 1-tap direct action button for promises.
/// Uses existing Apple glass styling with tactile haptic response.
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

    if (promise.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: g.sage.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: g.sage.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: g.sage),
            const SizedBox(width: 6),
            Text(
              'Completed',
              style: TextStyle(
                color: g.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      key: const ValueKey('home_promise_primary_action'),
      onPressed: isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed();
            },
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: g.bg,
              ),
            )
          : Icon(promise.contextualActionIcon, size: 17),
      label: Text(
        promise.contextualActionLabel,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: g.ink,
        foregroundColor: g.bg,
        disabledBackgroundColor: g.ink.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }
}
