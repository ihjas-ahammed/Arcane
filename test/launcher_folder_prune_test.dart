import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';

void main() {
  group('LauncherService.shouldDissolveAfterPrune', () {
    test('dissolves a folder that lost an item to an uninstall and is left with < 2', () {
      // 2 -> 1 after removing an uninstalled app.
      expect(LauncherService.shouldDissolveAfterPrune(itemsBefore: 2, itemsAfter: 1), isTrue);
      // 1 -> 0: its last app was uninstalled too.
      expect(LauncherService.shouldDissolveAfterPrune(itemsBefore: 1, itemsAfter: 0), isTrue);
    });

    test('does not dissolve a folder that still has >= 2 items after pruning', () {
      expect(LauncherService.shouldDissolveAfterPrune(itemsBefore: 3, itemsAfter: 2), isFalse);
      expect(LauncherService.shouldDissolveAfterPrune(itemsBefore: 2, itemsAfter: 2), isFalse);
    });

    test('leaves alone a folder deliberately created with a single app that this pass did not touch', () {
      // A "New folder" made with one app: nothing was removed this pass (before == after),
      // so it must survive even though it currently has fewer than 2 items.
      expect(LauncherService.shouldDissolveAfterPrune(itemsBefore: 1, itemsAfter: 1), isFalse);
      expect(LauncherService.shouldDissolveAfterPrune(itemsBefore: 0, itemsAfter: 0), isFalse);
    });
  });
}
