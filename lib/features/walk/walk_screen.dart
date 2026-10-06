import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';
import '../../core/walk/walk_tracking_service.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/empty_state.dart';

class WalkScreen extends ConsumerStatefulWidget {
  const WalkScreen({super.key});

  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _recenterMap(WalkTrackingState state) {
    if (state.currentLat != null && state.currentLng != null) {
      _mapController.move(LatLng(state.currentLat!, state.currentLng!), 16.5);
    }
  }

  Future<void> _showFinishDialog() async {
    final state = ref.read(walkTrackingProvider);
    final notesController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Finish Walk Session?',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${(state.distanceMeters / 1000.0).toStringAsFixed(2)} km'),
            const SizedBox(height: 4),
            Text('Duration: ${state.formattedDuration}'),
            const SizedBox(height: 4),
            Text('Avg Pace: ${state.formattedPace} /km'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Morning park route, evening brisk walk...',
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: AscentButton.outlined(
                  label: 'Cancel',
                  compact: true,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AscentButton.primary(
                  label: 'Save Walk',
                  compact: true,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (saved == true) {
      await ref.read(walkTrackingProvider.notifier).finishWalk(notes: notesController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Walk session saved to history!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walkState = ref.watch(walkTrackingProvider);
    final notifier = ref.read(walkTrackingProvider.notifier);
    final completedWalksAsync = ref.watch(completedWalksStreamProvider);
    final todayDistanceAsync = ref.watch(todayWalkDistanceStreamProvider);
    final goalAsync = ref.watch(activityGoalStreamProvider);

    final todayDistanceKm = (todayDistanceAsync.value ?? 0.0) / 1000.0;
    final targetDistanceKm = (goalAsync.value?.targetDistanceMeters ?? 5000.0) / 1000.0;
    final progress = (todayDistanceKm / targetDistanceKm).clamp(0.0, 1.0);

    final currentCenter = (walkState.currentLat != null && walkState.currentLng != null)
        ? LatLng(walkState.currentLat!, walkState.currentLng!)
        : const LatLng(28.6139, 77.2090); // default fallback coordinate

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        title: Text(
          'Walking & Activity',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.battery_saver_rounded, color: Colors.teal),
            tooltip: 'Background GPS Setup',
            onPressed: () => _showGpsBatteryGuide(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.accentPrimary,
          unselectedLabelColor: context.textMuted,
          indicatorColor: context.accentPrimary,
          tabs: const [
            Tab(text: 'Live GPS Tracker'),
            Tab(text: 'Walk History & Goals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Prevent accidental swipes during map gestures
        children: [
          // ── Tab 0: Live GPS Tracker ───────────────────────────────────────
          Stack(
            children: [
              // 1. OpenStreetMap Canvas via flutter_map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: currentCenter,
                  initialZoom: 16.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ascent.jobprep',
                  ),
                  if (walkState.routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: walkState.routePoints,
                          strokeWidth: 4.5,
                          color: context.accentPrimary,
                        ),
                      ],
                    ),
                  if (walkState.currentLat != null && walkState.currentLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(walkState.currentLat!, walkState.currentLng!),
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.accentPrimary,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // 2. GPS Quality Indicator Badge & Recenter Button
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.bgSurface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gps_fixed_rounded,
                            size: 14,
                            color: walkState.gpsSignal == GpsSignalQuality.good
                                ? context.accentPrimary
                                : (walkState.gpsSignal == GpsSignalQuality.permissionDenied
                                    ? context.stateDanger
                                    : Colors.orange),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            walkState.gpsSignal == GpsSignalQuality.good
                                ? 'GPS Signal: Strong'
                                : (walkState.gpsSignal == GpsSignalQuality.permissionDenied
                                    ? 'Location Permission Needed'
                                    : 'Acquiring GPS...'),
                            style: AscentTextStyles.labelSmall.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'recenter_gps_btn',
                      backgroundColor: context.bgSurface,
                      foregroundColor: context.textPrimary,
                      elevation: 2,
                      onPressed: () => _recenterMap(walkState),
                      child: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                  ],
                ),
              ),

              // 3. Floating Bottom Dashboard & Controls
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: AscentCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // JARVIS Live Coach Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0096C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0096C7).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.blur_on_rounded, color: Color(0xFF00B4D8), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                walkState.status == WalkTrackingStatus.tracking
                                    ? 'JARVIS: Cadence steady • Pacing ${walkState.formattedPace}/km • ${(walkState.distanceMeters / 1000.0).toStringAsFixed(2)} km covered'
                                    : (walkState.status == WalkTrackingStatus.paused
                                        ? 'JARVIS: Session paused. Catch your breath.'
                                        : 'JARVIS: Ready for outdoor activity. Target: ${(targetDistanceKm).toStringAsFixed(1)} km.'),
                                style: AscentTextStyles.bodySmall.copyWith(
                                  color: const Color(0xFF0096C7),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Metric row: Distance, Time, Pace, Calories
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricCol(
                            label: 'DISTANCE',
                            value: (walkState.distanceMeters / 1000.0).toStringAsFixed(2),
                            unit: 'km',
                            color: context.accentPrimary,
                          ),
                          _MetricCol(
                            label: 'TIME',
                            value: walkState.formattedDuration,
                            unit: '',
                            color: context.textPrimary,
                          ),
                          _MetricCol(
                            label: 'AVG PACE',
                            value: walkState.formattedPace,
                            unit: '/km',
                            color: context.textPrimary,
                          ),
                          _MetricCol(
                            label: 'CALORIES',
                            value: '${walkState.calories}',
                            unit: 'kcal',
                            color: context.accentSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Control buttons
                      if (walkState.status == WalkTrackingStatus.idle)
                        AscentButton.primary(
                          label: 'Start Outdoor Walk',
                          icon: Icons.play_arrow_rounded,
                          expanded: true,
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await notifier.startWalk();
                            if (!ok) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Please enable GPS & grant location permission to track walks.'),
                                ),
                              );
                            }
                          },
                        )
                      else if (walkState.status == WalkTrackingStatus.tracking)
                        Row(
                          children: [
                            Expanded(
                              child: AscentButton.outlined(
                                label: 'Pause',
                                icon: Icons.pause_rounded,
                                compact: true,
                                onPressed: notifier.pauseWalk,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AscentButton.primary(
                                label: 'Finish Walk',
                                icon: Icons.stop_rounded,
                                compact: true,
                                onPressed: _showFinishDialog,
                              ),
                            ),
                          ],
                        )
                      else if (walkState.status == WalkTrackingStatus.paused)
                        Row(
                          children: [
                            Expanded(
                              child: AscentButton.outlined(
                                label: 'Discard',
                                compact: true,
                                onPressed: () {
                                  notifier.discardWalk();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AscentButton.outlined(
                                label: 'Resume',
                                icon: Icons.play_arrow_rounded,
                                compact: true,
                                onPressed: notifier.resumeWalk,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AscentButton.primary(
                                label: 'Finish',
                                icon: Icons.check_rounded,
                                compact: true,
                                onPressed: _showFinishDialog,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Tab 1: Walk History & Goals ───────────────────────────────────
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Daily Goal Card
              AscentCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Today\'s Activity Goal', style: AscentTextStyles.headlineMedium.copyWith(color: context.textPrimary, fontSize: 16)),
                        Text('${(progress * 100).toInt()}%', style: AscentTextStyles.monoCode.copyWith(color: context.accentPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: context.bgBase,
                        valueColor: AlwaysStoppedAnimation<Color>(context.accentPrimary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${todayDistanceKm.toStringAsFixed(2)} km of ${targetDistanceKm.toStringAsFixed(1)} km target completed today.',
                      style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('Saved Walks', style: AscentTextStyles.headlineMedium.copyWith(color: context.textPrimary, fontSize: 17)),
              const SizedBox(height: 10),

              completedWalksAsync.when(
                data: (walks) {
                  if (walks.isEmpty) {
                    return EmptyState(
                      icon: Icons.directions_walk_rounded,
                      title: 'No Recorded Walks Yet',
                      subtitle: 'Start an outdoor walk with real GPS tracking to build your daily physical activity history.',
                      actionLabel: 'Go to Live Tracker',
                      onAction: () => _tabController.animateTo(0),
                    );
                  }

                  return Column(
                    children: walks.map((w) {
                      final km = (w.distanceMeters / 1000.0).toStringAsFixed(2);
                      final h = w.durationSeconds ~/ 3600;
                      final m = (w.durationSeconds % 3600) ~/ 60;
                      final s = w.durationSeconds % 60;
                      final durationStr = h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';

                      return AscentCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: context.accentPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.directions_walk_rounded, color: context.accentPrimary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMM d • h:mm a').format(w.startTime),
                                    style: AscentTextStyles.labelLarge.copyWith(color: context.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$durationStr • ${w.calories} kcal${w.notes != null ? ' • ${w.notes}' : ''}',
                                    style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$km km',
                              style: AscentTextStyles.monoCode.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.accentPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: context.textMuted),
                              onPressed: () => ref.read(walkDaoProvider).deleteWalk(w.id),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ],
      ),
    );
  }

  void _showGpsBatteryGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ctx.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: ctx.divider, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.battery_saver_rounded, color: Colors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Walk Tracking Setup',
                        style: AscentTextStyles.headlineMedium.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: ctx.textPrimary,
                        ),
                      ),
                      Text(
                        'Prevent Android from killing GPS when locked',
                        style: AscentTextStyles.bodySmall.copyWith(color: ctx.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _guideStep(
              number: '1',
              title: 'Open Android App Settings',
              description: 'Long press Ascent icon on your home screen > App info (or Phone Settings > Apps > Ascent).',
            ),
            const SizedBox(height: 12),
            _guideStep(
              number: '2',
              title: 'Set Battery to "Unrestricted"',
              description: 'Under Battery or App Battery Usage, change setting from "Optimized" to "Unrestricted". This allows continuous GPS recording.',
            ),
            const SizedBox(height: 12),
            _guideStep(
              number: '3',
              title: 'Keep GPS Live during Walk',
              description: 'Ascent will continue tracking your active route and distance even when your phone is in your pocket.',
            ),
            const SizedBox(height: 18),
            AscentButton.primary(
              label: 'Understood, Got it! 👍',
              expanded: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _guideStep({required String number, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Colors.teal.withValues(alpha: 0.2),
          child: Text(
            number,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AscentTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AscentTextStyles.bodySmall.copyWith(
                  color: context.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCol extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MetricCol({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AscentTextStyles.labelSmall.copyWith(
            color: context.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AscentTextStyles.displaySmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
