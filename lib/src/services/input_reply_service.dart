import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents a variable parameter in an [InputReplyMacro] that can be
/// substituted at runtime before replay (e.g. search query, recipient name).
class InputReplyParam {
  final String name;
  final String description;
  final String defaultValue;

  const InputReplyParam({
    required this.name,
    this.description = '',
    this.defaultValue = '',
  });

  factory InputReplyParam.fromJson(Map<String, dynamic> json) {
    return InputReplyParam(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      defaultValue: (json['default'] ?? json['value'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description.isNotEmpty) 'description': description,
        if (defaultValue.isNotEmpty) 'default': defaultValue,
      };
}

/// Represents an atomic action step recorded across the device.
class InputReplyStep {
  final String type; // click, long_click, type, wait, launch, scroll, key
  final double? x;
  final double? y;
  final double? xRatio;
  final double? yRatio;
  final int count;
  final String? viewId;
  final String? text;
  final String? desc;
  final String? package;
  final String? app;
  final String? param; // parameter key to substitute for text
  final double? seconds;
  final String? direction;
  final int? dx;
  final int? dy;
  final String? key;
  final int? duration;

  const InputReplyStep({
    required this.type,
    this.x,
    this.y,
    this.xRatio,
    this.yRatio,
    this.count = 1,
    this.viewId,
    this.text,
    this.desc,
    this.package,
    this.app,
    this.param,
    this.seconds,
    this.direction,
    this.dx,
    this.dy,
    this.key,
    this.duration,
  });

  factory InputReplyStep.fromJson(Map<String, dynamic> json) {
    return InputReplyStep(
      type: json['type'] as String? ?? 'click',
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      xRatio: (json['xRatio'] as num?)?.toDouble(),
      yRatio: (json['yRatio'] as num?)?.toDouble(),
      count: (json['count'] as num?)?.toInt() ?? 1,
      viewId: json['viewId'] as String?,
      text: json['text'] as String?,
      desc: json['desc'] as String?,
      package: json['package'] as String?,
      app: json['app'] as String?,
      param: json['param'] as String?,
      seconds: (json['seconds'] as num?)?.toDouble(),
      direction: json['direction'] as String?,
      dx: (json['dx'] as num?)?.toInt(),
      dy: (json['dy'] as num?)?.toInt(),
      key: (json['keys'] ?? json['key']) as String?,
      duration: (json['duration'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (x != null) map['x'] = x;
    if (y != null) map['y'] = y;
    if (xRatio != null) map['xRatio'] = xRatio;
    if (yRatio != null) map['yRatio'] = yRatio;
    if (count > 1) map['count'] = count;
    if (viewId != null && viewId!.isNotEmpty) map['viewId'] = viewId;
    if (text != null) map['text'] = text;
    if (desc != null && desc!.isNotEmpty) map['desc'] = desc;
    if (package != null && package!.isNotEmpty) map['package'] = package;
    if (app != null && app!.isNotEmpty) map['app'] = app;
    if (param != null && param!.isNotEmpty) map['param'] = param;
    if (seconds != null) map['seconds'] = seconds;
    if (direction != null && direction!.isNotEmpty) map['direction'] = direction;
    if (dx != null) map['dx'] = dx;
    if (dy != null) map['dy'] = dy;
    if (key != null && key!.isNotEmpty) map['key'] = key;
    if (duration != null) map['duration'] = duration;
    return map;
  }

  InputReplyStep copyWith({
    String? type,
    double? x,
    double? y,
    String? text,
    String? param,
    double? seconds,
    String? viewId,
    String? desc,
  }) {
    return InputReplyStep(
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      xRatio: xRatio,
      yRatio: yRatio,
      count: count,
      viewId: viewId ?? this.viewId,
      text: text ?? this.text,
      desc: desc ?? this.desc,
      package: package,
      app: app,
      param: param ?? this.param,
      seconds: seconds ?? this.seconds,
      direction: direction,
      dx: dx,
      dy: dy,
      key: key,
      duration: duration,
    );
  }
}

/// Macro model compatible with `input-reply-agent-v1`.
class InputReplyMacro {
  final String format;
  final String name;
  final String createdAt;
  final List<int> screen;
  final String targetPackage;
  final List<InputReplyParam> parameters;
  final List<InputReplyStep> steps;

  const InputReplyMacro({
    this.format = 'input-reply-agent-v1',
    required this.name,
    required this.createdAt,
    this.screen = const [1080, 2400],
    this.targetPackage = '',
    this.parameters = const [],
    this.steps = const [],
  });

  factory InputReplyMacro.fromJson(Map<String, dynamic> json) {
    final rawParams = (json['parameters'] as List<dynamic>?) ?? [];
    final params = rawParams
        .whereType<Map>()
        .map((p) => InputReplyParam.fromJson(Map<String, dynamic>.from(p)))
        .toList();

    final rawSteps = (json['steps'] as List<dynamic>?) ?? [];
    final steps = rawSteps
        .whereType<Map>()
        .map((s) => InputReplyStep.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    final rawScreen = (json['screen'] as List<dynamic>?) ?? [];
    final screen = rawScreen.whereType<num>().map((e) => e.toInt()).toList();

    return InputReplyMacro(
      format: json['format'] as String? ?? 'input-reply-agent-v1',
      name: json['name'] as String? ?? 'Untitled Macro',
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      screen: screen.length >= 2 ? screen : const [1080, 2400],
      targetPackage: json['target_package'] as String? ?? '',
      parameters: params,
      steps: steps,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'name': name,
        'created_at': createdAt,
        'screen': screen,
        if (targetPackage.isNotEmpty) 'target_package': targetPackage,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  int get actionStepCount => steps.where((s) => s.type != 'wait').length;

  double get estimatedDurationSeconds {
    double total = 0;
    for (final s in steps) {
      if (s.type == 'wait') {
        total += s.seconds ?? 0.5;
      } else {
        total += 0.35;
      }
    }
    return total;
  }

  InputReplyMacro copyWith({
    String? name,
    List<InputReplyParam>? parameters,
    List<InputReplyStep>? steps,
  }) {
    return InputReplyMacro(
      format: format,
      name: name ?? this.name,
      createdAt: createdAt,
      screen: screen,
      targetPackage: targetPackage,
      parameters: parameters ?? this.parameters,
      steps: steps ?? this.steps,
    );
  }
}

/// Service managing device-wide input recording, macro storage, and autonomous replay.
class InputReplyService {
  static const MethodChannel _channel = MethodChannel('me.ihjas.arcane/input_reply');

  static final InputReplyService instance = InputReplyService._();
  InputReplyService._();

  /// Check whether the Accessibility Service required for recording & replaying is enabled.
  Future<bool> checkAccessibility() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('checkAccessibility');
      return res ?? false;
    } catch (e) {
      debugPrint('[InputReplyService] checkAccessibility error: $e');
      return false;
    }
  }

  /// Open Android Accessibility Settings to let user grant Launcher Takeover / Input Reply permissions.
  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('[InputReplyService] openAccessibilitySettings error: $e');
    }
  }

  /// Start whole-device recording. The floating tactical HUD will appear over all apps.
  Future<bool> startRecording({required String name, String? targetPackage}) async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('startRecording', {
        'name': name,
        'targetPackage': targetPackage,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[InputReplyService] startRecording error: $e');
      return false;
    }
  }

  /// Stop current recording and return the saved macro.
  Future<InputReplyMacro?> stopRecording() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<dynamic>('stopRecording');
      if (res is Map) {
        return InputReplyMacro.fromJson(Map<String, dynamic>.from(res));
      }
      return null;
    } catch (e) {
      debugPrint('[InputReplyService] stopRecording error: $e');
      return null;
    }
  }

  /// Cancel current recording without saving.
  Future<bool> cancelRecording() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('cancelRecording');
      return res ?? true;
    } catch (e) {
      debugPrint('[InputReplyService] cancelRecording error: $e');
      return false;
    }
  }

