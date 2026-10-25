import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/glass_surface.dart';

class PromiseCheckInSheet extends ConsumerStatefulWidget {
  const PromiseCheckInSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PromiseCheckInSheet(),
    );
  }

  @override
  ConsumerState<PromiseCheckInSheet> createState() =>
      _PromiseCheckInSheetState();
}

class _PromiseCheckInSheetState extends ConsumerState<PromiseCheckInSheet> {
  int _currentIndex = 0;
  bool _showingReflection = false;
  int _keptCount = 0;
  int _slippedCount = 0;
  bool _isFinished = false;

  final List<String> _reflectionReasons = const [
    'Distracted',
    'Tired / Exhausted',
    'Overcommitted',
    'Emergency',
  ];

  Future<void> _handleKept(Thought promise, List<Thought> allToday) async {
    HapticFeedback.lightImpact();
    await ref.read(thoughtDaoProvider).setCompleted(promise.id, true);
    setState(() {
      _keptCount++;
      _nextStep(allToday);
    });
  }

  void _handleStillOnIt(List<Thought> allToday) {
    HapticFeedback.selectionClick();
    setState(() {
      _nextStep(allToday);
    });
  }

  void _promptSlipped() {
    HapticFeedback.mediumImpact();
    setState(() {
      _showingReflection = true;
    });
  }

  Future<void> _recordSlipped(
    Thought promise,
    String reason,
    List<Thought> allToday,
  ) async {
    await ref
        .read(thoughtDaoProvider)
        .updateThought(
          promise
              .toCompanion(true)
              .copyWith(promptQuestion: drift.Value('Slipped: $reason')),
        );
    setState(() {
      _slippedCount++;
      _showingReflection = false;
      _nextStep(allToday);
    });
  }

  void _nextStep(List<Thought> allToday) {
    if (_currentIndex + 1 < allToday.length) {
      _currentIndex++;
    } else {
      _isFinished = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final thoughtsAsync = ref.watch(allThoughtsStreamProvider);
    final allThoughts = thoughtsAsync.value ?? [];
    final now = DateTime.now();

    final todayPromises = allThoughts
        .where(
          (t) =>
              t.mood == 'promise' &&
              !t.isArchived &&
              DateUtils.isSameDay(t.createdAt, now),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassSurface(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: thoughtsAsync.isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: g.inkMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (todayPromises.isEmpty) ...[
                      const SizedBox(height: 12),
                      Icon(Icons.handshake_outlined, size: 40, color: g.clay),
                      const SizedBox(height: 12),
                      Text(
                        'No promises to review for today',
                        textAlign: TextAlign.center,
                        style: AscentTextStyles.homeTitle.copyWith(
                          color: g.ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: g.clay,
                          foregroundColor: g.bg,
                        ),
                        child: const Text('Close'),
                      ),
                    ] else if (_isFinished) ...[
                      // Accountability Summary
                      const SizedBox(height: 10),
                      Icon(Icons.verified_rounded, size: 48, color: g.clay),
                      const SizedBox(height: 12),
                      Text(
                        'Accountability Summary',
                        textAlign: TextAlign.center,
                        style: AscentTextStyles.homeTitle.copyWith(
                          color: g.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_keptCount Kept • $_slippedCount Slipped',
                        textAlign: TextAlign.center,
                        style: AscentTextStyles.bodyMedium.copyWith(
                          color: g.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: g.clay.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: g.clay.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          _keptCount >= _slippedCount
                              ? '“Shabash bhai! Real discipline isn’t never slipping — it’s facing it honestly and coming back stronger tomorrow.”'
                              : '“Honesty is the real victory today. Slipped promises are just lessons. Reset tonight and take on tomorrow.”',
                          textAlign: TextAlign.center,
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: g.ink,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: g.clay,
                          foregroundColor: g.bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Done'),
                      ),
                    ] else ...[
                      // One-by-one step
                      _buildPromiseStep(
                        todayPromises[_currentIndex],
                        todayPromises,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPromiseStep(Thought promise, List<Thought> allToday) {
    final g = context.glass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Promise ${_currentIndex + 1} of ${allToday.length}',
              style: AscentTextStyles.labelSmall.copyWith(
                color: g.clay,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: g.clay.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Accountability',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: g.inkMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: g.clay.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: g.clay.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.handshake_rounded, size: 12, color: g.clay),
                const SizedBox(width: 5),
                Text(
                  'PROMISE',
                  style: AscentTextStyles.homeCaption.copyWith(
                    color: g.clay,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          promise.content,
          textAlign: TextAlign.center,
          style: AscentTextStyles.homeTitle.copyWith(
            color: g.ink,
            fontSize: 19,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bhai, sach batao — what’s the status?',
          textAlign: TextAlign.center,
          style: AscentTextStyles.bodySmall.copyWith(
            color: g.inkMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 20),
        if (_showingReflection) ...[
          Text(
            'What got in the way?',
            textAlign: TextAlign.center,
            style: AscentTextStyles.labelMedium.copyWith(
              color: g.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _reflectionReasons.map((reason) {
              return ActionChip(
                label: Text(reason),
                backgroundColor: g.track,
                side: BorderSide(color: g.line),
                labelStyle: TextStyle(color: g.ink, fontSize: 13),
                onPressed: () => _recordSlipped(promise, reason, allToday),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _showingReflection = false),
            child: Text('Cancel', style: TextStyle(color: g.inkMuted)),
          ),
        ] else ...[
          FilledButton.icon(
            key: const ValueKey('check_in_kept_button'),
            onPressed: () => _handleKept(promise, allToday),
            icon: const Icon(Icons.emoji_events_outlined, size: 18),
            label: const Text('Kept it! 🏆'),
            style: FilledButton.styleFrom(
              backgroundColor: g.clay,
              foregroundColor: g.bg,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('check_in_still_button'),
            onPressed: () => _handleStillOnIt(allToday),
            icon: Icon(Icons.hourglass_empty_rounded, size: 18, color: g.ink),
            label: Text('Still on it ⏳', style: TextStyle(color: g.ink)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: g.line),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('check_in_slipped_button'),
            onPressed: _promptSlipped,
            icon: Icon(
              Icons.heart_broken_outlined,
              size: 17,
              color: g.inkMuted,
            ),
            label: Text(
              'Slipped / Broke it 💔',
              style: TextStyle(color: g.inkMuted, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}
