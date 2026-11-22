import 'dart:async';

import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

import '../../features/home/widgets/home_weather.dart'
    show weatherDescription, weatherJson;
import 'travel_service.dart';

/// Why "I'm here" couldn't read a location.
enum HereProblem { permissionDenied, locationOff, noFix }

/// What one tap of "I'm here" found.
class HereResult {
  const HereResult({
    this.fix,
    this.guesses = const [],
    this.weather,
    this.problem,
  });
  final LocationFix? fix;

  /// Best first. Empty when offline (the visit is named later).
  final List<PlaceGuess> guesses;
  final String? weather;
  final HereProblem? problem;
  bool get found => fix != null;
}

/// Reads where you are once. Tests use a fake.
abstract class HereLocator {
  Future<HereResult> locate();

  /// Names a saved location (used to name offline visits later).
  Future<List<PlaceGuess>> name(LocationFix fix);
}

/// One GPS reading, the phone's own place lookup, and weather if online.
/// Location is asked for only here, the first time it is needed (§1.3),
/// and nothing keeps running afterwards.
class DeviceHereLocator implements HereLocator {
  const DeviceHereLocator();

  @override
  Future<HereResult> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const HereResult(problem: HereProblem.locationOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const HereResult(problem: HereProblem.permissionDenied);
      }
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return const HereResult(problem: HereProblem.noFix);
      final fix = LocationFix(position.latitude, position.longitude);
      final results = await Future.wait([
        name(fix).catchError((_) => <PlaceGuess>[]),
        _weather(fix).catchError((_) => null),
      ]);
      return HereResult(
        fix: fix,
        guesses: results[0] as List<PlaceGuess>,
        weather: results[1] as String?,
      );
    } catch (_) {
      return const HereResult(problem: HereProblem.noFix);
    }
  }

  @override
  Future<List<PlaceGuess>> name(LocationFix fix) async {
    final marks = await geo.Geocoding()
        .placemarkFromCoordinates(fix.lat, fix.lon)
        .timeout(const Duration(seconds: 8));
    return placeGuessesFrom([
      for (final m in marks)
        (
          name: m.name,
          street: m.street,
          subLocality: m.subLocality,
          locality: m.locality,
          area: m.administrativeArea,
        ),
    ]);
  }

  static Future<String?> _weather(LocationFix fix) async {
    final json = await weatherJson(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${fix.lat}',
        'longitude': '${fix.lon}',
        'current': 'temperature_2m,weather_code',
      }),
    ).timeout(const Duration(seconds: 6));
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) return null;
    final t = (current['temperature_2m'] as num?)?.round();
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    return t == null ? null : '$t°, ${weatherDescription(code).toLowerCase()}';
  }
}

typedef RawPlacemark = ({
  String? name,
  String? street,
  String? subLocality,
  String? locality,
  String? area,
});

/// Turns the phone's placemarks into tidy, de-duplicated guesses: a real
/// name first ("Thalassa"), then the neighbourhood, then the street.
List<PlaceGuess> placeGuessesFrom(List<RawPlacemark> marks) {
  String? clean(String? v) {
    final t = v?.trim();
    if (t == null || t.isEmpty) return null;
    // Plus-codes and bare numbers aren't names.
    if (RegExp(r'^[0-9A-Z]{4}\+[0-9A-Z]{2,}').hasMatch(t)) return null;
    if (RegExp(r'^[\d\s,/-]+$').hasMatch(t)) return null;
    return t;
  }

  final out = <PlaceGuess>[];
  final seen = <String>{};
  void add(String? name, String? area) {
    final n = clean(name);
    if (n == null || !seen.add(n.toLowerCase())) return;
    out.add(PlaceGuess(n, area: area, kind: guessPlaceKind(n)));
  }

  for (final m in marks) {
    final areaParts = [
      clean(m.subLocality),
      clean(m.locality),
    ].whereType<String>().toSet().toList();
    final area = areaParts.isEmpty ? clean(m.area) : areaParts.join(', ');
    add(m.name, area);
    add(m.subLocality, clean(m.locality));
    add(m.street, area);
  }
  return out.take(4).toList();
}
