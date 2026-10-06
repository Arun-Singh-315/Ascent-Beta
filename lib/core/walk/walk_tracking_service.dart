import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';
import '../providers/database_provider.dart';

enum WalkTrackingStatus {
  idle,
  tracking,
  paused,
}

enum GpsSignalQuality {
  searching,
  good,
  low,
  permissionDenied,
  serviceDisabled,
}

class WalkTrackingState {
  final WalkTrackingStatus status;
  final GpsSignalQuality gpsSignal;
  final int durationSeconds;
  final double distanceMeters;
  final double currentSpeedMps;
  final int calories;
  final double? currentLat;
  final double? currentLng;
  final double? accuracyMeters;
  final List<LatLng> routePoints;

  const WalkTrackingState({
    this.status = WalkTrackingStatus.idle,
    this.gpsSignal = GpsSignalQuality.searching,
    this.durationSeconds = 0,
    this.distanceMeters = 0.0,
    this.currentSpeedMps = 0.0,
    this.calories = 0,
    this.currentLat,
    this.currentLng,
    this.accuracyMeters,
    this.routePoints = const [],
  });

  double get distanceKm => distanceMeters / 1000.0;

  double get avgPaceSecondsPerKm {
    if (distanceKm <= 0.05) return 0.0;
    return durationSeconds / distanceKm;
  }

