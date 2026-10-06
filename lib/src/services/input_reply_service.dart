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
        if (defaultValue.isNotEmpty) 'value': defaultValue,
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
    double? xRatio,
    double? yRatio,
    int? count,
    String? viewId,
    String? text,
    String? desc,
    String? package,
    String? app,
    String? param,
    bool clearParam = false,
    double? seconds,
    String? direction,
    int? dx,
    int? dy,
    String? key,
    int? duration,
  }) {
    return InputReplyStep(
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      xRatio: xRatio ?? this.xRatio,
      yRatio: yRatio ?? this.yRatio,
      count: count ?? this.count,
      viewId: viewId ?? this.viewId,
      text: text ?? this.text,
      desc: desc ?? this.desc,
      package: package ?? this.package,
      app: app ?? this.app,
      param: clearParam ? null : (param ?? this.param),
      seconds: seconds ?? this.seconds,
      direction: direction ?? this.direction,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      key: key ?? this.key,
      duration: duration ?? this.duration,
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
  final String mode; // 'touch_sensor', 'elements', 'hybrid'
  final List<InputReplyParam> parameters;
  final List<InputReplyStep> steps;

  const InputReplyMacro({
    this.format = 'input-reply-agent-v1',
    required this.name,
    required this.createdAt,
    this.screen = const [1080, 2400],
    this.targetPackage = '',
    this.mode = 'touch_sensor',
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
      mode: (json['mode'] as String?) == 'elements' ? 'elements' : 'touch_sensor',
      parameters: params,
      steps: steps,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'name': name,
        'created_at': createdAt,
        'screen': screen,
        'mode': mode,
        if (targetPackage.isNotEmpty) 'target_package': targetPackage,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  static final RegExp paramRegex = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,39}$');

  int get actionStepCount => steps.where((s) => s.type != 'wait').length;

  List<InputReplyStep> get typingSteps =>
      steps.where((s) => s.type == 'type' && (s.text?.isNotEmpty ?? false)).toList();

  bool hasParameter(String name) => parameters.any((p) => p.name == name);

  InputReplyParam? getParam(String name) {
    for (final p in parameters) {
      if (p.name == name) return p;
    }
    return null;
  }

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

  /// Turns typed text matching [value] into a named parameter [name].
  /// Matches original `input-reply` macro parameterization:
  /// - Splits the typed string if [value] is a substring so only the matched
  ///   part becomes parameterized.
  /// - Throws [ArgumentError] if [name] is invalid or already declared.
  /// - Throws [ArgumentError] if [value] was never typed in this macro.
  InputReplyMacro parameterize({
    required String name,
    required String value,
    String description = '',
  }) {
    final cleanName = name.trim();
    if (!paramRegex.hasMatch(cleanName)) {
      throw ArgumentError(
        'Invalid parameter name "$cleanName". Must start with a letter/underscore and contain up to 40 alphanumeric characters.',
      );
    }
    if (value.isEmpty) {
      throw ArgumentError('Parameter "$cleanName" requires the example text that was typed.');
    }
    if (parameters.any((p) => p.name == cleanName)) {
      throw ArgumentError('Duplicate parameter: "$cleanName" already exists on this macro.');
    }

    final newSteps = <InputReplyStep>[];
    bool found = false;

    for (final step in steps) {
      if (step.type != 'type' || step.param != null || step.text == null || !step.text!.contains(value)) {
        newSteps.add(step);
        continue;
      }

      found = true;
      final text = step.text!;
      int start = 0;
      int matchIndex;
      while ((matchIndex = text.indexOf(value, start)) != -1) {
        if (matchIndex > start) {
          final prefix = text.substring(start, matchIndex);
          newSteps.add(step.copyWith(text: prefix, param: null));
        }
        newSteps.add(step.copyWith(text: value, param: cleanName));
        start = matchIndex + value.length;
      }
      if (start < text.length) {
        final suffix = text.substring(start);
        newSteps.add(step.copyWith(text: suffix, param: null));
      }
    }

    if (!found) {
      throw ArgumentError('The text "$value" for parameter "$cleanName" was never typed in this macro.');
    }

    final newParam = InputReplyParam(
      name: cleanName,
      description: description.trim(),
      defaultValue: value,
    );

    final newParams = [...parameters, newParam];
    return copyWith(parameters: newParams, steps: newSteps);
  }

  /// Removes a parameter by [name], unlinks it from typing steps, and merges adjacent plain type steps.
  InputReplyMacro removeParameter(String name) {
    final newParams = parameters.where((p) => p.name != name).toList();
    final updatedSteps = <InputReplyStep>[];

    for (final step in steps) {
      if (step.type == 'type' && step.param == name) {
        updatedSteps.add(step.copyWith(clearParam: true));
      } else {
        updatedSteps.add(step);
      }
    }

    // Merge adjacent unparameterized type steps if they target the same viewId/package
    final mergedSteps = <InputReplyStep>[];
    for (final step in updatedSteps) {
      if (mergedSteps.isNotEmpty &&
          step.type == 'type' &&
          step.param == null &&
          mergedSteps.last.type == 'type' &&
          mergedSteps.last.param == null &&
          (mergedSteps.last.viewId ?? '') == (step.viewId ?? '') &&
          (mergedSteps.last.package ?? '') == (step.package ?? '')) {
        final prev = mergedSteps.removeLast();
        mergedSteps.add(prev.copyWith(text: (prev.text ?? '') + (step.text ?? '')));
      } else {
        mergedSteps.add(step);
      }
    }

    return copyWith(parameters: newParams, steps: mergedSteps);
  }

  /// Resolves macro steps by substituting runtime parameter [values].
  /// Matches original input-reply:
  /// - Parameters provided in [values] replace step.text for steps with step.param.
  /// - Omitted parameters keep the original example text typed when the macro was made.
  /// - Also supports template interpolation like $param and ${param} in text.
  /// - If [mergeAdjacentTypeSteps] is true (default true), merges consecutive
  ///   type steps targeting the same field into a single text step.
  List<InputReplyStep> resolve(
    Map<String, dynamic> values, {
    bool mergeAdjacentTypeSteps = true,
  }) {
    final resolved = <InputReplyStep>[];

    for (final step in steps) {
      if (step.type != 'type') {
        resolved.add(step);
        continue;
      }

      String text = step.text ?? '';
      if (step.param != null && values.containsKey(step.param!)) {
        final val = values[step.param!];
        if (val != null) {
          text = val.toString();
        }
      }

      // Also perform template interpolation if values are provided
      for (final entry in values.entries) {
        final k = entry.key;
        final v = entry.value?.toString() ?? '';
        if (k.isNotEmpty && (text.contains('\$$k') || text.contains('\${$k}'))) {
          text = text.replaceAll('\${$k}', v).replaceAll('\$$k', v);
        }
      }

      resolved.add(step.copyWith(text: text));
    }

    if (!mergeAdjacentTypeSteps) return resolved;

    final combined = <InputReplyStep>[];
    for (final step in resolved) {
      if (combined.isNotEmpty &&
          step.type == 'type' &&
          combined.last.type == 'type' &&
          combined.last.viewId == step.viewId &&
          combined.last.package == step.package) {
        final prev = combined.removeLast();
        combined.add(prev.copyWith(text: (prev.text ?? '') + (step.text ?? '')));
      } else {
        combined.add(step);
      }
    }

    return combined;
  }

  InputReplyMacro copyWith({
    String? name,
    String? targetPackage,
    String? mode,
    List<InputReplyParam>? parameters,
    List<InputReplyStep>? steps,
  }) {
    return InputReplyMacro(
      format: format,
      name: name ?? this.name,
      createdAt: createdAt,
      screen: screen,
      targetPackage: targetPackage ?? this.targetPackage,
      mode: mode ?? this.mode,
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
  Future<bool> startRecording({
    required String name,
    String? targetPackage,
    String mode = 'touch_sensor',
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('startRecording', {
        'name': name,
        'targetPackage': targetPackage,
        'mode': mode,
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

  /// Add a parameter to a macro by turning typed text into a variable, then persists it.
  Future<InputReplyMacro> addParameter({
    required InputReplyMacro macro,
    required String name,
    required String value,
    String description = '',
  }) async {
    final updated = macro.parameterize(
      name: name,
      value: value,
      description: description,
    );
    await saveRecording(updated);
    return updated;
  }

  /// Remove a parameter from a macro by name, then persists it.
  Future<InputReplyMacro> removeParameter({
    required InputReplyMacro macro,
    required String name,
  }) async {
    final updated = macro.removeParameter(name);
    await saveRecording(updated);
    return updated;
  }

  /// Updates execution mode ('touch_sensor', 'elements', 'hybrid') and persists it.
  Future<InputReplyMacro> updateMacroMode({
    required InputReplyMacro macro,
    required String mode,
  }) async {
    final updated = macro.copyWith(mode: mode);
    await saveRecording(updated);
    return updated;
  }

  /// Play a macro with runtime parameters, speed multiplier, repeat count, and mode.
  Future<bool> playMacro(
    InputReplyMacro macro, {
    Map<String, dynamic>? params,
    double speed = 1.0,
    int repeatCount = 1,
    String? mode,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('[InputReplyService] Replay requested on non-Android platform: ${macro.name}');
      return false;
    }
    try {
      final runtime = params ?? {};
      final resolvedSteps = macro.resolve(runtime);
      final resolvedMacro = macro.copyWith(
        steps: resolvedSteps,
        mode: mode ?? macro.mode,
      );

      final res = await _channel.invokeMethod<bool>('playMacro', {
        'macro': resolvedMacro.toJson(),
        'params': runtime,
        'speed': speed,
        'repeatCount': repeatCount,
        'mode': mode ?? macro.mode,
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
