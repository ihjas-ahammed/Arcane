import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';

class DataExportService {
  /// Exports a Map to a JSON file.
  /// 
  /// On Web: Triggers a browser download.
  /// On Mobile: Saves to temporary storage and opens the Share sheet.
  Future<void> exportJson(Map<String, dynamic> data, String baseFilename) async {
    final jsonStr = jsonEncode(data);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = '${baseFilename}_$timestamp.json';

    if (kIsWeb) {
      final bytes = utf8.encode(jsonStr);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = filename;
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(jsonStr);
      
      // Use Share Plus to export
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Arcane Database Export',
        text: 'Backup created on $timestamp',
      );
    }
  }

  /// Imports a JSON file and returns the parsed Map.
  /// 
  /// Triggers a file picker dialog.
  Future<Map<String, dynamic>?> importJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true, // Important for Web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content;

        if (kIsWeb) {
          // On web, bytes are available directly
          if (file.bytes != null) {
            content = utf8.decode(file.bytes!);
          } else {
            throw Exception("Failed to read file data on web.");
          }
        } else {
          // On mobile/desktop, read from path
          if (file.path != null) {
            final ioFile = File(file.path!);
            content = await ioFile.readAsString();
          } else {
             throw Exception("File path not available.");
          }
        }

        final dynamic decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          throw Exception("Invalid JSON structure. Root must be a JSON object.");
        }
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }
}