  String get formattedPace {
    final pace = avgPaceSecondsPerKm;
    if (pace <= 0 || pace > 3600) return "--:--";
    final m = pace ~/ 60;
    final s = (pace % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get currentSpeedKmh => currentSpeedMps * 3.6;

  bool get isStationary =>
      status == WalkTrackingStatus.tracking && currentSpeedMps < 0.4;

  bool get isMoving =>
      status == WalkTrackingStatus.tracking && currentSpeedMps >= 0.4;

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  WalkTrackingState copyWith({
    WalkTrackingStatus? status,
    GpsSignalQuality? gpsSignal,
    int? durationSeconds,
    double? distanceMeters,
    double? currentSpeedMps,
    int? calories,
    double? currentLat,
    double? currentLng,
    double? accuracyMeters,
    List<LatLng>? routePoints,
  }) {
    return WalkTrackingState(
      status: status ?? this.status,
      gpsSignal: gpsSignal ?? this.gpsSignal,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentSpeedMps: currentSpeedMps ?? this.currentSpeedMps,
      calories: calories ?? this.calories,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      routePoints: routePoints ?? this.routePoints,
    );
  }
}

class WalkTrackingNotifier extends Notifier<WalkTrackingState> {
  Timer? _timer;
  StreamSubscription<Position>? _positionSub;
  DateTime? _walkStartTime;

  @override
  WalkTrackingState build() {
    ref.onDispose(() {
      _stopTimer();
      _positionSub?.cancel();
    });
    return const WalkTrackingState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == WalkTrackingStatus.tracking) {
        final newDuration = state.durationSeconds + 1;
        // MET formula: calories approx = distanceKm * 65 kcal/km for standard walking
        final newCalories = (state.distanceKm * 65.0).round();
        state = state.copyWith(
          durationSeconds: newDuration,
          calories: newCalories,
        );
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> startWalk() async {
    // Check location service
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(gpsSignal: GpsSignalQuality.serviceDisabled);
      return false;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(gpsSignal: GpsSignalQuality.permissionDenied);
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(gpsSignal: GpsSignalQuality.permissionDenied);
      return false;
    }

    _walkStartTime = DateTime.now();
    state = state.copyWith(
      status: WalkTrackingStatus.tracking,
      gpsSignal: GpsSignalQuality.searching,
      durationSeconds: 0,
      distanceMeters: 0.0,
      calories: 0,
      routePoints: [],
    );

    _startTimer();
    _subscribeGpsStream();
    return true;
  }

  void _subscribeGpsStream() {
    _positionSub?.cancel();

    late final LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Ascent is actively tracking your outdoor walk session",
          notificationTitle: "Walking Session Active",
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      );
    }

    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) => _processPosition(position),
      onError: (err) {
        if (kDebugMode) print('GPS Stream error: $err');
        state = state.copyWith(gpsSignal: GpsSignalQuality.low);
      },
    );
  }

  void _processPosition(Position position) {
    final quality = position.accuracy <= 15
        ? GpsSignalQuality.good
        : (position.accuracy <= 30 ? GpsSignalQuality.low : GpsSignalQuality.searching);

    // Discard highly inaccurate positions
    if (position.accuracy > 35.0) {
      state = state.copyWith(
        currentLat: position.latitude,
        currentLng: position.longitude,
        accuracyMeters: position.accuracy,
        gpsSignal: quality,
      );
      return;
    }

    final newPoint = LatLng(position.latitude, position.longitude);

    if (state.status != WalkTrackingStatus.tracking) {
      state = state.copyWith(
        currentLat: position.latitude,
        currentLng: position.longitude,
        accuracyMeters: position.accuracy,
        gpsSignal: quality,
      );
      return;
    }

    if (state.routePoints.isEmpty) {
      state = state.copyWith(
        currentLat: position.latitude,
        currentLng: position.longitude,
        accuracyMeters: position.accuracy,
        gpsSignal: quality,
        currentSpeedMps: position.speed > 0.4 ? position.speed : 0.0,
        routePoints: [newPoint],
      );
      return;
    }

    final lastPoint = state.routePoints.last;
    final segmentDistance = _calculateHaversineDistance(
      lastPoint.latitude,
      lastPoint.longitude,
      newPoint.latitude,
      newPoint.longitude,
    );

    // Stationary Drift Elimination:
    // When GPS speed is < 0.4 m/s (approx 1.4 km/h) or displacement is tiny (< 2.5m),
    // the user is stationary (stopped). Do NOT increment distance or route points.
    final rawSpeed = position.speed > 0 ? position.speed : 0.0;
    if (rawSpeed < 0.4 || segmentDistance < 2.5) {
      state = state.copyWith(
        currentLat: position.latitude,
        currentLng: position.longitude,
        accuracyMeters: position.accuracy,
        gpsSignal: quality,
        currentSpeedMps: 0.0,
      );
      return;
    }

    // Filter impossible outlier coordinate jumps (> 150m and > 12 m/s -> > 43 km/h)
    if (segmentDistance > 150.0 && rawSpeed > 12.0) {
      return;
    }

    final updatedDistance = state.distanceMeters + segmentDistance;
    final updatedPoints = List<LatLng>.from(state.routePoints)..add(newPoint);

    state = state.copyWith(
      currentLat: position.latitude,
      currentLng: position.longitude,
      accuracyMeters: position.accuracy,
      gpsSignal: quality,
      distanceMeters: updatedDistance,
      currentSpeedMps: rawSpeed,
      calories: (updatedDistance / 1000.0 * 65.0).round(),
      routePoints: updatedPoints,
    );
  }

  void pauseWalk() {
    if (state.status == WalkTrackingStatus.tracking) {
      _stopTimer();
      state = state.copyWith(status: WalkTrackingStatus.paused);
    }
  }

  void resumeWalk() {
    if (state.status == WalkTrackingStatus.paused) {
      _startTimer();
      state = state.copyWith(status: WalkTrackingStatus.tracking);
    }
  }

  Future<int?> finishWalk({String? notes}) async {
    _stopTimer();
    _positionSub?.cancel();

    final walkDao = ref.read(walkDaoProvider);
    final startTime = _walkStartTime ?? DateTime.now().subtract(Duration(seconds: state.durationSeconds));
    final endTime = DateTime.now();

    // Serialize route coordinates
    final coordsList = state.routePoints
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList();
    final jsonString = jsonEncode(coordsList);

    final walkId = await walkDao.insertWalk(
      WalkSessionTableCompanion.insert(
        startTime: startTime,
        endTime: drift.Value(endTime),
        durationSeconds: drift.Value(state.durationSeconds),
        distanceMeters: drift.Value(state.distanceMeters),
        calories: drift.Value(state.calories),
        avgPaceSecondsPerKm: drift.Value(state.avgPaceSecondsPerKm),
        isCompleted: const drift.Value(true),
        routeCoordinatesJson: drift.Value(jsonString),
        notes: drift.Value(notes?.isNotEmpty == true ? notes : null),
      ),
    );

    state = const WalkTrackingState();
    return walkId;
  }

  void discardWalk() {
    _stopTimer();
    _positionSub?.cancel();
    state = const WalkTrackingState();
  }

  /// Calculates Haversine distance between two coordinates in meters.
  static double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }
}

final walkTrackingProvider =
    NotifierProvider<WalkTrackingNotifier, WalkTrackingState>(
  WalkTrackingNotifier.new,
);
