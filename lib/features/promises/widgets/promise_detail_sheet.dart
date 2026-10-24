import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';
import 'promise_action_button.dart';
import 'promise_reflection_sheet.dart';
import 'promise_session_sheet.dart';

/// Detailed view of a commitment: intention, plan, history timeline, and lifecycle management.
class PromiseDetailSheet extends ConsumerStatefulWidget {
  const PromiseDetailSheet({
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
      builder: (_) => PromiseDetailSheet(promise: promise),
    );
  }

  @override
  ConsumerState<PromiseDetailSheet> createState() => _PromiseDetailSheetState();
}

class _PromiseDetailSheetState extends ConsumerState<PromiseDetailSheet> {
  late PromiseModel _current;
  List<PromiseProgressEvent> _events = [];
  bool _loadingEvents = true;

  @override
  void initState() {
    super.initState();
    _current = widget.promise;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final repo = ref.read(promiseRepositoryProvider);
    final events = await repo.getProgressEvents(_current.id);
    if (mounted) {
      setState(() {
        _events = events;
        _loadingEvents = false;
      });
    }
  }

  void _executeAction() {
    switch (_current.trackingType) {
      case PromiseTrackingType.duration:
        Navigator.pop(context);
        PromiseSessionSheet.show(context, _current);
        break;
      case PromiseTrackingType.reflection:
        Navigator.pop(context);
        PromiseReflectionSheet.show(context, _current);
        break;
      case PromiseTrackingType.completion:
      case PromiseTrackingType.frequency:
      case PromiseTrackingType.milestone:
        _quickMarkDone();
        break;
    }
  }

  Future<void> _quickMarkDone() async {
    final repo = ref.read(promiseRepositoryProvider);
    await repo.recordProgress(
      promiseId: _current.id,
      eventType: PromiseEventType.completion,
      amount: 1,
      note: 'Checked in directly',
    );
    final updated = await repo.getPromiseById(_current.id);
    if (mounted && updated != null) {
      setState(() => _current = updated);
      _loadEvents();
    }
  }

  Future<void> _togglePause() async {
    final repo = ref.read(promiseRepositoryProvider);
    final newStatus = _current.isPaused ? PromiseStatus.active : PromiseStatus.paused;
    await repo.setPromiseStatus(_current.id, newStatus);
    final updated = await repo.getPromiseById(_current.id);
    if (mounted && updated != null) {
      setState(() => _current = updated);
    }
  }

  Future<void> _deletePromise() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Promise?'),
        content: const Text('This will remove this commitment and its history cleanly.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(promiseRepositoryProvider).deletePromise(_current.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.90,
      ),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Handle and top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: g.inkMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _current.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: g.inkMuted,
                      size: 20,
                    ),
                    tooltip: _current.isPaused ? 'Resume' : 'Pause',
                    onPressed: _togglePause,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: g.inkMuted, size: 20),
                    tooltip: 'Delete',
                    onPressed: _deletePromise,
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: g.inkMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  // Title & Tags
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: g.ink.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _current.category.toUpperCase(),
                          style: TextStyle(
                            color: g.inkMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (_current.isPrivate) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.lock_rounded, size: 14, color: g.inkMuted),
                      ],
                      if (_current.isPaused) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Paused',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  Text(
                    _current.title,
                    style: AscentTextStyles.homeTitle.copyWith(
                      color: g.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (_current.intention.isNotEmpty) ...[
                    Text(
                      '"${_current.intention}"',
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _current.progressFraction,
                      minHeight: 8,
                      backgroundColor: g.ink.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(g.ink),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _current.progressSummary,
                    style: TextStyle(
                      color: g.inkMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  PromiseActionButton(
                    promise: _current,
                    onPressed: _executeAction,
                  ),
                  const SizedBox(height: 28),

                  // History Timeline Header
                  Text(
                    'Commitment History',
                    style: TextStyle(
                      color: g.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_loadingEvents)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_events.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: g.ink.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'No actions recorded yet. Your journey starts with the first step.',
                        style: TextStyle(
                          color: g.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    for (final event in _events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: g.ink,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.note ?? 'Progress logged',
                                    style: TextStyle(
                                      color: g.ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${event.occurredAt.day}/${event.occurredAt.month}/${event.occurredAt.year} • ${event.amount > 0 ? '+${event.amount.toInt()}' : ''}',
                                    style: TextStyle(
                                      color: g.inkMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
