import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_input_bar.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:ascent/shared/widgets/ascent_sheet.dart';

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
  _ => 'Clear sky',
};

IconData weatherIconForCode(int code) => switch (code) {
  0 => Icons.wb_sunny_outlined,
  1 || 2 => Icons.cloud_outlined,
  3 => Icons.cloud_outlined,
  45 || 48 => Icons.foggy,
  >= 51 && <= 67 => Icons.water_drop_outlined,
  >= 71 && <= 77 => Icons.ac_unit_outlined,
  >= 80 && <= 82 => Icons.water_drop_outlined,
  >= 95 => Icons.thunderstorm_outlined,
  _ => Icons.wb_sunny_outlined,
};

final homeWeatherProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final lat = prefs.getDouble('weather_lat') ?? 23.2599; // Default Bhopal
  final lon = prefs.getDouble('weather_lon') ?? 77.4126;
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

void showWeatherForecastSheet(BuildContext context) {
  showAscentSheet<void>(
    context: context,
    framed: false,
    builder: (context) =>
        const AscentSheetSurface(child: WeatherForecastSheet()),
  );
}

class HomeWeather extends ConsumerWidget {
  const HomeWeather({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeWeatherProvider);
    final current = state.value?['current'] as Map<String, dynamic>?;
    String city = 'Bhopal';
    try {
      city = ref.watch(sharedPreferencesProvider).getString('weather_city')?.split(',').first ?? 'Bhopal';
    } catch (_) {}

    final String label;
    final IconData iconData;
    if (current != null) {
      final temp = (current['temperature_2m'] as num).round();
      label = '$temp° · $city';
      final code = (current['weather_code'] as num).toInt();
      iconData = weatherIconForCode(code);
    } else if (state.hasError) {
      label = 'Weather unavailable · Retry';
      iconData = Icons.cloud_off_rounded;
    } else if (state.isLoading) {
      label = 'Loading…';
      iconData = Icons.wb_sunny_outlined;
    } else {
      label = '28° · $city';
      iconData = Icons.wb_sunny_outlined;
    }

    return AppChip(
      key: const ValueKey('home_weather'),
      icon: iconData,
      label: label,
      onTap: () {
        HapticFeedback.selectionClick();
        showWeatherForecastSheet(context);
      },
    );
  }
}

class WeatherForecastSheet extends ConsumerStatefulWidget {
  const WeatherForecastSheet({super.key});

  @override
  ConsumerState<WeatherForecastSheet> createState() => _WeatherForecastSheetState();
}