  /// Query if a recording session is actively running.
  Future<bool> isRecording() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isRecording');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Query if a replay session is currently executing on device.
  Future<bool> isReplaying() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isReplaying');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Play a macro with runtime parameters, speed multiplier, and repeat count.
  Future<bool> playMacro(
    InputReplyMacro macro, {
    Map<String, dynamic>? params,
    double speed = 1.0,
    int repeatCount = 1,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('[InputReplyService] Replay requested on non-Android platform: ${macro.name}');
      return false;
    }
    try {
      final res = await _channel.invokeMethod<bool>('playMacro', {
        'macro': macro.toJson(),
        'params': params ?? {},
        'speed': speed,
        'repeatCount': repeatCount,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[InputReplyService] playMacro error: $e');
      return false;
    }
  }

  /// Abort an ongoing replay immediately.
  Future<bool> stopReplay() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('stopReplay');
      return res ?? true;
    } catch (e) {
      debugPrint('[InputReplyService] stopReplay error: $e');
      return false;
    }
  }

  /// List all saved macros on device (and desktop ~/.local/share/input-reply if on Linux).
  Future<List<InputReplyMacro>> listRecordings() async {
    final list = <InputReplyMacro>[];

    // Android storage via native bridge
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<List<dynamic>>('listRecordings');
        if (res != null) {
          for (final item in res) {
            if (item is Map) {
              list.add(InputReplyMacro.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      } catch (e) {
        debugPrint('[InputReplyService] listRecordings error: $e');
      }
    }

    // Linux desktop fallback: ~/.local/share/input-reply/recordings
    if (Platform.isLinux) {
      try {
        final home = Platform.environment['HOME'] ?? '';
        final desktopDir = Directory('$home/.local/share/input-reply/recordings');
        if (desktopDir.existsSync()) {
          final files = desktopDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
          for (final file in files) {
            try {
              final content = file.readAsStringSync();
              final map = jsonDecode(content) as Map<String, dynamic>;
              list.add(InputReplyMacro.fromJson(map));
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('[InputReplyService] Desktop recordings load error: $e');
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Save or update a macro.
  Future<bool> saveRecording(InputReplyMacro macro) async {
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('saveRecording', {
          'name': macro.name,
          'macro': macro.toJson(),
        });
        return res ?? false;
      } catch (e) {
        debugPrint('[InputReplyService] saveRecording error: $e');
        return false;
      }
    } else if (Platform.isLinux) {
      try {
        final home = Platform.environment['HOME'] ?? '';
        final desktopDir = Directory('$home/.local/share/input-reply/recordings');
        if (!desktopDir.existsSync()) desktopDir.createSync(recursive: true);
        final file = File('${desktopDir.path}/${macro.name}.json');
        file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(macro.toJson()));
        return true;
      } catch (e) {
        debugPrint('[InputReplyService] Desktop save error: $e');
        return false;
      }
    }
    return false;
  }

  /// Delete a macro by name.
  Future<bool> deleteRecording(String name) async {
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('deleteRecording', {'name': name});
        return res ?? false;
      } catch (e) {
        debugPrint('[InputReplyService] deleteRecording error: $e');
        return false;
      }
    } else if (Platform.isLinux) {
      try {
        final home = Platform.environment['HOME'] ?? '';
        final file = File('$home/.local/share/input-reply/recordings/$name.json');
        if (file.existsSync()) {
          file.deleteSync();
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
