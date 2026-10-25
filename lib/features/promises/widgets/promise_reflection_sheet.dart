import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';

/// Private, lightweight reflection sheet for behavioral commitments.
class PromiseReflectionSheet extends ConsumerStatefulWidget {
  const PromiseReflectionSheet({super.key, required this.promise});

  final PromiseModel promise;

  static Future<void> show(BuildContext context, PromiseModel promise) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PromiseReflectionSheet(promise: promise),
    );
  }

  @override
  ConsumerState<PromiseReflectionSheet> createState() =>
      _PromiseReflectionSheetState();
}

class _PromiseReflectionSheetState
    extends ConsumerState<PromiseReflectionSheet> {
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: g.inkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              widget.promise.title,
              style: AscentTextStyles.homeTitle.copyWith(
                color: g.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A private moment with yourself. How did it go today?',
              style: TextStyle(color: g.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _noteController,
              maxLines: 4,
              style: TextStyle(color: g.ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Any thoughts or observations... (optional)',
                hintStyle: TextStyle(
                  color: g.inkMuted.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: g.ink.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: g.ink.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: g.ink.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: g.ink, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(color: g.inkMuted)),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          setState(() => _submitting = true);
                          HapticFeedback.mediumImpact();
                          try {
                            await ref
                                .read(promiseRepositoryProvider)
                                .recordProgress(
                                  promiseId: widget.promise.id,
                                  eventType: PromiseEventType.reflectionNote,
                                  amount: 1,
                                  note: _noteController.text.trim().isNotEmpty
                                      ? _noteController.text.trim()
                                      : 'Reflected today',
                                );
                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.of(context).pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Reflection noted in peace.'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } catch (_) {
                            if (context.mounted) {
                              setState(() => _submitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not save. Your reflection is still here.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: g.ink,
                    foregroundColor: g.bg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: g.bg,
                          ),
                        )
                      : const Text('Save Reflection'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
