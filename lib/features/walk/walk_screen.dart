import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
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
  bool _showOnlineMap = false;

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
              // 1. High-Performance Vector Route Canvas (default zero-lag) OR Online Map
              if (_showOnlineMap)
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
                )
              else
                _WalkFitnessHud(
                  walkState: walkState,
                  targetDistanceKm: targetDistanceKm,
                ),

              // 2. Controls & Mode Toggle Header
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // GPS Quality Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.bgSurface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.divider.withValues(alpha: 0.8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gps_fixed_rounded,
                            size: 13,
                            color: walkState.gpsSignal == GpsSignalQuality.good
                                ? context.accentPrimary
                                : (walkState.gpsSignal == GpsSignalQuality.permissionDenied
                                    ? context.stateDanger
                                    : Colors.orange),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            walkState.gpsSignal == GpsSignalQuality.good
                                ? 'GPS: Strong'
                                : (walkState.gpsSignal == GpsSignalQuality.permissionDenied
                                    ? 'Permission Needed'
                                    : 'Searching...'),
                            style: AscentTextStyles.labelSmall.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Online Map / Radar HUD Switcher
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _showOnlineMap = !_showOnlineMap;
                        });
                        if (_showOnlineMap) {
                          ScaffoldMessenger.of(context).removeCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Connecting to online map. Turn on internet if tiles don\'t load.',
                                style: TextStyle(fontSize: 12),
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.bgSurface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _showOnlineMap
                                ? context.accentPrimary.withValues(alpha: 0.6)
                                : context.divider.withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showOnlineMap ? Icons.fitness_center_rounded : Icons.map_outlined,
                              size: 14,
                              color: _showOnlineMap ? context.accentPrimary : context.textPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showOnlineMap ? 'Fitness HUD' : 'Map View',
                              style: AscentTextStyles.labelSmall.copyWith(
                                color: _showOnlineMap ? context.accentPrimary : context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showOnlineMap) ...[
                      const SizedBox(width: 8),
                      FloatingActionButton.small(
                        heroTag: 'recenter_gps_btn',
                        backgroundColor: context.bgSurface,
                        foregroundColor: context.textPrimary,
                        elevation: 2,
                        onPressed: () => _recenterMap(walkState),
                        child: const Icon(Icons.my_location_rounded, size: 18),
                      ),
                    ],
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
                            Builder(
                              builder: (context) {
                                final assistantName = ref.watch(assistantNameProvider);
                                return Expanded(
                                  child: Text(
                                    walkState.status == WalkTrackingStatus.tracking
                                        ? '$assistantName: Cadence steady • Pacing ${walkState.formattedPace}/km • ${(walkState.distanceMeters / 1000.0).toStringAsFixed(2)} km covered'
                                        : (walkState.status == WalkTrackingStatus.paused
                                            ? '$assistantName: Session paused. Catch your breath.'
                                            : '$assistantName: Ready for outdoor activity. Target: ${(targetDistanceKm).toStringAsFixed(1)} km.'),
                                    style: AscentTextStyles.bodySmall.copyWith(
                                      color: const Color(0xFF0096C7),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                );
                              },
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

// ---------------------------------------------------------------------------
// Modern Fitness Activity HUD (Apple Fitness / Strava Style Arc & Metrics)
// ---------------------------------------------------------------------------

class _WalkFitnessHud extends StatelessWidget {
  final WalkTrackingState walkState;
  final double targetDistanceKm;

  const _WalkFitnessHud({
    required this.walkState,
    required this.targetDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentPrimary;
    final isTracking = walkState.status == WalkTrackingStatus.tracking;
    final isPaused = walkState.status == WalkTrackingStatus.paused;
    final isStationary = walkState.isStationary;
    final distanceKm = walkState.distanceMeters / 1000.0;
    final progress = (targetDistanceKm > 0 ? distanceKm / targetDistanceKm : 0.0).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF090D16), const Color(0xFF0F172A)]
              : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 60, bottom: 250, left: 20, right: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. Dynamic Status Indicator Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isTracking
                      ? (isStationary
                          ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.15))
                      : (isPaused
                          ? Colors.amber.withValues(alpha: 0.15)
                          : context.bgSurface.withValues(alpha: 0.8)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isTracking
                        ? (isStationary
                            ? const Color(0xFF0284C7).withValues(alpha: 0.4)
                            : const Color(0xFF10B981).withValues(alpha: 0.5))
                        : (isPaused
                            ? Colors.amber.withValues(alpha: 0.4)
                            : context.divider),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isTracking
                            ? (isStationary ? const Color(0xFF38BDF8) : const Color(0xFF22C55E))
                            : (isPaused ? Colors.amber : context.textMuted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isTracking
                          ? (isStationary
                              ? 'RESTING / STATIONARY · 0.0 KM/H'
                              : 'WALKING · ${walkState.currentSpeedKmh.toStringAsFixed(1)} KM/H')
                          : (isPaused ? 'SESSION PAUSED' : 'READY FOR OUTDOOR WALK'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isTracking
                            ? (isStationary ? const Color(0xFF38BDF8) : const Color(0xFF22C55E))
                            : (isPaused ? Colors.amber : context.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Circular Fitness Progress Ring
              Center(
                child: SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(210, 210),
                        painter: _ActivityRingPainter(
                          progress: progress,
                          trackColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                          progressColor: isStationary ? const Color(0xFF38BDF8) : accent,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            distanceKm.toStringAsFixed(2),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                              letterSpacing: -1.5,
                            ),
                          ),
                          Text(
                            'KILOMETERS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: context.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.bgSurface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              walkState.formattedDuration,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Stat Badges Row: Current Speed, Cadence / Pace, Energy
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _HudStatItem(
                    label: 'SPEED',
                    value: isStationary
                        ? '0.0'
                        : walkState.currentSpeedKmh.toStringAsFixed(1),
                    unit: 'km/h',
                    icon: Icons.speed_rounded,
                  ),
                  _HudStatItem(
                    label: 'PACE',
                    value: walkState.formattedPace,
                    unit: '/km',
                    icon: Icons.timer_outlined,
                  ),
                  _HudStatItem(
                    label: 'CALORIES',
                    value: '${walkState.calories}',
                    unit: 'kcal',
                    icon: Icons.local_fire_department_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudStatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const _HudStatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.bgSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.divider.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: context.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: context.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _ActivityRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 14.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    if (progress > 0.0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}

