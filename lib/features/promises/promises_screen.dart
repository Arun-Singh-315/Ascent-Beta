import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/promise_service.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/glass_chip.dart';
import '../../shared/widgets/glass_surface.dart';
import '../thought_wall/drop_thought_sheet.dart';
import 'promise_check_in_sheet.dart';
import 'promise_ui.dart';

class PromisesScreen extends ConsumerStatefulWidget {
  const PromisesScreen({super.key});
  @override
  ConsumerState<PromisesScreen> createState() => _PromisesScreenState();
}

class _PromisesScreenState extends ConsumerState<PromisesScreen> {
  Timer? _refreshTimer;
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  void _refresh() {
    _refreshTimer?.cancel();
    final now = DateTime.now();
    final next =
        _nextCheckIn(now) ?? DateTime(now.year, now.month, now.day + 1);
    _refreshTimer = Timer(
      next.difference(now) + const Duration(seconds: 1),
      _refresh,
    );
    if (mounted) setState(() {});
  }

  DateTime? _nextCheckIn(DateTime now) {
    for (final hour in PromiseService.checkInHours) {
      final time = DateTime(now.year, now.month, now.day, hour);
      if (time.isAfter(now)) return time;
    }
    return null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _showSchedule() {
    final now = DateTime.now();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily check-ins', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Each notification brings your open promises together.'),
            const SizedBox(height: 12),
            for (final hour in PromiseService.checkInHours)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  hour <= now.hour
                      ? Icons.check_rounded
                      : Icons.notifications_none_rounded,
                ),
                title: Text(
                  DateFormat(
                    'h:mm a',
                  ).format(DateTime(now.year, now.month, now.day, hour)),
                ),
                trailing: hour <= now.hour ? const Text('Passed') : null,
              ),
            const SizedBox(height: 8),
            const Text(
              'Only remaining times today. Kept and archived promises are left out.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _keep(Thought promise) async {
    try {
      await ref.read(thoughtDaoProvider).setCompleted(promise.id, true);
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not update your promise. Please retry.',
        );
      }
    }
  }

  Widget _promiseCard(Thought promise, int number) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassSurface(
        key: ValueKey('promise_card_${promise.id}'),
        enableBlur: false,
        radius: 18,
        fillColor: promise.isCompleted ? g.sage.withValues(alpha: .10) : null,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '$number'.padLeft(2, '0'),
                    style: TextStyle(
                      color: g.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      promise.content,
                      style: AppTypography.thoughtContent(
                        color: promise.isCompleted ? g.inkMuted : g.ink,
                      ).copyWith(fontSize: 17),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit promise',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.edit_outlined, size: 17, color: g.inkMuted),
                  onPressed: () =>
                      DropThoughtSheet.show(context, existingThought: promise),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GlassChip(
                label: promise.isCompleted ? 'Kept' : 'Mark kept',
                icon: promise.isCompleted ? Icons.check_rounded : Icons.check,
                success: promise.isCompleted,
                onTap: promise.isCompleted ? null : () => _keep(promise),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final promises = ref.watch(allThoughtsStreamProvider);
    return AscentScaffold(
      title: 'Promises',
      showFeatureHelp: false,
      body: promises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(allThoughtsStreamProvider),
            child: const Text('Retry promises'),
          ),
        ),
        data: (items) {
          final now = DateTime.now();
          final today = items
              .where(
                (t) =>
                    t.mood == 'promise' &&
                    !t.isArchived &&
                    DateUtils.isSameDay(t.createdAt, now),
              )
              .toList();
          final active = today.where((t) => !t.isCompleted).toList();
          final kept = today.where((t) => t.isCompleted).toList();
          final next = _nextCheckIn(now);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today',
                        style: AppTypography.thoughtContent(
                          color: g.ink,
                        ).copyWith(fontSize: 30, height: 1.2),
                      ),
                      if (today.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${active.length} active · ${kept.length} kept',
                          style: TextStyle(color: g.inkMuted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  if (today.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => PromiseCheckInSheet.show(context),
                          icon: const Icon(Icons.record_voice_over_outlined, size: 16),
                          label: const Text('Bhai Check-in'),
                          style: FilledButton.styleFrom(
                            backgroundColor: g.clay.withValues(alpha: 0.15),
                            foregroundColor: g.clay,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        PromiseActionButton(
                          label: 'Add promise',
                          icon: Icons.add,
                          onPressed: () => DropThoughtSheet.showPromise(context),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (today.isEmpty)
                GlassSurface(
                  key: const ValueKey('promise_empty'),
                  enableBlur: false,
                  radius: 22,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: g.ink.withValues(alpha: .18),
                          ),
                        ),
                        child: Icon(
                          Icons.handshake_outlined,
                          size: 30,
                          color: g.ink,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'No promises yet',
                        style: AppTypography.thoughtContent(
                          color: g.ink,
                        ).copyWith(fontSize: 23),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: PromiseActionButton(
                          label: 'Create a promise',
                          icon: Icons.add,
                          onPressed: () =>
                              DropThoughtSheet.showPromise(context),
                        ),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < active.length; i++)
                _promiseCard(active[i], i + 1),
              if (kept.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: g.sage),
                      const SizedBox(width: 8),
                      Text(
                        'KEPT · ${kept.length}',
                        style: TextStyle(
                          color: g.inkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < kept.length; i++)
                  _promiseCard(kept[i], active.length + i + 1),
              ],
              const SizedBox(height: 12),
              GlassSurface(
                enableBlur: false,
                radius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                onTap: _showSchedule,
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 19,
                      color: g.inkMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        active.isNotEmpty ? 'Next check-in' : 'Daily check-ins',
                        style: TextStyle(color: g.inkMuted, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        active.isNotEmpty
                            ? (next == null
                                  ? 'Finished for today'
                                  : DateFormat('h:mm a').format(next))
                            : '4 times',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: g.inkMuted,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
