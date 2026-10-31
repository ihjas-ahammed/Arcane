import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/external_ai_briefing_helper.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:path_provider/path_provider.dart';

/// Result of checking one picked briefing JSON file.
class BriefingFileCheck {
  final bool isValid;
  final String message;
  final DateTime? generatedAt;

  const BriefingFileCheck({required this.isValid, required this.message, this.generatedAt});
}

/// Status of one picker slot (today, this week, this month).
enum BriefingSlotStatus { empty, accepted, rejected }

class BriefingFileSlot {
  final BriefingType type;
  final BriefingSlotStatus status;
  final String? fileName;
  final DateTime? generatedAt;
  final String message;

  const BriefingFileSlot({
    required this.type,
    this.status = BriefingSlotStatus.empty,
    this.fileName,
    this.generatedAt,
    this.message = 'No file picked yet.',
  });
}

/// Holds the three briefing file slots. Each pick opens the file picker, checks the JSON is
/// the current offline export for that slot, and copies the matching prompt to the clipboard.
class BriefingFilePickerProvider extends ChangeNotifier {
  /// Slots shown in the picker, in display order.
  static const List<BriefingType> slotTypes = [
    BriefingType.daily,
    BriefingType.weekly,
    BriefingType.monthly,
  ];

  final Map<BriefingType, BriefingFileSlot> _slots = {
    for (final type in slotTypes) type: BriefingFileSlot(type: type),
  };

  bool _isPicking = false;

  BriefingFileSlot slot(BriefingType type) => _slots[type]!;

  bool get isPicking => _isPicking;

  /// Folder under the app documents folder. The Android documents provider (ArcaneExportsProvider)
  /// shows this folder in the system file picker. Keep the two names in sync.
  static const String exportDirName = 'briefing_exports';

  static String exportFileName(BriefingType type) => 'arcane_briefing_${type.name}.json';

  static String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// Writes the latest offline export for each slot into [exportDirName], so the file picker can
  /// offer it. Each file is replaced on every refresh, so it always holds the current data.
  Future<void> refreshOfflineExports(AppProvider app, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    try {
      await ExternalAiBriefingHelper.syncNotificationsFromJournal(app, today);
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/$exportDirName');
      await dir.create(recursive: true);
      for (final type in slotTypes) {
        final data = ExternalAiBriefingHelper.buildExportData(
          provider: app,
          targetDate: today,
          type: type,
        );
        final file = File('${dir.path}/${exportFileName(type)}');
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(data), flush: true);
        await tmp.rename(file.path);
      }
    } catch (e) {
      debugPrint('[BriefingFilePicker] Offline export refresh failed: $e');
    }
  }

  /// Checks one JSON export against the slot type and today's date.
  ///
  /// The file must be the export for [type], its target date must be [now] (today), and it must be
  /// generated on the same calendar day. This makes sure the file holds the latest offline data.
  static BriefingFileCheck checkFile(String raw, BriefingType type, DateTime now) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const BriefingFileCheck(isValid: false, message: 'Not valid JSON. Pick an Arcane briefing export.');
    }
    final meta = decoded is Map ? decoded['meta'] : null;
    if (meta is! Map) {
      return const BriefingFileCheck(isValid: false, message: 'Missing meta block. Pick an Arcane briefing export.');
    }

    final fileType = meta['briefing_type']?.toString() ?? '';
    if (fileType != type.name) {
      return BriefingFileCheck(
        isValid: false,
        message: 'Wrong file: this slot needs a ${type.name} export, not $fileType.',
      );
    }

    final today = _dayKey(now);
    final targetDate = meta['target_date']?.toString() ?? '';
    if (targetDate != today) {
      return BriefingFileCheck(
        isValid: false,
        message: 'Not current: target date is $targetDate, today is $today. Export again.',
      );
    }

    final generatedAt = DateTime.tryParse(meta['generated_at']?.toString() ?? '');
    if (generatedAt == null) {
      return const BriefingFileCheck(isValid: false, message: 'Missing generated time. Export again.');
    }
    if (_dayKey(generatedAt) != today) {
      return BriefingFileCheck(
        isValid: false,
        generatedAt: generatedAt,
        message: 'Stale: generated ${DateFormat('yyyy-MM-dd HH:mm').format(generatedAt)}. Export again today.',
      );
    }

    return BriefingFileCheck(
      isValid: true,
      generatedAt: generatedAt,
      message: 'Latest offline data, generated ${DateFormat('HH:mm').format(generatedAt)}.',
    );
  }

  /// Opens the picker for [type]. On an accepted file, copies the matching prompt to the clipboard.
  /// A cancelled pick leaves the slot unchanged.
  Future<void> pickFor({required BriefingType type, required AppProvider app, DateTime? now}) async {
    if (_isPicking) return;
    _isPicking = true;
    notifyListeners();

    final current = slot(type);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final String raw;
      if (picked.bytes != null) {
        raw = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        raw = await File(picked.path!).readAsString();
      } else {
        throw Exception('Could not read the selected file.');
      }

      final today = now ?? DateTime.now();
      final check = checkFile(raw, type, today);
      if (!check.isValid) {
        _slots[type] = BriefingFileSlot(
          type: type,
          status: BriefingSlotStatus.rejected,
          fileName: picked.name,
          generatedAt: check.generatedAt,
          message: check.message,
        );
        return;
      }

      final prompt = ExternalAiBriefingHelper.buildPrompt(
        type: type,
        targetDate: today,
        provider: app,
      );
      await Clipboard.setData(ClipboardData(text: prompt));

      _slots[type] = BriefingFileSlot(
        type: type,
        status: BriefingSlotStatus.accepted,
        fileName: picked.name,
        generatedAt: check.generatedAt,
        message: '${check.message} Prompt copied.',
      );
    } catch (e) {
      _slots[type] = BriefingFileSlot(
        type: type,
        status: BriefingSlotStatus.rejected,
        fileName: current.fileName,
        generatedAt: current.generatedAt,
        message: 'Pick failed: $e',
      );
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }
}
