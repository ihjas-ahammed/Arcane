import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/models/app_state_models.dart';

void main() {
  group('Pristine Bus Transit Network Tests', () {
    test('Default locations and routes have no pre-added intermediate subStops and use Title Case', () {
      final stops = DefaultBusNetwork.stops;
      expect(stops.length, 3);
      expect(stops.map((s) => s.name), containsAll(['S.S College', 'Edavannappara', 'Areekode']));

      final routes = DefaultBusNetwork.getRoutes();
      expect(routes.length, 6);

      for (final r in routes) {
        expect(r.subStops, isEmpty, reason: 'Route ${r.name} should not have pre-added subStops');
      }
    });

    test('formatPlaceName helper properly handles abbreviations and Title Case', () {
      expect(DefaultBusNetwork.formatPlaceName('edavannappara'), 'Edavannappara');
      expect(DefaultBusNetwork.formatPlaceName('AREEKODE'), 'Areekode');
      expect(DefaultBusNetwork.formatPlaceName('s.s college'), 'S.S College');
      expect(DefaultBusNetwork.formatPlaceName('MANJERI'), 'Manjeri');
      expect(DefaultBusNetwork.formatPlaceName('calicut airport'), 'Calicut Airport');
    });

    test('Pristine default schedules match authentic departures with Title Case keys', () {
      final map = DefaultBusNetwork.getDefaultScheduleMap();

      expect(map.containsKey("S.S College"), isTrue);
      expect(map.containsKey("Edavannappara"), isTrue);
      expect(map.containsKey("Areekode"), isTrue);

      // S.S College -> Edavannappara (56 runs)
      final sscToEdv = map["S.S College"]!["Edavannappara"]!;
      expect(sscToEdv.length, 56);
      expect(sscToEdv.first, "06:30 AM");
      expect(sscToEdv.last, "06:35 PM");

      // S.S College -> Areekode (56 runs)
      final sscToArk = map["S.S College"]!["Areekode"]!;
      expect(sscToArk.length, 56);
      expect(sscToArk.first, "07:06 AM");
      expect(sscToArk.last, "07:08 PM");

      // Edavannappara -> S.S College (41 runs)
      final edvToSsc = map["Edavannappara"]!["S.S College"]!;
      expect(edvToSsc.length, 41);
      expect(edvToSsc.first, "08:00 AM");
      expect(edvToSsc.last, "06:30 PM");

      // Derived Edavannappara -> Areekode (+0 offset from EDV -> SSC)
      final edvToArk = map["Edavannappara"]!["Areekode"]!;
      expect(edvToArk.length, 41);
      expect(edvToArk.first, "08:00 AM");

      // Derived Areekode -> S.S College (-2 min offset from SSC -> EDV: 06:30 AM - 2min = 06:28 AM)
      final arkToSsc = map["Areekode"]!["S.S College"]!;
      expect(arkToSsc.length, 56);
      expect(arkToSsc.first, "06:28 AM");

      // Derived Areekode -> Edavannappara (-2 min offset from SSC -> EDV: 06:30 AM - 2min = 06:28 AM)
      final arkToEdv = map["Areekode"]!["Edavannappara"]!;
      expect(arkToEdv.length, 56);
      expect(arkToEdv.first, "06:28 AM");
    });

    test('Auto addition of two-way bidirectional data works on single-direction custom place', () {
      final customMap = <String, Map<String, List<String>>>{
        "Calicut": {
          "Manjeri": ["09:00 AM", "11:30 AM", "03:00 PM"],
        }
      };

      DefaultBusNetwork.calculateAndFillDerivedSchedules(customMap);

      // Verify reverse two-way data was automatically generated
      expect(customMap.containsKey("Manjeri"), isTrue);
      expect(customMap["Manjeri"]!.containsKey("Calicut"), isTrue);
      final reverse = customMap["Manjeri"]!["Calicut"]!;
      expect(reverse.isNotEmpty, isTrue);
      expect(reverse.length, 3);
      expect(reverse.first, "09:30 AM"); // 30 min transit offset
    });

    test('AppSettings preserves lastSelectedBusOrigin and lastSelectedBusDestination focus', () {
      final settings = AppSettings(
        lastSelectedBusOrigin: 'Edavannappara',
        lastSelectedBusDestination: 'Manjeri',
      );

      final json = settings.toJson();
      expect(json['lastSelectedBusOrigin'], 'Edavannappara');
      expect(json['lastSelectedBusDestination'], 'Manjeri');

      final reconstructed = AppSettings.fromJson(json);
      expect(reconstructed.lastSelectedBusOrigin, 'Edavannappara');
      expect(reconstructed.lastSelectedBusDestination, 'Manjeri');
    });
  });
}
