import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/home_design.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/ascent_sheet.dart';

Future<Map<String, dynamic>> weatherJson(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 12));
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw const HttpException('Weather unavailable');
    }
    return jsonDecode(
          await response
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(seconds: 12)),
        )
        as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

String weatherDescription(int code) => switch (code) {
  0 => 'Clear sky',
  1 || 2 => 'Partly cloudy',
  3 => 'Overcast',
  45 || 48 => 'Fog',
  >= 51 && <= 67 => 'Rain',
  >= 71 && <= 77 => 'Snow',
  >= 80 && <= 82 => 'Rain showers',
  85 || 86 => 'Snow showers',
  >= 95 => 'Thunderstorms',
  _ => 'Current conditions',
};

final homeWeatherProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  // Location is explicitly selected in the sheet; no background GPS request.
  final prefs = ref.watch(sharedPreferencesProvider);
  final lat = prefs.getDouble('weather_lat');
  final lon = prefs.getDouble('weather_lon');
  if (lat == null || lon == null) return null;
  final timer = Timer(const Duration(minutes: 15), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return weatherJson(
    Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lon',
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m',
      'daily':
          'temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'forecast_days': '3',
      'timezone': 'auto',
    }),
  );
});

class HomeWeather extends ConsumerWidget {
  const HomeWeather({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeWeatherProvider);
    final current = state.value?['current'] as Map<String, dynamic>?;
    final design = HomeDesign.of(context);
    return TextButton.icon(
      key: const ValueKey('home_weather'),
      style: TextButton.styleFrom(
        foregroundColor: design.action,
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
      icon: Icon(
        current == null
            ? Icons.cloud_outlined
            : (current['weather_code'] as num) < 3
            ? Icons.wb_sunny_outlined
            : Icons.cloud_outlined,
        size: 19,
      ),
      label: Text(
        current != null
            ? '${(current['temperature_2m'] as num).round()}° · ${ref.read(sharedPreferencesProvider).getString('weather_city')?.split(',').first ?? weatherDescription((current['weather_code'] as num).toInt())}'
            : state.hasError
            ? 'Weather unavailable · Retry'
            : state.isLoading
            ? 'Loading weather…'
            : 'Weather · Choose city',
        style: HomeType.supporting,
      ),
      onPressed: () => showAscentSheet(
        context: context,
        builder: (_) => const _WeatherSheet(),
      ),
    );
  }
}

class _WeatherSheet extends ConsumerStatefulWidget {
  const _WeatherSheet();
  @override
  ConsumerState<_WeatherSheet> createState() => _WeatherSheetState();
}

class _WeatherSheetState extends ConsumerState<_WeatherSheet> {
  final query = TextEditingController();
  List<dynamic> cities = [];
  bool searching = false;
  String? error;
  int requestId = 0;

  static const _quickCities = [
    ('🇮🇳 New Delhi', 'New Delhi, India', 28.6139, 77.2090),
    ('🇮🇳 Mumbai', 'Mumbai, India', 19.0760, 72.8777),
    ('🇮🇳 Bengaluru', 'Bengaluru, India', 12.9716, 77.5946),
    ('🇬🇧 London', 'London, United Kingdom', 51.5074, -0.1278),
    ('🇺🇸 New York', 'New York, United States', 40.7128, -74.0060),
    ('🇯🇵 Tokyo', 'Tokyo, Japan', 35.6762, 139.6503),
    ('🇦🇪 Dubai', 'Dubai, United Arab Emirates', 25.2048, 55.2708),
    ('🇸🇬 Singapore', 'Singapore, Singapore', 1.3521, 103.8198),
  ];

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> _selectCity(String cityName, double lat, double lon) async {
    HapticFeedback.selectionClick();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble('weather_lat', lat);
    await prefs.setDouble('weather_lon', lon);
    await prefs.setString('weather_city', cityName);
    if (!mounted) return;
    ref.invalidate(homeWeatherProvider);
    setState(() {
      cities = [];
      query.clear();
      error = null;
    });
  }

