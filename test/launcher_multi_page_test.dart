import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LauncherService.resetForTest();
  });

  group('Launcher Multi-Page Support Tests', () {
    test('LauncherWidgetEntry serializes and deserializes page field correctly', () {
      final entry = LauncherWidgetEntry(
        id: 42,
        provider: 'com.example.app/WidgetProvider',
        label: 'Calendar Widget',
        height: 180,
        page: 2,
      );

      final json = entry.toJson();
      expect(json['id'], equals(42));
      expect(json['page'], equals(2));

      final restored = LauncherWidgetEntry.fromJson(json);
      expect(restored.id, equals(42));
      expect(restored.provider, equals('com.example.app/WidgetProvider'));
      expect(restored.label, equals('Calendar Widget'));
      expect(restored.height, equals(180));
      expect(restored.page, equals(2));

      final moved = restored.copyWith(page: 3);
      expect(moved.page, equals(3));
      expect(moved.id, equals(42));
    });

    test('LauncherService initializes with default single page and migrates legacy home', () async {
      SharedPreferences.setMockInitialValues({
        'launcher_v4_home': ['app_1', 'app_2'],
      });

      final service = LauncherService.instance;
      await service.init();

      expect(service.homePageCount, equals(1));
      expect(service.getPageItems(0), containsAll(['app_1', 'app_2']));
      expect(service.home.value, containsAll(['app_1', 'app_2']));
    });

    test('addHomePage, addToPage, and moving between pages without duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final service = LauncherService.instance;
      await service.init();

      service.saveHomePages([
        ['app_1', 'app_2']
      ]);
      expect(service.homePageCount, equals(1));

      // Add a second page
      final page1Idx = service.addHomePage();
      expect(page1Idx, equals(1));
      expect(service.homePageCount, equals(2));
      expect(service.getPageItems(1), isEmpty);

      // Add app_3 directly to page 1
      service.addToPage(1, 'app_3');
      expect(service.getPageItems(1), equals(['app_3']));

      // Move app_1 from page 0 to page 1
      service.addToPage(1, 'app_1');
      // app_1 must now be in page 1, and no longer in page 0
      expect(service.getPageItems(0), equals(['app_2']));
      expect(service.getPageItems(1), containsAll(['app_3', 'app_1']));

      // Total items across home reflects all unique items
      expect(service.home.value, containsAll(['app_1', 'app_2', 'app_3']));
    });

    test('removeHomePage re-homes remaining items to previous page and decrements widget pages', () async {
      SharedPreferences.setMockInitialValues({});
      final service = LauncherService.instance;
      await service.init();

      service.saveHomePages([
        ['app_0'],
        ['app_1'],
        ['app_2'],
      ]);
      expect(service.homePageCount, equals(3));

      // Remove page 1
      service.removeHomePage(1);
      expect(service.homePageCount, equals(2));
      // Remaining items on page 1 should have been merged into previous page (page 0)
      expect(service.getPageItems(0), containsAll(['app_0', 'app_1']));
      // What was page 2 is now page 1
      expect(service.getPageItems(1), equals(['app_2']));
    });

    test('pruneEmptyTrailingPages cleans up empty pages while preserving content', () async {
      SharedPreferences.setMockInitialValues({});
      final service = LauncherService.instance;
      await service.init();

      service.saveHomePages([
        ['app_0'],
        <String>[],
        <String>[],
      ]);
      expect(service.homePageCount, equals(3));

      service.pruneEmptyTrailingPages();
      expect(service.homePageCount, equals(1));
      expect(service.getPageItems(0), equals(['app_0']));
    });

    test('moveWidgetToPage moves widget and auto-adds pages if target index exceeds count', () async {
      SharedPreferences.setMockInitialValues({
        'launcher_v4_widgets': jsonEncode([
          {'id': 100, 'provider': 'prov', 'label': 'Test Widget', 'height': 120, 'page': 0}
        ]),
      });
      final service = LauncherService.instance;
      await service.init();

      expect(service.widgetsForPage(0).length, equals(1));
      expect(service.widgetsForPage(2).length, equals(0));

      final widget = service.widgets.value.first;
      service.moveWidgetToPage(widget, 2);

      expect(service.homePageCount, greaterThanOrEqualTo(3));
      expect(service.widgetsForPage(0), isEmpty);
      expect(service.widgetsForPage(2).length, equals(1));
      expect(service.widgetsForPage(2).first.id, equals(100));
    });
  });
}
