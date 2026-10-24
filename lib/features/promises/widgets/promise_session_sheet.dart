import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';

/// Live session sheet for duration promises.
/// Allows starting, pausing, resuming, and recording completed time.
class PromiseSessionSheet extends ConsumerWidget {
  const PromiseSessionSheet({
    super.key,
    required this.promise,
  });

  final PromiseModel promise;

  static Future<void> show(BuildContext context, PromiseModel promise) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PromiseSessionSheet(promise: promise),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final session = ref.watch(activePromiseSessionProvider);
    final notifier = ref.read(activePromiseSessionProvider.notifier);

    final isThisSessionActive = session.promiseId == promise.id;
    final elapsedSec = isThisSessionActive ? session.elapsedSeconds : 0;
    final isRunning = isThisSessionActive && session.isRunning;

    final minutes = elapsedSec ~/ 60;
    final seconds = elapsedSec % 60;
    final timeFormatted =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final targetSec = (promise.targetValue * 60).toInt();
    final progress = targetSec > 0 ? (elapsedSec / targetSec).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              // Grab handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: g.inkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title and target
              Text(
                promise.title,
                textAlign: TextAlign.center,
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Target: ${promise.targetValue.toInt()} minutes',
                style: TextStyle(
                  color: g.inkMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 32),

              // Timer display
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: g.ink.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(g.ink),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeFormatted,
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        isRunning ? 'Session Active' : (elapsedSec > 0 ? 'Paused' : 'Ready to Start'),
                        style: TextStyle(
                          color: g.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Action buttons: Start/Pause/Resume and Finish
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isThisSessionActive || elapsedSec == 0)
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        notifier.startSession(promise.id);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Start Practice'),
                      style: FilledButton.styleFrom(
                        backgroundColor: g.ink,
                        foregroundColor: g.bg,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (isRunning) {
                          notifier.pauseSession();
                        } else {
                          notifier.resumeSession();
                        }
                      },
                      icon: Icon(
                        isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 20,
                        color: g.ink,
                      ),
                      label: Text(
                        isRunning ? 'Pause' : 'Resume',
                        style: TextStyle(color: g.ink, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: g.ink.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        final recordedMinutes = (elapsedSec / 60).ceil();
                        notifier.stopSession();
                        await ref.read(promiseRepositoryProvider).recordProgress(
                          promiseId: promise.id,
                          eventType: PromiseEventType.durationSession,
                          amount: recordedMinutes > 0 ? recordedMinutes.toDouble() : 1.0,
                          note: 'Practiced for $timeFormatted',
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Logged $recordedMinutes min for "${promise.title}"'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 20),
                      label: const Text('Complete & Save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: g.ink,
                        foregroundColor: g.bg,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }
}
