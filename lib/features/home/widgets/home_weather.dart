import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (query.text.trim().length < 2) {
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
          'name': query.text.trim(),
          'count': '5',
          'language': 'en',
        }),
      );
      if (!mounted || id != requestId) return;
      setState(() {
        cities = result['results'] as List? ?? [];
        if (cities.isEmpty) error = 'No cities found. Try a nearby city.';
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weather',
            style: HomeType.title.copyWith(color: design.primaryText),
          ),
          if (current != null) ...[
            const SizedBox(height: 12),
            Text(
              prefs.getString('weather_city') ?? '',
              style: HomeType.section,
            ),
            Text(
              '${(current['temperature_2m'] as num).round()}°C',
              style: HomeType.metric.copyWith(color: design.primaryText),
            ),
            Text(
              weatherDescription((current['weather_code'] as num).toInt()),
              style: HomeType.section,
            ),
            const SizedBox(height: 12),
            Text(
              'Feels like ${current['apparent_temperature']}° · Humidity ${current['relative_humidity_2m']}%\nWind ${current['wind_speed_10m']} km/h',
              style: HomeType.supporting,
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < (data!['daily']['time'] as List).length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${DateFormat('EEE, d MMM').format(DateTime.parse(data['daily']['time'][i]))}  ·  ${data['daily']['temperature_2m_min'][i]}–${data['daily']['temperature_2m_max'][i]}°  ·  Rain ${data['daily']['precipitation_probability_max'][i]}%',
                  style: HomeType.supporting,
                ),
              ),
            Text(
              'Updated ${current['time'].toString().replaceFirst('T', ' ')} · Local time',
              style: HomeType.supporting,
            ),
          ],
          if (weather.isLoading && !weather.hasError)
            const LinearProgressIndicator(),
          if (weather.hasError)
            const Text(
              'Weather could not load. Check your connection and retry.',
            ),
          TextButton.icon(
            onPressed: () => ref.invalidate(homeWeatherProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh weather'),
          ),
          const Divider(),
          const Text('Choose your city'),
          const SizedBox(height: 8),
          TextField(
            controller: query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              labelText: 'City name',
              suffixIcon: IconButton(
                tooltip: 'Search cities',
                onPressed: searching ? null : search,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          if (searching) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          for (final city in cities)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${city['name']}'),
              subtitle: Text(
                '${city['admin1'] ?? ''}, ${city['country'] ?? ''}',
              ),
              onTap: () async {
                await prefs.setDouble(
                  'weather_lat',
                  (city['latitude'] as num).toDouble(),
                );
                await prefs.setDouble(
                  'weather_lon',
                  (city['longitude'] as num).toDouble(),
                );
                await prefs.setString(
                  'weather_city',
                  '${city['name']}, ${city['country'] ?? ''}',
                );
                if (!mounted) return;
                ref.invalidate(homeWeatherProvider);
                setState(() => cities = []);
              },
            ),
          const SizedBox(height: 12),
          Text(
            'Forecast by Open-Meteo · City coordinates are used to fetch outdoor weather.',
            style: HomeType.supporting.copyWith(color: design.secondaryText),
          ),
        ],
      ),
    );
  }
}