  Future<void> search() async {
    final text = query.text.trim();
    if (text.length < 2) {
      setState(() => error = 'Enter at least two letters.');
      return;
    }
    final id = ++requestId;
    setState(() {
      searching = true;
      error = null;
    });
    try {
      final result = await weatherJson(
        Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
          'name': text,
          'count': '6',
          'language': 'en',
        }),
      );
      if (!mounted || id != requestId) return;
      setState(() {
        cities = result['results'] as List? ?? [];
        if (cities.isEmpty) error = 'No cities found for "$text".';
      });
    } catch (_) {
      if (mounted && id == requestId) {
        setState(
          () => error = 'Could not search. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted && id == requestId) setState(() => searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(homeWeatherProvider);
    final data = weather.value;
    final current = data?['current'] as Map<String, dynamic>?;
    final prefs = ref.watch(sharedPreferencesProvider);
    final design = HomeDesign.of(context);
    final currentCity = prefs.getString('weather_city');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: design.action.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.cloud_outlined,
                  color: design.action,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weather & Forecast',
                      style: HomeType.section.copyWith(color: design.primaryText),
                    ),
                    Text(
                      currentCity != null
                          ? currentCity.split(',').first
                          : 'Choose a location',
                      style: HomeType.supporting.copyWith(
                        color: design.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (current != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: design.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: design.separator.withValues(alpha: 0.5),
                  width: 0.9,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(current['temperature_2m'] as num).round()}°C',
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                color: design.primaryText,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              weatherDescription(
                                (current['weather_code'] as num).toInt(),
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: design.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: design.action.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          (current['weather_code'] as num) < 3
                              ? Icons.wb_sunny_rounded
                              : Icons.cloud_rounded,
                          size: 28,
                          color: design.action,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _weatherMetricPill(
                        context,
                        'Feels',
                        '${current['apparent_temperature']}°',
                        Icons.thermostat_rounded,
                      ),
                      const SizedBox(width: 8),
                      _weatherMetricPill(
                        context,
                        'Humidity',
                        '${current['relative_humidity_2m']}%',
                        Icons.water_drop_rounded,
                      ),
                      const SizedBox(width: 8),
                      _weatherMetricPill(
                        context,
                        'Wind',
                        '${current['wind_speed_10m']} km/h',
                        Icons.air_rounded,
                      ),
                    ],
                  ),
                  if (data?['daily']?['time'] != null) ...[
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: design.separator,
                    ),
                    const SizedBox(height: 10),
                    for (
                      var i = 0;
                      i < (data!['daily']['time'] as List).length;
                      i++
                    )
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                DateFormat('EEE, d MMM').format(
                                  DateTime.parse(data['daily']['time'][i]),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: design.secondaryText,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${data['daily']['temperature_2m_min'][i]}° – ${data['daily']['temperature_2m_max'][i]}°',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: design.primaryText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Rain ${data['daily']['precipitation_probability_max'][i]}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: design.action,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (weather.isLoading && !weather.hasError) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],

          Text(
            'Quick choose city',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: design.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (flag, full, lat, lon) in _quickCities)
                InkWell(
                  onTap: () => _selectCity(full, lat, lon),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: currentCity == full
                          ? design.action.withValues(alpha: 0.15)
                          : design.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentCity == full
                            ? design.action
                            : design.separator.withValues(alpha: 0.6),
                        width: currentCity == full ? 1.2 : 0.8,
                      ),
                    ),
                    child: Text(
                      flag,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: currentCity == full
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: currentCity == full
                            ? design.action
                            : design.primaryText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Or search location',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: design.primaryText,
            ),
          ),
          const SizedBox(height: 8),

          // Single-enclosure glass search field
          Container(
            decoration: BoxDecoration(
              color: design.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: design.separator.withValues(alpha: 0.8),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: design.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => search(),
                    style: TextStyle(color: design.primaryText, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search city or region...',
                      hintStyle: TextStyle(
                        color: design.secondaryText,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (query.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() {
                      query.clear();
                      cities = [];
                      error = null;
                    }),
                  ),
                IconButton(
                  tooltip: 'Search cities',
                  onPressed: searching ? null : search,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                ),
              ],
            ),
          ),
          if (searching) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: TextStyle(color: Colors.red.shade400, fontSize: 13),
              ),
            ),
          if (cities.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final city in cities)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () {
                    final lat = (city['latitude'] as num).toDouble();
                    final lon = (city['longitude'] as num).toDouble();
                    final name = '${city['name']}, ${city['country'] ?? ''}';
                    _selectCity(name, lat, lon);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: design.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: design.separator.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: design.action,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${city['name']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: design.primaryText,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${city['admin1'] ?? ''}, ${city['country'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: design.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: design.secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.invalidate(homeWeatherProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh forecast data'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherMetricPill(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final design = HomeDesign.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: design.action.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: design.action),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: design.primaryText,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: design.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
