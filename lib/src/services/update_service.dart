import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:missions/src/models/update_model.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
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
        version: '2026.8.15',
        buildNumber: '2126081501',
      );
    }
  }

  /// Checks whether an update is available on GitHub
  Future<UpdateModel?> checkForUpdate({bool forceCheck = false}) async {
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

      if (remoteVersionCode > localBuildNumber || forceCheck) {
        return updateModel;
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// Resolves the local cache directory for APK downloads
  Future<Directory> _getUpdateDir() async {
    Directory baseDir;
    try {
      if (Platform.isAndroid) {
        baseDir = (await getExternalStorageDirectory()) ?? (await getApplicationDocumentsDirectory());
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      baseDir = await getTemporaryDirectory();
    }

    final updateDir = Directory('${baseDir.path}/updates');
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }
    return updateDir;
  }

  /// Checks if the APK is already cached locally
  Future<File?> getCachedApk(String apkFilename) async {
    try {
      final dir = await _getUpdateDir();
      final file = File('${dir.path}/$apkFilename');
      if (await file.exists() && await file.length() > 500000) {
        return file;
      }
    } catch (e) {
      debugPrint('[UpdateService] Error checking cached APK: $e');
    }
    return null;
  }

  /// Removes outdated APK files to reclaim storage
  Future<void> clearOldApks(String currentApkFilename) async {
    try {
      final dir = await _getUpdateDir();
      if (await dir.exists()) {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File && !entity.path.endsWith(currentApkFilename)) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Error cleaning old APKs: $e');
    }
  }

  /// Downloads the APK with real-time stream progress
  Future<File> downloadApk(
    String url,
    String filename, {
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    final dir = await _getUpdateDir();
    final targetFile = File('${dir.path}/$filename');
    final tempFile = File('${dir.path}/$filename.download');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Cache-Control'] = 'no-cache';
      final response = await client.send(request);

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

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

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

  /// Prompts Android package installer to install the downloaded APK
  Future<bool> installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('APK file not found at path: $filePath');
      }

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('[UpdateService] OpenFilex result: ${result.type} - ${result.message}');
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[UpdateService] Failed to launch installer: $e');
      return false;
    }
  }
}
