// test/features/dashboard/weather_snapshot_test.dart
//
// Pins the WMO weather-code mapping down exactly -- real published
// codes (https://open-meteo.com/en/docs), not invented ones.
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/features/dashboard/domain/weather_snapshot.dart';

void main() {
  group('WeatherSnapshot.fromOpenMeteo', () {
    test('code 0 is clear-sky "Sunny"', () {
      final w =
          WeatherSnapshot.fromOpenMeteo(temperatureC: 31.2, weatherCode: 0);
      expect(w.description, 'Sunny');
      expect(w.icon, '☀️');
      expect(w.temperatureC, 31.2);
    });

    test('code 3 (overcast) is "Cloudy"', () {
      expect(
          WeatherSnapshot.fromOpenMeteo(temperatureC: 28, weatherCode: 3)
              .description,
          'Cloudy');
    });

    test('codes 61-67 (the real rain-intensity range) all map to "Rainy"', () {
      for (final code in [61, 63, 65, 66, 67]) {
        expect(
            WeatherSnapshot.fromOpenMeteo(temperatureC: 26, weatherCode: code)
                .description,
            'Rainy');
      }
    });

    test('codes 95-99 (thunderstorm range) map to "Thunderstorms"', () {
      for (final code in [95, 96, 99]) {
        expect(
            WeatherSnapshot.fromOpenMeteo(temperatureC: 25, weatherCode: code)
                .description,
            'Thunderstorms');
      }
    });

    test('an unrecognized code falls back to a generic label, not a crash', () {
      final w =
          WeatherSnapshot.fromOpenMeteo(temperatureC: 27, weatherCode: 999);
      expect(w.description, isNotEmpty);
    });
  });
}
