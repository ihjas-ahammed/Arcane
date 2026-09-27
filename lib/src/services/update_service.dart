import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:missions/src/models/update_model.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const MethodChannel _native = MethodChannel('arcane/update');

  static const List<String> _updateMetadataUrls = [
    'https://raw.githubusercontent.com/ihjas-ahammed/Arcane/revive2/builds/update_info.json',
    'https://raw.githubusercontent.com/ihjas-ahammed/Arcane/main/builds/update_info.json',
  ];

  static const String fallbackChangelogUrl =
      'https://raw.githubusercontent.com/ihjas-ahammed/Arcane/revive2/builds/latest.md';

  /// Fetches the local app version info
  Future<PackageInfo> getLocalPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (e) {
      debugPrint('[UpdateService] Failed to get PackageInfo: $e');
      return PackageInfo(
        appName: 'Arcane',
        packageName: 'me.ihjas.missions',
        version: '2026.9.16',
        buildNumber: '2126091604',
      );
    }
  }

  /// Compares two version strings (e.g. "2026.9.5" vs "2026.9.1").
  /// Returns true ONLY if remoteVer is strictly newer than localVer.
  static bool isVersionStringNewer(String remoteVer, String localVer) {
    final cleanRemote = remoteVer.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final cleanLocal = localVer.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;

    final remoteParts = cleanRemote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final localParts = cleanLocal.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLen = remoteParts.length > localParts.length ? remoteParts.length : localParts.length;
    for (int i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final l = i < localParts.length ? localParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }
    return false;
  }

  /// Evaluates whether a remote release is strictly newer than the currently installed build.
  /// An update is available ONLY if remote build is strictly greater than local build.
  static bool isUpdateAvailable({
    required int remoteCode,
    required int localCode,
    required String remoteVersion,
    required String localVersion,
    bool forceCheck = false,
  }) {
    if (remoteCode > 0 && localCode > 0) {
      if (remoteCode > localCode) return true;
      if (remoteCode < localCode) return false;
      return isVersionStringNewer(remoteVersion, localVersion);
    }
    return isVersionStringNewer(remoteVersion, localVersion);
  }

  /// Fetches the latest changelog markdown from remote endpoints or fallback
  Future<String> getLatestChangelog() async {
    final client = http.Client();
    try {
      for (final url in _updateMetadataUrls) {
        try {
          final uri = Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}');
          final response = await client.get(
            uri,
            headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          ).timeout(const Duration(seconds: 6));

          if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
            final json = jsonDecode(response.body) as Map<String, dynamic>;
            final md = json['changelog_markdown'] as String?;
            if (md != null && md.trim().isNotEmpty) return md;
            final clUrl = json['changelog_url'] as String? ?? fallbackChangelogUrl;
            final clUri = Uri.parse('$clUrl?t=${DateTime.now().millisecondsSinceEpoch}');
            final clResponse = await client.get(
              clUri,
              headers: {'Cache-Control': 'no-cache'},
            ).timeout(const Duration(seconds: 6));
            if (clResponse.statusCode == 200 && clResponse.body.trim().isNotEmpty) {
              return clResponse.body;
            }
          }
        } catch (_) {}
      }

      // Try direct fallback changelog URL
      try {
        final clUri = Uri.parse('$fallbackChangelogUrl?t=${DateTime.now().millisecondsSinceEpoch}');
        final clResponse = await client.get(
          clUri,
          headers: {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 6));
        if (clResponse.statusCode == 200 && clResponse.body.trim().isNotEmpty) {
          return clResponse.body;
        }
      } catch (_) {}
    } finally {
      client.close();
    }

    return '''# ⚡ Arcane System Upgrade
### 🎯 Build Enhancements & Tactical Upgrades
- Mobile touch drag & drop stability optimizations.
- Dynamic auto-scrolling during plan reorganization.
- Collapsible checkpoints dropdown panel.
- Strict version superiority and build update detection.
- Complete dark & light theme tactical parity across all views and homescreen widgets.''';
  }

  /// Returns true if running in a debug (Flutter) build.
  /// Both release and debug APKs are signed with the same key, so this relies
  /// on Flutter runtime compile-time environment flags (kDebugMode / !kReleaseMode).
  static bool get isDebugBuild => kDebugMode || !kReleaseMode;

  /// Checks whether an update is available on GitHub
  Future<UpdateModel?> checkForUpdate({bool forceCheck = false}) async {
    if (isDebugBuild) {
      debugPrint('[UpdateService] Debug build detected (isDebugBuild=true). Skipping update check.');
      return null;
    }

    final packageInfo = await getLocalPackageInfo();
    final localBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

    debugPrint('[UpdateService] Current installed build: $localBuildNumber (v${packageInfo.version})');

    Map<String, dynamic>? metadataJson;
    String? resolvedChangelogUrl;

    final client = http.Client();
    try {
      for (final url in _updateMetadataUrls) {
        try {
          final uri = Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}');
          final response = await client.get(
            uri,
            headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
            metadataJson = jsonDecode(response.body) as Map<String, dynamic>;
            resolvedChangelogUrl = metadataJson['changelog_url'] as String? ?? fallbackChangelogUrl;
            break;
          }
        } catch (e) {
          debugPrint('[UpdateService] Failed to fetch metadata from $url: $e');
        }
      }

      if (metadataJson == null) {
        debugPrint('[UpdateService] Could not reach update endpoints.');
        return null;
      }

      final remoteVersionCode = metadataJson['version_code'] as int? ?? 0;
      debugPrint('[UpdateService] Remote version code: $remoteVersionCode');

      // Fetch changelog markdown
      String? changelogMarkdown = metadataJson['changelog_markdown'] as String?;
      if (changelogMarkdown == null || changelogMarkdown.trim().isEmpty) {
        if (resolvedChangelogUrl != null && resolvedChangelogUrl.isNotEmpty) {
          try {
            final clUri = Uri.parse('$resolvedChangelogUrl?t=${DateTime.now().millisecondsSinceEpoch}');
            final clResponse = await client.get(
              clUri,
              headers: {'Cache-Control': 'no-cache'},
            ).timeout(const Duration(seconds: 8));

            if (clResponse.statusCode == 200) {
              changelogMarkdown = clResponse.body;
            }
          } catch (e) {
            debugPrint('[UpdateService] Failed to fetch changelog markdown: $e');
          }
        }
      }

      final updateModel = UpdateModel.fromJson(metadataJson, changelogMarkdown: changelogMarkdown);

      final isNewer = isUpdateAvailable(
        remoteCode: remoteVersionCode,
        localCode: localBuildNumber,
        remoteVersion: updateModel.versionName,
        localVersion: packageInfo.version,
        forceCheck: forceCheck,
      );

      debugPrint(
        '[UpdateService] Installed: v${packageInfo.version} (#$localBuildNumber), '
        'Remote: v${updateModel.versionName} (#$remoteVersionCode) -> isNewer: $isNewer (forceCheck: $forceCheck)',
      );

      if (isNewer) {
        // The metadata can be committed before CI has finished building the APK it points
        // to. Only announce the update once that exact APK is actually downloadable.
        final apkUrl = await resolveApkUrl(updateModel);
        if (!await _isDownloadable(client, apkUrl, updateModel.versionCode)) {
          debugPrint('[UpdateService] APK for #$remoteVersionCode not published yet: $apkUrl');
          return null;
        }
        // Proactively clean older versions from cache
        await clearOldApks(updateModel.versionedApkFilename);
        return updateModel;
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// Picks the split APK matching this device's ABI (falls back to `apk_url`).
  Future<String> resolveApkUrl(UpdateModel update) async {
    if (update.apkArchUrls.isNotEmpty && Platform.isAndroid) {
      try {
        final abis = await _native.invokeListMethod<String>('supportedAbis') ?? const <String>[];
        for (final abi in abis) {
          final url = update.apkArchUrls[abi];
          if (url != null && url.isNotEmpty) return url;
        }
      } catch (_) {}
    }
    return update.apkUrl;
  }

  /// Cache-busting query so the raw.githubusercontent CDN never serves a previous file.
  static Uri _bust(String url, int versionCode) {
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: {...uri.queryParameters, 'v': '$versionCode'});
  }

  Future<bool> _isDownloadable(http.Client client, String url, int versionCode) async {
    if (url.isEmpty) return false;
    try {
      final res = await client.head(_bust(url, versionCode)).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      // Network hiccup on HEAD only: don't hide a real update, the download reports errors itself.
      return true;
    }
  }

  /// Resolves the local directory for APK downloads
  Future<Directory> _getUpdateDir() async {
    Directory baseDir;
    try {
      if (Platform.isAndroid) {
        // Use external storage directory (maps to context.getExternalFilesDir(null))
        // or application support directory (maps to context.getFilesDir())
        // which match OpenFilex's pathRequiresPermission check without requiring MANAGE_EXTERNAL_STORAGE.
        baseDir = (await getExternalStorageDirectory()) ?? (await getApplicationSupportDirectory());
      } else {
        baseDir = await getApplicationSupportDirectory();
      }
    } catch (_) {
      try {
        baseDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        baseDir = await getTemporaryDirectory();
      }
    }

    final updateDir = Directory('${baseDir.path}/updates');
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }
    return updateDir;
  }

  /// Checks if a valid APK for this specific update is already cached locally
  Future<File?> getCachedApk(UpdateModel update) async {
    try {
      final dir = await _getUpdateDir();
      final filename = update.versionedApkFilename;
      final file = File('${dir.path}/$filename');
      if (await file.exists()) {
        final length = await file.length();
        if (length > 1024 * 1024) {
          return file;
        } else {
          // Corrupt or truncated file, remove it
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Error checking cached APK: $e');
    }
    return null;
  }

  /// Removes outdated APK files to reclaim storage
  Future<void> clearOldApks([String? currentApkFilename]) async {
    try {
      final dir = await _getUpdateDir();
      if (await dir.exists()) {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final name = entity.path.split(Platform.pathSeparator).last;
            if (name.endsWith('.apk') || name.endsWith('.apk.download') || name.endsWith('.download')) {
              if (currentApkFilename == null || name != currentApkFilename) {
                try {
                  entity.deleteSync();
                } catch (_) {}
              }
            }
          }
        }
      }
      // Also clean legacy apk_cache folder if present
      try {
        final extCacheDirs = await getExternalCacheDirectories();
        if (extCacheDirs != null && extCacheDirs.isNotEmpty) {
          final legacyDir = Directory('${extCacheDirs.first.path}/apk_cache');
          if (await legacyDir.exists()) {
            await legacyDir.delete(recursive: true);
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[UpdateService] Error cleaning old APKs: $e');
    }
  }

  /// Downloads the APK with real-time stream progress
  Future<File> downloadApk(
    UpdateModel update, {
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    final dir = await _getUpdateDir();
    final filename = update.versionedApkFilename;
    final targetFile = File('${dir.path}/$filename');
    final tempFile = File('${dir.path}/$filename.download');

    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }

    final downloadUrl = await resolveApkUrl(update);
    if (downloadUrl.isEmpty) {
      throw Exception('Update download URL is empty in update metadata');
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', _bust(downloadUrl, update.versionCode));
      request.headers['Cache-Control'] = 'no-cache';
      final response = await client.send(request);

      if (response.statusCode == 404) {
        throw Exception('Build #${update.versionCode} is still being published by CI. Try again in a few minutes.');
      }
      if (response.statusCode != 200) {
        throw Exception('Download failed with HTTP status ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = tempFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
        onProgress(progress, receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();

      if (await tempFile.length() < 1024 * 1024) {
        throw Exception('Downloaded APK is corrupt or too small (< 1MB)');
      }

      // Android rejects an APK that isn't newer than the installed app, so verify first.
      final archiveCode = await apkVersionCode(tempFile.path);
      if (archiveCode > 0 && update.versionCode > 0 && archiveCode < update.versionCode) {
        throw Exception(
          'The server returned an older build (#$archiveCode instead of #${update.versionCode}). '
          'The new build is still propagating. Try again in a few minutes.',
        );
      }

      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      await tempFile.rename(targetFile.path);

      // Clean all older cached APKs from previous versions
      await clearOldApks(filename);

      return targetFile;
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Version code inside a downloaded APK (-1 when unreadable / off-Android).
  Future<int> apkVersionCode(String path) async {
    if (!Platform.isAndroid) return -1;
    try {
      return await _native.invokeMethod<int>('archiveVersionCode', {'path': path}) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// Opens the system installer for [filePath]. Returns null on success, otherwise a message
  /// saying exactly what to do next.
  Future<String?> installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 'The downloaded update file is missing. Tap download again.';
      }

      if (Platform.isAndroid) {
        final allowed = await _native.invokeMethod<bool>('canInstallPackages') ?? true;
        if (!allowed) {
          await _native.invokeMethod<bool>('openInstallPermission');
          return 'Allow "Install unknown apps" for Arcane in the screen that just opened, then tap Install again.';
        }
      }

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('[UpdateService] OpenFilex result: ${result.type} - ${result.message}');
      switch (result.type) {
        case ResultType.done:
          return null;
        case ResultType.permissionDenied:
          if (Platform.isAndroid) await _native.invokeMethod<bool>('openInstallPermission');
          return 'Allow "Install unknown apps" for Arcane, then tap Install again.';
        case ResultType.noAppToOpen:
          return 'No package installer is available on this device.';
        default:
          return 'Could not open the installer: ${result.message}';
      }
    } catch (e) {
      debugPrint('[UpdateService] Failed to launch installer: $e');
      return 'Could not open the installer: $e';
    }
  }
}
