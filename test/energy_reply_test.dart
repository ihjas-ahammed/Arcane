import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:intl/intl.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Energy Check direct reply & wearable auto-reply parsing', () {
    test('User reply "yes" (tired) logs low energy level', () async {
      final provider = AppProvider.forTest();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await provider.handleEnergyReply('yes');

      final logs = provider.getDailyHealthLog(todayStr).energyLogs;
      expect(logs.isNotEmpty, true);
      final latest = logs.last;
      expect(latest.level, 2);
      expect(latest.note?.contains('yes'), true);
    });

    test('User reply "no" (energetic) logs high energy level', () async {
      final provider = AppProvider.forTest();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await provider.handleEnergyReply('no');

      final logs = provider.getDailyHealthLog(todayStr).energyLogs;
      expect(logs.isNotEmpty, true);
      final latest = logs.last;
      expect(latest.level, 8);
      expect(latest.note?.contains('no'), true);
    });

    test('User reply with numeric score logs parsed energy level', () async {
      final provider = AppProvider.forTest();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await provider.handleEnergyReply('Feeling about a 4 right now');

      final logs = provider.getDailyHealthLog(todayStr).energyLogs;
      expect(logs.isNotEmpty, true);
      final latest = logs.last;
      expect(latest.level, 4);
    });
  });
}
