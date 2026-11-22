import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_navigation.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/features/feature_registry.dart';
import '../../core/travel/travel_providers.dart';
import '../../core/travel/travel_service.dart';
import '../../core/utils/human_time.dart';
import '../../shared/widgets/ascent_backdrop.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass_card.dart';
import 'travel_ui.dart';
import 'trip_sheet.dart';
import 'visit_sheet.dart';

/// Travel: "I'm here" up top, then your trips, then every place you've been.
///
/// Opening it switches the Travel feature on, so its Home card can appear.
class TravelScreen extends ConsumerStatefulWidget {
  const TravelScreen({super.key});

  @override
  ConsumerState<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends ConsumerState<TravelScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final features = ref.read(unlockedFeaturesProvider);
      if (!features.contains(AscentFeature.travel)) {
        ref
            .read(unlockedFeaturesProvider.notifier)
            .unlock(AscentFeature.travel)
            .ignore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final trips = ref.watch(tripsProvider).value;
    final visits = ref.watch(recentVisitsProvider).value;
    final live = ref.watch(liveTripProvider);
    final loading = trips == null || visits == null;
    final empty = !loading && trips.isEmpty && visits.isEmpty;
    return AscentBackdrop(
      child: AscentScaffold(
        title: 'Travel',
        largeTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          AscentButton.icon(
            key: const ValueKey('travel_new_trip'),
            icon: Icons.add_rounded,
            tooltip: 'New trip',
            semanticLabel: 'New trip',
            onPressed: () => showTripSheet(context),
          ),
        ],
        body: loading
            ? const SizedBox.shrink()
            : empty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.s24),
                  child: EmptyState(
                    icon: Icons.place_outlined,
                    tint: travelTint(context),
                    title: 'Remember where you’ve been',
                    subtitle:
                        'Tap I’m here anywhere. Ascent fills in the place, '
                        'time and weather, then helps with bills and photos.',
                    actionLabel: 'I’m here',
                    onAction: () => showHereSheet(context),
                    starters: [
                      EmptyStarter(
                        label: 'Plan a trip',
                        icon: Icons.luggage_outlined,
                        onTap: () => showTripSheet(context),
                      ),
                      EmptyStarter(
                        label: 'Add a place',
                        icon: Icons.edit_location_alt_outlined,
                        onTap: () => showAddPlaceSheet(context),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s16,
                  AppSpace.s8,
                  AppSpace.s16,
                  AppSpace.s40,
                ),
                children: [
                  HereCard(live: live),
                  const SizedBox(height: AppSpace.s28),
                  if (trips.isNotEmpty) ...[
                    _Heading('Trips'),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s16,
                        vertical: AppSpace.s4,
                      ),
                      child: Column(
                        children: [
                          for (final (i, t) in trips.indexed) ...[
                            if (i > 0) Divider(height: 1, color: g.line),
                            _TripRow(key: ValueKey('trip_${t.id}'), trip: t),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.s28),
                  ],
                  if (visits.isNotEmpty) ...[
                    _Heading('Places'),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s16,
                        vertical: AppSpace.s4,
                      ),
                      child: Column(
                        children: [
                          for (final (i, v) in visits.indexed) ...[
                            if (i > 0) Divider(height: 1, color: g.line),
                            VisitRowTile(
                              key: ValueKey('visit_${v.id}'),
                              visit: v,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s8, left: AppSpace.s4),
    child: Text(
      text,
      style: AscentTextStyles.homeTitle.copyWith(color: context.glass.ink),
    ),
  );
}

/// The big "I'm here" card, with the live trip when there is one.
class HereCard extends StatelessWidget {
  const HereCard({super.key, this.live});
  final TripView? live;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final now = DateTime.now();
    return GlassCard(
      padding: const EdgeInsets.all(AppSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (live != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.open('/travel/trip?id=${live!.id}'),
              child: Row(
                children: [
                  const VisitTile(kind: 'transit', size: 44),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          live!.trip.name,
                          style: AscentTextStyles.homeTitle.copyWith(
                            color: g.ink,
                          ),
                        ),
                        Text(
                          [
                            live!.dayLabel(now) ?? '',
                            if (live!.total > 0) '${rupees(live!.total)} spent',
                            if (live!.myNet > 0.009)
                              'you owe ${rupees(live!.myNet)}',
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: AscentTextStyles.caption.copyWith(
                            color: g.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: g.inkMuted),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s16),
          ],
          AscentButton.primary(
            key: const ValueKey('travel_here'),
            label: 'I’m here',
            icon: Icons.my_location_rounded,
            expanded: true,
            onPressed: () => showHereSheet(context),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'One tap saves the place, time and weather. Location turns off '
            'right after.',
            textAlign: TextAlign.center,
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({super.key, required this.trip});
  final TripView trip;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final fmt = DateFormat('d MMM');
    final s = trip.trip.startDay;
    final e = trip.trip.endDay;
    final when = s == null
        ? null
        : e == null || e == s
        ? fmt.format(s)
        : '${fmt.format(s)} to ${fmt.format(e)}';
    final live = trip.dayLabel(DateTime.now());
    final sub = [
      live ?? when ?? '',
      if (trip.people.length > 1) '${trip.people.length} people',
      if (trip.total > 0) rupees(trip.total),
    ].where((x) => x.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () => context.open('/travel/trip?id=${trip.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: Row(
          children: [
            const VisitTile(kind: 'transit'),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.trip.name,
                    style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
                  ),
                  Text(
                    sub,
                    style: AscentTextStyles.caption.copyWith(
                      color: live != null ? g.actionInk : g.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: g.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// One visit in a list: icon, name, area and when.
class VisitRowTile extends StatelessWidget {
  const VisitRowTile({super.key, required this.visit, this.trailing});
  final VisitRow visit;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final sub = [
      if (visit.area != null) visit.area!,
      humanWhen(visit.at),
    ].join(' · ');
    return InkWell(
      onTap: () => showVisitSheet(context, visit.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: Row(
          children: [
            VisitTile(kind: visit.kind),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
                  ),
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.caption.copyWith(
                      color: g.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: AscentTextStyles.tabular(
                  AscentTextStyles.caption,
                ).copyWith(color: g.ink),
              ),
          ],
        ),
      ),
    );
  }
}
