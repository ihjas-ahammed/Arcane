import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:missions/src/models/update_model.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const MethodChannel _native = MethodChannel('arcane/update');

  /// Instantaneous zero-cache Firebase Realtime Database update metadata endpoint
  static const String _firebaseRtdbUpdateUrl =
      'https://task-dominion-default-rtdb.asia-southeast1.firebasedatabase.app/app_updates/latest.json';

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

  /// Map of Flutter Gradle plugin ABI offsets added when --split-per-abi is used
  static int abiOffsetFor(String? abi) {
    switch (abi) {
      case 'arm64-v8a':
        return 2000;
      case 'armeabi-v7a':
        return 1000;
      case 'x86_64':
        return 4000;
      case 'x86':
        return 3000;
      default:
        return 0;
    }
  }

  /// Normalizes a version code back to its base version code by removing Flutter's
  /// per-ABI offset (+2000 for arm64-v8a, +1000 for armeabi-v7a, +4000 for x86_64).
  /// Works reliably for Arcane's 10-digit 21YYMMDDxx build code scheme and standard builds.
  static int normalizeVersionCode(int code, {List<String>? abis}) {
    if (code <= 0) return code;

    final candidateOffsets = <int>[];
    if (abis != null) {
      for (final abi in abis) {
        final off = abiOffsetFor(abi);
        if (off > 0 && !candidateOffsets.contains(off)) candidateOffsets.add(off);
      }
    }
    for (final off in [2000, 1000, 4000, 3000]) {
      if (!candidateOffsets.contains(off)) candidateOffsets.add(off);
    }

    for (final offset in candidateOffsets) {
      final stripped = code - offset;
      if (stripped >= 2000000000) {
        final s = stripped.toString();
        if (s.length == 10 && s.startsWith('21')) {
          final mm = int.tryParse(s.substring(4, 6)) ?? 0;
          final dd = int.tryParse(s.substring(6, 8)) ?? 0;
          if (mm >= 1 && mm <= 12 && dd >= 1 && dd <= 31) {
            return stripped;
          }
        }
      }
    }
    return code;
  }

  /// Resolves the device's supported ABIs
  Future<List<String>> getSupportedAbis() async {
    if (!Platform.isAndroid) return const [];
    try {
      return await _native.invokeListMethod<String>('supportedAbis') ?? const <String>[];
    } catch (_) {
      return const [];
    }
  }

  /// Evaluates whether a remote release is strictly newer than the currently installed build.
  /// Seamlessly normalizes per-ABI build numbers (e.g. arm64 +2000 offset) and checks architecture codes.
  static bool isUpdateAvailable({
    required int remoteCode,
    required int localCode,
    required String remoteVersion,
    required String localVersion,
    List<String>? abis,
    Map<String, int>? remoteArchCodes,
    bool forceCheck = false,
  }) {
    // 1. Direct ABI matching if remote provides architecture-specific version codes
    if (abis != null && remoteArchCodes != null && remoteArchCodes.isNotEmpty && localCode > 0) {
      for (final abi in abis) {
        final archRemoteCode = remoteArchCodes[abi];
        if (archRemoteCode != null && archRemoteCode > 0) {
          if (archRemoteCode > localCode) return true;
          if (archRemoteCode < localCode) {
            return isVersionStringNewer(remoteVersion, localVersion);
          }
          return isVersionStringNewer(remoteVersion, localVersion);
        }
      }
    }

    // 2. Normalized base version code comparison (stripping split-per-abi offsets)
    final normLocal = normalizeVersionCode(localCode, abis: abis);
    final normRemote = normalizeVersionCode(remoteCode, abis: abis);

    if (normRemote > 0 && normLocal > 0) {
      if (normRemote > normLocal) return true;
      if (normRemote < normLocal) {
        return isVersionStringNewer(remoteVersion, localVersion);
      }
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
  /// Real-time reactive stream watching for instant updates pushed to Firebase RTDB
  Stream<UpdateModel?> watchAppUpdates() {
    if (kDebugMode) return const Stream.empty();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        return FirebaseDatabase.instance
            .ref('app_updates/latest')
            .onValue
            .asyncMap((event) async {
          final val = event.snapshot.value;
          if (val == null) return null;
          Map<String, dynamic>? json;
          if (val is Map) {
            json = Map<String, dynamic>.from(val);
          } else if (val is String) {
            json = jsonDecode(val) as Map<String, dynamic>?;
          }
          if (json == null || json['version_code'] == null) return null;
          final packageInfo = await getLocalPackageInfo();
          final localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
          final abis = await getSupportedAbis();
          final update = UpdateModel.fromJson(json);
          if (isUpdateAvailable(
            remoteCode: update.versionCode,
            localCode: localBuild,
            remoteVersion: update.versionName,
            localVersion: packageInfo.version,
            abis: abis,
            remoteArchCodes: update.apkArchVersionCodes,
          )) {
            debugPrint('[UpdateService] Instant update detected via Firebase RTDB stream: #${update.versionCode}');
            return update;
          }
          return null;
        }).handleError((e) {
          debugPrint('[UpdateService] watchAppUpdates error: $e');
        });
      } catch (e) {
        debugPrint('[UpdateService] watchAppUpdates setup failed: $e');
      }
    }
    return const Stream.empty();
  }

  /// Checks whether an update is available via Firebase RTDB (zero cache) or GitHub
  Future<UpdateModel?> checkForUpdate({bool forceCheck = false}) async {
    if (kDebugMode) {
      debugPrint('[UpdateService] Debug build: update checks disabled.');
      return null;
    }

    final packageInfo = await getLocalPackageInfo();
    final localBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

    debugPrint('[UpdateService] Current installed build: $localBuildNumber (v${packageInfo.version})');

    Map<String, dynamic>? metadataJson;
    String? resolvedChangelogUrl;

    final client = http.Client();
    try {
      // 1. Primary: Query Firebase Realtime Database for instant zero-cache update metadata
      try {
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          final snap = await FirebaseDatabase.instance
              .ref('app_updates/latest')
              .get()
              .timeout(const Duration(seconds: 4));
          if (snap.exists && snap.value != null) {
            final val = snap.value;
            if (val is Map) {
              metadataJson = Map<String, dynamic>.from(val);
            } else if (val is String) {
              metadataJson = jsonDecode(val) as Map<String, dynamic>?;
            }
            if (metadataJson != null && metadataJson['version_code'] != null) {
              debugPrint('[UpdateService] Retrieved instant update metadata from Firebase RTDB SDK: #${metadataJson['version_code']}');
            }
          }
        }
      } catch (e) {
        debugPrint('[UpdateService] Firebase RTDB SDK fetch error: $e');
      }

      // If SDK didn't return metadata, query Firebase RTDB REST directly (guaranteed zero cache)
      if (metadataJson == null || metadataJson['version_code'] == null) {
        try {
          final rtdbUri = Uri.parse('$_firebaseRtdbUpdateUrl?t=${DateTime.now().millisecondsSinceEpoch}');
          final res = await client.get(
            rtdbUri,
            headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          ).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200 && res.body.trim().isNotEmpty && res.body.trim() != 'null') {
            metadataJson = jsonDecode(res.body) as Map<String, dynamic>?;
            if (metadataJson != null && metadataJson['version_code'] != null) {
              debugPrint('[UpdateService] Retrieved instant update metadata from Firebase RTDB REST: #${metadataJson['version_code']}');
            }
          }
        } catch (e) {
          debugPrint('[UpdateService] Firebase RTDB REST fetch error: $e');
        }
      }

      // 2. Secondary: Fall back to GitHub raw URLs if Firebase is unreachable
      if (metadataJson == null || metadataJson['version_code'] == null) {
        for (final url in _updateMetadataUrls) {
          try {
            final uri = Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}');
            final response = await client.get(
              uri,
              headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
            ).timeout(const Duration(seconds: 8));

            if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
              metadataJson = jsonDecode(response.body) as Map<String, dynamic>;
              resolvedChangelogUrl = metadataJson['changelog_url'] as String? ?? fallbackChangelogUrl;
              break;
            }
          } catch (e) {
            debugPrint('[UpdateService] Failed to fetch metadata from $url: $e');
          }
        }
      }

      if (metadataJson == null || metadataJson['version_code'] == null) {
        debugPrint('[UpdateService] Could not reach update endpoints.');
        return null;
      }

      final remoteVersionCode = (metadataJson['version_code'] as num?)?.toInt() ?? 0;
      resolvedChangelogUrl ??= metadataJson['changelog_url'] as String? ?? fallbackChangelogUrl;
      debugPrint('[UpdateService] Remote version code: $remoteVersionCode');

      // Fetch changelog markdown
      String? changelogMarkdown = metadataJson['changelog_markdown'] as String?;
      if (changelogMarkdown == null || changelogMarkdown.trim().isEmpty) {
        if (resolvedChangelogUrl.isNotEmpty) {
          try {
            final clUri = Uri.parse('$resolvedChangelogUrl?t=${DateTime.now().millisecondsSinceEpoch}');
            final clResponse = await client.get(
              clUri,
              headers: {'Cache-Control': 'no-cache'},
            ).timeout(const Duration(seconds: 6));

            if (clResponse.statusCode == 200) {
              changelogMarkdown = clResponse.body;
            }
          } catch (e) {
            debugPrint('[UpdateService] Failed to fetch changelog markdown: $e');
          }
        }
      }

      final updateModel = UpdateModel.fromJson(metadataJson, changelogMarkdown: changelogMarkdown);

      final abis = await getSupportedAbis();
      final isNewer = isUpdateAvailable(
        remoteCode: remoteVersionCode,
        localCode: localBuildNumber,
        remoteVersion: updateModel.versionName,
        localVersion: packageInfo.version,
        abis: abis,
        remoteArchCodes: updateModel.apkArchVersionCodes,
        forceCheck: forceCheck,
      );

      debugPrint(
        '[UpdateService] Installed: v${packageInfo.version} (#$localBuildNumber), '
        'Remote: v${updateModel.versionName} (#$remoteVersionCode) -> isNewer: $isNewer (forceCheck: $forceCheck)',
      );

      if (isNewer) {
        final downloadUrl = await resolveDownloadUrl(updateModel);
        final reachable = await _isDownloadable(client, downloadUrl, updateModel.versionCode);
        if (!reachable) {
          debugPrint('[UpdateService] Package for #${updateModel.versionCode} preflight warning: $downloadUrl');
        }
        // Proactively clean older versions from cache
        await clearOldPackages(updateModel.versionedPackageFilename);
        return updateModel;
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// Builds candidate URLs for an APK download, trying cache-busted timestamps,
  /// alternative git branches (revive2 / main), and GitHub raw redirect mirrors.
  static List<Uri> buildCandidateUrls(String baseDownloadUrl, [String? filename]) {
    final candidates = <Uri>[];
    final ts = DateTime.now().millisecondsSinceEpoch;

    final parsed = Uri.tryParse(baseDownloadUrl);
    if (parsed != null) {
      // 1. Primary URL with dynamic timestamp cache-buster (bypasses Fastly 404 cache)
      candidates.add(parsed.replace(queryParameters: {...parsed.queryParameters, 't': '$ts'}));
      // 2. Direct clean primary URL
      candidates.add(parsed);
    }

    // 3. Fallbacks for alternate branches (revive2 <-> main)
    if (baseDownloadUrl.contains('/revive2/')) {
      final mainRaw = baseDownloadUrl.replaceAll('/revive2/', '/main/');
      final parsedMain = Uri.tryParse(mainRaw);
      if (parsedMain != null) {
        candidates.add(parsedMain.replace(queryParameters: {...parsedMain.queryParameters, 't': '$ts'}));
        candidates.add(parsedMain);
      }
      final ghRaw = baseDownloadUrl.replaceFirst('raw.githubusercontent.com', 'github.com');
      final parsedGh = Uri.tryParse(ghRaw);
      if (parsedGh != null) candidates.add(parsedGh);
    } else if (baseDownloadUrl.contains('/main/')) {
      final reviveRaw = baseDownloadUrl.replaceAll('/main/', '/revive2/');
      final parsedRevive = Uri.tryParse(reviveRaw);
      if (parsedRevive != null) {
        candidates.add(parsedRevive.replace(queryParameters: {...parsedRevive.queryParameters, 't': '$ts'}));
        candidates.add(parsedRevive);
      }
      final ghRaw = baseDownloadUrl.replaceFirst('raw.githubusercontent.com', 'github.com');
      final parsedGh = Uri.tryParse(ghRaw);
      if (parsedGh != null) candidates.add(parsedGh);
    }

    return candidates;
  }

  /// Picks the download URL matching this device (split APK on Android, tar.gz on Linux).
  Future<String> resolveDownloadUrl(UpdateModel update) async {
    if (!kIsWeb && Platform.isLinux) {
      if (update.linuxArchUrls.containsKey('x86_64')) {
        return update.linuxArchUrls['x86_64']!;
      }
      if (update.linuxUrl != null && update.linuxUrl!.isNotEmpty) {
        return update.linuxUrl!;
      }
      final cleanVersion = update.versionName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      return 'https://raw.githubusercontent.com/ihjas-ahammed/Arcane/revive2/builds/missions-v$cleanVersion-b${update.versionCode}-linux-x86_64.tar.gz';
    }
    return resolveApkUrl(update);
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

  /// Checks reachability of an APK across multiple mirrors without suppressing valid updates
  Future<bool> _isDownloadable(http.Client client, String url, int versionCode) async {
    if (url.isEmpty) return false;
    final filename = url.split('/').last.split('?').first;
    final candidates = buildCandidateUrls(url, filename);
    for (final candidate in candidates) {
      try {
        final res = await client.head(candidate).timeout(const Duration(seconds: 4));
        if (res.statusCode >= 200 && res.statusCode < 400) return true;
        if (res.statusCode == 404) {
          // Range check fallback to handle CDNs that reject HEAD
          final getRes = await client.get(
            candidate,
            headers: {'Range': 'bytes=0-10'},
          ).timeout(const Duration(seconds: 4));
          if ((getRes.statusCode >= 200 && getRes.statusCode < 400) || getRes.statusCode == 206) {
            return true;
          }
        }
      } catch (_) {}
    }
    // Network hiccup: don't hide a genuine update
    return true;
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

  /// Checks if a valid package for this specific update is already cached locally
  Future<File?> getCachedPackage(UpdateModel update) async {
    try {
      final dir = await _getUpdateDir();
      final filename = update.versionedPackageFilename;
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
      debugPrint('[UpdateService] Error checking cached package: $e');
    }
    return null;
  }

  /// Backward-compatible alias for getCachedPackage
  Future<File?> getCachedApk(UpdateModel update) => getCachedPackage(update);

  /// Removes outdated package files to reclaim storage
  Future<void> clearOldPackages([String? currentPackageFilename]) async {
    try {
      final dir = await _getUpdateDir();
      if (await dir.exists()) {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final name = entity.path.split(Platform.pathSeparator).last;
            if (name.endsWith('.apk') ||
                name.endsWith('.apk.download') ||
                name.endsWith('.tar.gz') ||
                name.endsWith('.tar.gz.download') ||
                name.endsWith('.download')) {
              if (currentPackageFilename == null || name != currentPackageFilename) {
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
      debugPrint('[UpdateService] Error cleaning old packages: $e');
    }
  }

  /// Backward-compatible alias for clearOldPackages
  Future<void> clearOldApks([String? currentApkFilename]) => clearOldPackages(currentApkFilename);

  /// Downloads the update package (APK on Android, tar.gz on Linux) with real-time progress
  Future<File> downloadPackage(
    UpdateModel update, {
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    final dir = await _getUpdateDir();
    final filename = update.versionedPackageFilename;
    final targetFile = File('${dir.path}/$filename');
    final tempFile = File('${dir.path}/$filename.download');

    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }

    final downloadUrl = await resolveDownloadUrl(update);
    if (downloadUrl.isEmpty) {
      throw Exception('Update download URL is empty in update metadata');
    }

    final candidateUrls = buildCandidateUrls(downloadUrl, filename);
    final client = http.Client();
    try {
      http.StreamedResponse? response;
      for (final candidate in candidateUrls) {
        try {
          final request = http.Request('GET', candidate);
          request.headers['Cache-Control'] = 'no-cache';
          request.headers['Pragma'] = 'no-cache';
          final resp = await client.send(request);
          if (resp.statusCode == 200) {
            response = resp;
            break;
          }
        } catch (_) {}
      }

      if (response == null || response.statusCode != 200) {
        throw Exception(
          'Build #${update.versionCode} is still propagating across CDN mirrors. '
          'Please tap Download again in a moment.',
        );
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
        throw Exception('Downloaded package is corrupt or too small (< 1MB)');
      }

      if (Platform.isAndroid) {
        // Android rejects an APK that isn't newer than the installed app, so verify first.
        final archiveCode = await apkVersionCode(tempFile.path);
        final normArchive = normalizeVersionCode(archiveCode);
        final normUpdate = normalizeVersionCode(update.versionCode);
        if (normArchive > 0 && normUpdate > 0 && normArchive < normUpdate) {
          throw Exception(
            'The server returned an older build (#$normArchive instead of #$normUpdate). '
            'The new build is still propagating. Try again in a few minutes.',
          );
        }
      }

      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      await tempFile.rename(targetFile.path);

      // Clean all older cached packages from previous versions
      await clearOldPackages(filename);

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

  /// Backward-compatible alias for downloadPackage
  Future<File> downloadApk(
    UpdateModel update, {
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) => downloadPackage(update, onProgress: onProgress);

  /// Version code inside a downloaded APK (-1 when unreadable / off-Android).
  Future<int> apkVersionCode(String path) async {
    if (!Platform.isAndroid) return -1;
    try {
      return await _native.invokeMethod<int>('archiveVersionCode', {'path': path}) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// Installs an update archive on Linux.
  /// Extracts the bundle into temporary staging, creates a detached updater script that
  /// waits for the current process to close, overwrites the bundle directory, and relaunches.
  Future<String?> installLinux(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 'The downloaded update archive is missing. Tap download again.';
      }

      final execPath = Platform.resolvedExecutable;
      final execFile = File(execPath);
      final appDir = execFile.parent;

      final tempDir = await getTemporaryDirectory();
      final stagingDir = Directory(
        '${tempDir.path}/arcane_update_staging_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
      await stagingDir.create(recursive: true);

      // Extract tar.gz into stagingDir
      final tarRes = await Process.run('tar', ['-xzf', filePath, '-C', stagingDir.path]);
      if (tarRes.exitCode != 0) {
        return 'Could not extract update archive: ${tarRes.stderr}';
      }

      // Check if extracted contents are nested in a subfolder or root
      Directory sourceDir = stagingDir;
      final entries = stagingDir.listSync();
      if (entries.length == 1 && entries.first is Directory) {
        sourceDir = entries.first as Directory;
      }

      // Test write permission on appDir
      bool isWritable = false;
      try {
        final testFile = File('${appDir.path}/.arcane_write_test_${DateTime.now().millisecondsSinceEpoch}');
        await testFile.writeAsString('test');
        await testFile.delete();
        isWritable = true;
      } catch (_) {
        isWritable = false;
      }

      final scriptFile = File('${tempDir.path}/arcane_updater.sh');
      final currentPid = pid;

      if (isWritable) {
        final script = '''#!/usr/bin/env bash
OLD_PID=\$1
TARGET_DIR="\$2"
SOURCE_DIR="\$3"
EXE_PATH="\$4"

# Wait for old instance to terminate
for i in {1..50}; do
  if ! kill -0 "\$OLD_PID" 2>/dev/null; then
    break
  fi
  sleep 0.1
done

# Copy new files over existing app bundle
cp -rf "\$SOURCE_DIR"/* "\$TARGET_DIR"/
chmod +x "\$TARGET_DIR/missions"

# Clean up staging directory
rm -rf "\$SOURCE_DIR"

# Relaunch the application
nohup "\$EXE_PATH" >/dev/null 2>&1 &
''';
        await scriptFile.writeAsString(script);
        await Process.run('chmod', ['+x', scriptFile.path]);

        await Process.start(
          'bash',
          [scriptFile.path, currentPid.toString(), appDir.path, sourceDir.path, execPath],
          mode: ProcessStartMode.detached,
        );

        exit(0);
      } else {
        // App is installed in a system directory (e.g. /opt or /usr)
        final script = '''#!/usr/bin/env bash
TARGET_DIR="\$1"
SOURCE_DIR="\$2"
cp -rf "\$SOURCE_DIR"/* "\$TARGET_DIR"/
chmod +x "\$TARGET_DIR/missions"
rm -rf "\$SOURCE_DIR"
''';
        await scriptFile.writeAsString(script);
        await Process.run('chmod', ['+x', scriptFile.path]);

        final res = await Process.run('pkexec', ['bash', scriptFile.path, appDir.path, sourceDir.path]);
        if (res.exitCode != 0) {
          return 'Permission denied updating $appDir (${res.stderr}).';
        }

        await Process.start(execPath, [], mode: ProcessStartMode.detached);
        exit(0);
      }
    } catch (e) {
      debugPrint('[UpdateService] Linux install error: $e');
      return 'Failed to install update: $e';
    }
  }

  /// Installs the downloaded update package on the current platform
  Future<String?> installPackage(String filePath) async {
    if (Platform.isLinux) {
      return installLinux(filePath);
    }
    return installApk(filePath);
  }

  /// Opens the system installer for [filePath]. Returns null on success, otherwise a message
  /// saying exactly what to do next.
  Future<String?> installApk(String filePath) async {
    if (Platform.isLinux) {
      return installLinux(filePath);
    }
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
