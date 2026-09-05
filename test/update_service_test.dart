import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/services/update_service.dart';

void main() {
  group('UpdateService version comparisons', () {
    test('isVersionStringNewer correctly detects newer, older, and equal versions', () {
      // Newer
      expect(UpdateService.isVersionStringNewer('2026.9.5', '2026.9.4'), isTrue);
      expect(UpdateService.isVersionStringNewer('2026.9.5', '2026.9.1'), isTrue);
      expect(UpdateService.isVersionStringNewer('2026.10.1', '2026.9.5'), isTrue);
      expect(UpdateService.isVersionStringNewer('2027.1.1', '2026.9.5'), isTrue);
      expect(UpdateService.isVersionStringNewer('v2026.9.5', '2026.9.4'), isTrue);

      // Older
      expect(UpdateService.isVersionStringNewer('2026.9.1', '2026.9.5'), isFalse);
      expect(UpdateService.isVersionStringNewer('2026.9.4', '2026.9.5'), isFalse);
      expect(UpdateService.isVersionStringNewer('2026.8.28', '2026.9.5'), isFalse);
      expect(UpdateService.isVersionStringNewer('v2026.9.1', 'v2026.9.5'), isFalse);

      // Equal
      expect(UpdateService.isVersionStringNewer('2026.9.5', '2026.9.5'), isFalse);
      expect(UpdateService.isVersionStringNewer('2026.9.5+2126090501', '2026.9.5'), isFalse);
      expect(UpdateService.isVersionStringNewer('v2026.9.5', '2026.9.5'), isFalse);
    });

    test('isUpdateAvailable evaluates versionCode primarily and version string as fallback', () {
      // Remote is older versionCode -> must NOT be available (e.g. 26.9.1 bug)
      expect(
        UpdateService.isUpdateAvailable(
          remoteCode: 2126090101,
          localCode: 2126090501,
          remoteVersion: '2026.9.1',
          localVersion: '2026.9.5',
        ),
        isFalse,
      );

      // Remote is newer versionCode -> MUST be available
      expect(
        UpdateService.isUpdateAvailable(
          remoteCode: 2126090601,
          localCode: 2126090501,
          remoteVersion: '2026.9.6',
          localVersion: '2026.9.5',
        ),
        isTrue,
      );

      // Equal versionCode and version name -> NOT available
      expect(
        UpdateService.isUpdateAvailable(
          remoteCode: 2126090501,
          localCode: 2126090501,
          remoteVersion: '2026.9.5',
          localVersion: '2026.9.5',
        ),
        isFalse,
      );

      // Missing or zero local versionCode -> fallback to string comparison
      expect(
        UpdateService.isUpdateAvailable(
          remoteCode: 2126090101,
          localCode: 0,
          remoteVersion: '2026.9.1',
          localVersion: '2026.9.5',
        ),
        isFalse,
      );

      expect(
        UpdateService.isUpdateAvailable(
          remoteCode: 2126090601,
          localCode: 0,
          remoteVersion: '2026.9.6',
          localVersion: '2026.9.5',
        ),
        isTrue,
      );

      // Same version string (e.g. 2026.9.5) but newer versionCode -> MUST be available
      expect(
        UpdateService.isUpdateAvailable(
          remoteCode: 2126090505,
          localCode: 2126090504,
          remoteVersion: '2026.9.5',
          localVersion: '2026.9.5',
        ),
        isTrue,
      );

      // forceCheck = true with different versionCode -> returns true
      expect(
        UpdateService.isUpdateAvailable(
          remoteCode: 2126090504,
          localCode: 2126090505,
          remoteVersion: '2026.9.5',
          localVersion: '2026.9.5',
          forceCheck: true,
        ),
        isTrue,
      );

      // forceCheck = true with identical version and versionCode -> returns false
      expect(
        UpdateService.isUpdateAvailable(
          remoteCode: 2126090505,
          localCode: 2126090505,
          remoteVersion: '2026.9.5',
          localVersion: '2026.9.5',
          forceCheck: true,
        ),
        isFalse,
      );
    });
  });
}
