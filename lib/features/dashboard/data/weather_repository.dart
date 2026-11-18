// lib/features/dashboard/data/weather_repository.dart
//
// Open-Meteo (https://open-meteo.com) -- free, no API key required,
// no account signup -- the one weather provider that fits this
// project's established "don't require a credential just for a demo"
// discipline (same reasoning already applied to FCM/Vision SafeSearch
// failing open without credentials). A plain Dio instance, not the
// app's authenticated ApiClient: this is a public third-party API,
// not our own backend, so it needs neither the JWT bearer interceptor
// nor our backend's base URL.
//
// Fixed to Naga City's coordinates (13.62, 123.19 -- Wikipedia/
// PhilAtlas/latlong.net cluster here within a few hundred meters of
// each other) rather than the device's live GPS location: this whole
// app is already scoped to Naga City (UW's own stated locale), so a
// per-user location permission just for a dashboard weather chip
// would be a new runtime permission for something that doesn't need
// per-user precision.
import 'package:dio/dio.dart';
import '../domain/weather_snapshot.dart';

class WeatherRepository {
  WeatherRepository() : _dio = Dio();
  final Dio _dio;

  static const _lat = 13.62;
  static const _lon = 123.19;

  Future<WeatherSnapshot?> getCurrentWeather() async {
    try {
      final response = await _dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': _lat,
          'longitude': _lon,
          'current': 'temperature_2m,weather_code',
          'timezone': 'Asia/Manila',
        },
        options: Options(
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8)),
      );
      final current = response.data['current'];
      if (current == null) return null;
      return WeatherSnapshot.fromOpenMeteo(
        temperatureC: (current['temperature_2m'] as num).toDouble(),
        weatherCode: current['weather_code'] as int,
      );
    } catch (_) {
      // A dashboard weather chip is a nice-to-have, never a reason to
      // break the home screen -- same "fails open/silent" discipline
      // as every other optional external dependency in this app.
      return null;
    }
  }
}
