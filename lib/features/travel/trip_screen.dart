import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/travel/travel_providers.dart';
import '../../core/travel/travel_service.dart';
import '../../core/utils/human_time.dart';
import '../../shared/widgets/ascent_action_menu.dart';
import '../../shared/widgets/ascent_backdrop.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass_card.dart';
import 'bill_sheet.dart';
import 'travel_screen.dart';
import 'travel_ui.dart';
import 'trip_sheet.dart';
import 'visit_sheet.dart';

enum TripTab { plan, money, photos }

/// One trip: Plan (places by day), Money (bills and settle up), Photos.
class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key, required this.id, this.tab = TripTab.plan});
  final String id;
  final TripTab tab;

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  late TripTab _tab = widget.tab;

  Future<void> _more(TripView t) async {
    final action = await showAscentActionMenu<String>(
      context: context,
      title: t.trip.name,
      actions: const [
        AscentAction('edit', 'Edit trip and people', Icons.edit_outlined),
        AscentAction(
          'delete',
          'Delete trip',
          Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await showTripSheet(context, editing: t);
      return;
    }
    HapticFeedback.mediumImpact();
    await ref.read(travelServiceProvider).deleteTrip(t.id);
    if (!mounted) return;
    Navigator.of(context).maybePop();
    AscentSnackBar.show(
      context,
      message: 'Trip deleted. Its places stay in Travel.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.id));
    final t = trip.value;
    return AscentBackdrop(
      child: AscentScaffold(
        title: t?.trip.name ?? 'Trip',
        backgroundColor: Colors.transparent,
        actions: [
          if (t != null)
            AscentButton.icon(
              key: const ValueKey('trip_more'),
              icon: Icons.more_horiz_rounded,
              tooltip: 'More',
              semanticLabel: 'Trip actions',
              onPressed: () => _more(t),
            ),
        ],
        body: t == null
            ? (trip.isLoading
                  ? const SizedBox.shrink()
                  : const EmptyState(
                      icon: Icons.luggage_outlined,
                      title: 'This trip was deleted',
                      subtitle: 'Its places are still in Travel.',
                    ))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s16,
                  AppSpace.s8,
                  AppSpace.s16,
                  AppSpace.s40,
                ),
                children: [
                  _Header(trip: t),
                  const SizedBox(height: AppSpace.s16),
                  AscentSegmentedControl<TripTab>(
                    segments: const [
                      AscentSegment(
                        key: ValueKey('tab_plan'),
                        value: TripTab.plan,
                        label: 'Plan',
                      ),
                      AscentSegment(
                        key: ValueKey('tab_money'),
                        value: TripTab.money,
                        label: 'Money',
                      ),
                      AscentSegment(
                        key: ValueKey('tab_photos'),
                        value: TripTab.photos,
                        label: 'Photos',
                      ),
                    ],
                    selected: _tab,
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  switch (_tab) {
                    TripTab.plan => _Plan(trip: t),
                    TripTab.money => _Money(trip: t),
                    TripTab.photos => _Photos(trip: t),
                  },
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.trip});
  final TripView trip;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final names = trip.people.map((p) => p.name).join(', ');
    final day = trip.dayLabel(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (day != null)
          Text(
            day,
            style: AscentTextStyles.caption.copyWith(color: g.actionInk),
          ),
        Text(
          names,
          style: AscentTextStyles.supportingText.copyWith(
            color: g.inkSecondary,
          ),
        ),
      ],
    );
  }
}

/// Places grouped by day, newest day last, with "I'm here" at the end.
class _Plan extends ConsumerWidget {
  const _Plan({required this.trip});
  final TripView trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final byDay = <DateTime, List<VisitRow>>{};
    for (final v in trip.visits) {
      byDay
          .putIfAbsent(DateTime(v.at.year, v.at.month, v.at.day), () => [])
          .add(v);
    }
    final billByVisit = <String, double>{};
    for (final e in trip.expenses) {
      if (e.visitId != null && e.kind == 'expense') {
        billByVisit[e.visitId!] = (billByVisit[e.visitId!] ?? 0) + e.amount;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (byDay.isEmpty)
          EmptyState.inline(
            icon: Icons.place_outlined,
            title: 'Tap I’m here at each stop to build the trip',
            actionLabel: 'Add a place',
            onAction: () => showAddPlaceSheet(context, tripId: trip.id),
            tint: travelTint(context),
          ),
        for (final entry in byDay.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpace.s4,
              bottom: AppSpace.s8,
            ),
            child: Text(
              humanDay(entry.key),
              style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
            ),
          ),
          GlassCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: AppSpace.s4,
            ),
            child: Column(
              children: [
                for (final (i, v) in entry.value.indexed) ...[
                  if (i > 0) Divider(height: 1, color: g.line),
                  VisitRowTile(
                    key: ValueKey('trip_visit_${v.id}'),
                    visit: v,
                    trailing: billByVisit[v.id] == null
                        ? null
                        : rupees(billByVisit[v.id]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s20),
        ],
        HereCard(live: null),
        Align(
          alignment: Alignment.center,
          child: AscentButton.ghost(
            key: const ValueKey('trip_add_place'),
            label: 'Add a place by name',
            compact: true,
            onPressed: () => showAddPlaceSheet(context, tripId: trip.id),
          ),
        ),
      ],
    );
  }
}

/// Totals, who pays whom, and every bill.
class _Money extends ConsumerWidget {
  const _Money({required this.trip});
  final TripView trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final settle = trip.settlements;
    final bills = trip.expenses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(label: 'Total', value: rupees(trip.total)),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: _Metric(label: 'Your share', value: rupees(trip.myShare)),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
        if (trip.people.length > 1) ...[
          Text(
            'Settle up',
            style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
          ),
          const SizedBox(height: AppSpace.s8),
          GlassCard(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: settle.isEmpty
                ? Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: g.successInk),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          'Everyone is even.',
                          style: AscentTextStyles.body.copyWith(color: g.ink),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final s in settle)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_who(trip, s.from)} pay${s.from == trip.me?.id ? '' : 's'} ${trip.nameOf(s.to)}',
                                  style: AscentTextStyles.body.copyWith(
                                    color: g.ink,
                                  ),
                                ),
                              ),
                              Text(
                                rupees(s.amount),
                                style: AscentTextStyles.tabular(
                                  AscentTextStyles.body,
                                ).copyWith(color: g.ink),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        settle.length == 1
                            ? '1 payment settles everyone'
                            : '${settle.length} payments settle everyone',
                        style: AscentTextStyles.caption.copyWith(
                          color: g.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s12),
                      AscentButton.tonal(
                        key: const ValueKey('trip_settle'),
                        label: 'Mark settled',
                        expanded: true,
                        onPressed: () async {
                          final travel = ref.read(travelServiceProvider);
                          final ids = await travel.markSettled(trip.id);
                          HapticFeedback.lightImpact();
                          if (!context.mounted) return;
                          AscentSnackBar.undo(
                            context,
                            message: 'Marked settled',
                            onUndo: () async {
                              for (final id in ids) {
                                await travel.deleteBill(id);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpace.s20),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Bills',
                style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
              ),
            ),
            AscentButton.ghost(
              key: const ValueKey('trip_add_bill'),
              label: 'Add bill',
              icon: Icons.add_rounded,
              compact: true,
              onPressed: () => showBillSheet(context, tripId: trip.id),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        if (bills.isEmpty)
          EmptyState.inline(
            icon: Icons.receipt_long_outlined,
            title: 'Add a bill and Ascent works out who owes whom',
            actionLabel: 'Add bill',
            onAction: () => showBillSheet(context, tripId: trip.id),
            tint: travelTint(context),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: AppSpace.s4,
            ),
            child: Column(
              children: [
                for (final (i, b) in bills.indexed) ...[
                  if (i > 0) Divider(height: 1, color: g.line),
                  _BillRow(key: ValueKey('bill_${b.id}'), trip: trip, bill: b),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static String _who(TripView t, String id) =>
      id == t.me?.id ? 'You' : t.nameOf(id);
}

class _BillRow extends ConsumerWidget {
  const _BillRow({super.key, required this.trip, required this.bill});
  final TripView trip;
  final TripExpenseRow bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final settlement = bill.kind == 'settlement';
    final payer = bill.paidBy == trip.me?.id ? 'you' : trip.nameOf(bill.paidBy);
    return Dismissible(
      key: ValueKey('dismiss_${bill.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.s16),
        color: g.errorInk.withValues(alpha: .12),
        child: Icon(Icons.delete_outline_rounded, color: g.errorInk),
      ),
      onDismissed: (_) {
        final travel = ref.read(travelServiceProvider);
        travel.deleteBill(bill.id);
        AscentSnackBar.undo(
          context,
          message: 'Bill removed',
          onUndo: () => travel.deleteBill(bill.id, undo: true),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    style: AscentTextStyles.listRowTitle.copyWith(
                      color: settlement ? g.inkSecondary : g.ink,
                    ),
                  ),
                  Text(
                    settlement
                        ? 'Pay-back · ${humanWhen(bill.at)}'
                        : 'Paid by $payer · ${humanWhen(bill.at)}',
                    style: AscentTextStyles.caption.copyWith(
                      color: g.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              rupees(bill.amount),
              style: AscentTextStyles.tabular(
                AscentTextStyles.body,
              ).copyWith(color: settlement ? g.inkSecondary : g.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            value,
            style: AscentTextStyles.tabular(
              AscentTextStyles.pageTitle,
            ).copyWith(color: g.ink),
          ),
        ],
      ),
    );
  }
}

/// Every photo from the trip's places.
class _Photos extends ConsumerWidget {
  const _Photos({required this.trip});
  final TripView trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final photos = ref.watch(tripPhotosProvider(trip.id)).value ?? const [];
    if (photos.isEmpty) {
      return EmptyState.inline(
        icon: Icons.photo_library_outlined,
        title: trip.visits.isEmpty
            ? 'Add a place, then attach its photos'
            : 'Open a place and tap Photos to attach some',
        tint: travelTint(context),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpace.s4,
        crossAxisSpacing: AppSpace.s4,
      ),
      itemBuilder: (_, i) => GestureDetector(
        onTap: () => showVisitSheet(context, photos[i].visitId),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(photos[i].path),
            fit: BoxFit.cover,
            cacheWidth: 360,
            errorBuilder: (_, _, _) => Container(
              color: g.recessed,
              child: Icon(Icons.image_outlined, color: g.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}
