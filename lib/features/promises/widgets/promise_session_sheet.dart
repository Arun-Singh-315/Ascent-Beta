import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';

class PromiseSessionSheet extends ConsumerStatefulWidget {
  const PromiseSessionSheet({super.key, required this.promise});
  final PromiseModel promise;
  static Future<void> show(BuildContext context, PromiseModel promise) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PromiseSessionSheet(promise: promise),
      );
  @override
  ConsumerState<PromiseSessionSheet> createState() =>
      _PromiseSessionSheetState();
}

class _PromiseSessionSheetState extends ConsumerState<PromiseSessionSheet> {
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Could not save. Your timer is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activePromiseSessionProvider);
    final notifier = ref.read(activePromiseSessionProvider.notifier);
    final mine = session.promiseId == widget.promise.id;
    final seconds = mine ? session.elapsedSeconds : 0;
    final time =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return PopScope(
      canPop: !_busy,
      child: GlassSurface(
        radius: 28,
        minimumOpacity: .9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.promise.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close timer',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.promise.targetValue.toStringAsFixed(0)} minutes · one small step',
              ),
              const SizedBox(height: 24),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                mine && session.isRunning
                    ? 'Timer running'
                    : mine
                    ? 'Paused'
                    : 'Ready when you are',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            if (!mine) {
                              await notifier.startSession(widget.promise.id);
                            } else if (session.isRunning) {
                              await notifier.pauseSession();
                            } else {
                              await notifier.resumeSession();
                            }
                          }),
                    icon: Icon(
                      mine && session.isRunning
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      mine && session.isRunning
                          ? 'Pause'
                          : mine
                          ? 'Resume'
                          : 'Start',
                    ),
                  ),
                  if (mine)
                    FilledButton.icon(
                      onPressed: _busy || seconds <= 0
                          ? null
                          : () => _run(() async {
                              await notifier.pauseSession();
                              final exactSeconds = ref
                                  .read(activePromiseSessionProvider)
                                  .elapsedSeconds;
                              await ref
                                  .read(promiseRepositoryProvider)
                                  .recordProgress(
                                    promiseId: widget.promise.id,
                                    eventType: PromiseEventType.durationSession,
                                    amount: exactSeconds / 60,
                                    note: 'Practiced for ${exactSeconds}s',
                                  );
                              await notifier.stopSession();
                              if (context.mounted) {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(context);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Practice saved.'),
                                  ),
                                );
                              }
                            }),
                      icon: const Icon(Icons.check),
                      label: Text(_busy ? 'Saving…' : 'Save practice'),
                    ),
                ],
              ),
              if (session.promiseId != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final discard = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Discard unsaved practice?'),
                              content: Text(
                                '${session.elapsedSeconds ~/ 60} min ${session.elapsedSeconds % 60}s will be removed from ${mine ? 'this' : 'your other'} timer.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Keep timer'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Discard'),
                                ),
                              ],
                            ),
                          );
                          if (discard == true) await notifier.stopSession();
                        }),
                  child: Text(mine ? 'Discard timer' : 'Discard other timer'),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'You can close this sheet. Your timer stays with you.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