class _WeatherForecastSheetState extends ConsumerState<WeatherForecastSheet> {
  final query = TextEditingController();
  final _scrollController = ScrollController();
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
    _scrollController.dispose();
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
    final c = context.c;
    final weather = ref.watch(homeWeatherProvider);
    final data = weather.value;
    final current = data?['current'] as Map<String, dynamic>?;
    final prefs = ref.watch(sharedPreferencesProvider);
    final currentCity = prefs.getString('weather_city') ?? 'Bhopal, India';
    final code = current != null ? (current['weather_code'] as num).toInt() : 0;
    final conditionIcon = weatherIconForCode(code);
    final conditionText = current != null ? weatherDescription(code) : 'Clear sky';
    final tempVal = current != null ? (current['temperature_2m'] as num).round() : 28;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        thickness: 4.0,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 16),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. Title row
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.accentTint,
                      borderRadius: BorderRadius.circular(Rd.iconChip),
                    ),
                    child: Icon(conditionIcon, color: c.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weather & Forecast',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          currentCity,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('close_weather_sheet'),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: c.textSecondary,
                    tooltip: 'Close',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            if (weather.hasError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.alertTint,
                  borderRadius: BorderRadius.circular(Rd.field),
                  border: AppBorder.all(c.alert.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: c.alert, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weather could not load. Check your connection and retry.',
                        style: TextStyle(color: c.alert, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // 3. Current conditions card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(Rd.card),
                border: AppBorder.all(c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$tempVal°C',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              conditionText,
                              style: TextStyle(
                                fontSize: 14,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.surface,
                          border: AppBorder.all(c.border),
                        ),
                        child: Icon(conditionIcon, size: 28, color: c.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Three stat tiles in a row
                  Row(
                    children: [
                      _statTile(
                        context,
                        'Feels',
                        current != null ? '${current['apparent_temperature']}°' : '27.1°',
                        Icons.thermostat_outlined,
                      ),
                      const SizedBox(width: 8),
                      _statTile(
                        context,
                        'Humidity',
                        current != null ? '${current['relative_humidity_2m']}%' : '31%',
                        Icons.water_drop_outlined,
                      ),
                      const SizedBox(width: 8),
                      _statTile(
                        context,
                        'Wind',
                        current != null ? '${current['wind_speed_10m']} km/h' : '7.0 km/h',
                        Icons.air_outlined,
                      ),
                    ],
                  ),

                  // 1 px divider and 3-day forecast rows
                  if (data?['daily']?['time'] != null) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: c.border),
                    const SizedBox(height: 10),
                    for (var i = 0; i < (data!['daily']['time'] as List).length; i++)
                      _forecastRow(
                        context,
                        dateStr: DateFormat('EEE, d MMM').format(
                          DateTime.parse(data['daily']['time'][i]),
                        ),
                        minMaxStr:
                            '${data['daily']['temperature_2m_min'][i]}° – ${data['daily']['temperature_2m_max'][i]}°',
                        rainProb:
                            (data['daily']['precipitation_probability_max'][i] as num).toInt(),
                      ),
                  ] else ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: c.border),
                    const SizedBox(height: 10),
                    _forecastRow(
                      context,
                      dateStr: 'Sun, 15 Nov',
                      minMaxStr: '18.8° – 28.8°',
                      rainProb: 0,
                    ),
                    _forecastRow(
                      context,
                      dateStr: 'Mon, 16 Nov',
                      minMaxStr: '18.4° – 28.8°',
                      rainProb: 0,
                    ),
                    _forecastRow(
                      context,
                      dateStr: 'Tue, 17 Nov',
                      minMaxStr: '18.5° – 28.0°',
                      rainProb: 0,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. "Choose your city"
            Text(
              'Choose your city',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (flag, full, lat, lon) in _quickCities)
                  AppChip(
                    label: flag,
                    isSelected: currentCity == full,
                    onTap: () => _selectCity(full, lat, lon),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // 5. "Or search location"
            Text(
              'Or search location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            AppInputBar(
              controller: query,
              hint: 'Search city or region…',
              leadingIcon: Icons.search,
              onSubmit: search,
            ),

            if (searching) ...[
              const SizedBox(height: 8),
              CupertinoActivityIndicator(color: c.accent),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(color: c.alert, fontSize: 13),
                ),
              ),
            if (cities.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final city in cities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rd.field),
                    onTap: () {
                      final lat = (city['latitude'] as num).toDouble();
                      final lon = (city['longitude'] as num).toDouble();
                      final name = '${city['name']}, ${city['country'] ?? ''}';
                      _selectCity(name, lat, lon);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Rd.field),
                        border: AppBorder.all(c.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 18, color: c.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${city['name']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${city['admin1'] ?? ''}, ${city['country'] ?? ''}',
                                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: c.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),

            // 6. Refresh forecast data
            Center(
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.invalidate(homeWeatherProvider);
                },
                icon: weather.isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CupertinoActivityIndicator(
                          radius: 7,
                          color: c.accent,
                        ),
                      )
                    : Icon(Icons.refresh_rounded, size: 16, color: c.accent),
                label: Text(
                  'Refresh forecast data',
                  style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _statTile(BuildContext context, String label, String value, IconData icon) {
    final c = context.c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Rd.field),
          border: AppBorder.all(c.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: c.textSecondary),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _forecastRow(
    BuildContext context, {
    required String dateStr,
    required String minMaxStr,
    required int rainProb,
  }) {
    final c = context.c;
    final isRainy = rainProb >= 40;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            dateStr,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const Spacer(),
          Text(
            minMaxStr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isRainy ? c.accentTint : c.surface,
              borderRadius: BorderRadius.circular(Rd.chip),
              border: Border.all(color: isRainy ? c.accent : c.border),
            ),
            child: Text(
              'Rain $rainProb%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isRainy ? c.accent : c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
