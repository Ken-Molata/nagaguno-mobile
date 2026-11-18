// lib/features/dashboard/domain/weather_snapshot.dart
//
// WMO weather-interpretation codes, as returned by Open-Meteo's
// `current.weather_code` field -- a real, published, stable code
// table (https://open-meteo.com/en/docs), not an invented mapping.
// Collapsed to the handful of plain-language conditions relevant to
// a short dashboard chip; codes outside this table fall back to a
// generic label rather than showing nothing.
class WeatherSnapshot {
  const WeatherSnapshot(
      {required this.temperatureC,
      required this.description,
      required this.icon});

  final double temperatureC;
  final String description;
  final String icon; // a single emoji, kept simple -- no icon asset needed

  factory WeatherSnapshot.fromOpenMeteo(
      {required double temperatureC, required int weatherCode}) {
    final (description, icon) = _describe(weatherCode);
    return WeatherSnapshot(
        temperatureC: temperatureC, description: description, icon: icon);
  }

  static (String, String) _describe(int code) {
    if (code == 0) return ('Sunny', '☀️');
    if (code == 1) return ('Mostly Sunny', '🌤️');
    if (code == 2) return ('Partly Cloudy', '⛅');
    if (code == 3) return ('Cloudy', '☁️');
    if (code == 45 || code == 48) return ('Foggy', '🌫️');
    if (code >= 51 && code <= 57) return ('Drizzle', '🌦️');
    if (code >= 61 && code <= 67) return ('Rainy', '🌧️');
    if (code >= 80 && code <= 82) return ('Rain Showers', '🌧️');
    if (code >= 95 && code <= 99) return ('Thunderstorms', '⛈️');
    return ('Clear', '🌤️');
  }
}
