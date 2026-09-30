import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/services/input_reply_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class InputReplyScreen extends StatefulWidget {
  const InputReplyScreen({super.key});

  @override
  State<InputReplyScreen> createState() => _InputReplyScreenState();
}

class _InputReplyScreenState extends State<InputReplyScreen> with WidgetsBindingObserver {
  final InputReplyService _service = InputReplyService.instance;
  bool _isLoading = true;
  bool _hasAccessibility = false;
  bool _isRecording = false;
  bool _isReplaying = false;
  List<InputReplyMacro> _macros = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  Future<void> _refreshState() async {
    setState(() => _isLoading = true);
    final access = await _service.checkAccessibility();
    final rec = await _service.isRecording();
    final rep = await _service.isReplaying();
    final macros = await _service.listRecordings();
    if (mounted) {
      setState(() {
        _hasAccessibility = access;
        _isRecording = rec;
        _isReplaying = rep;
        _macros = macros;
        _isLoading = false;
      });
    }
  }

  Future<void> _startRecordingFlow() async {
    if (!_hasAccessibility) {
      _showAccessibilityRequiredDialog();
      return;
    }

    final nameController = TextEditingController(
      text: 'Macro_${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    final appController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JweTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          'RECORD WHOLE DEVICE',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.accentCyan,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A floating HUD controller will be summoned over all apps.\nEvery tap, gesture, typing block, and delay across the system will be recorded.',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMid,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'MACRO NAME',
                  labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.accentCyan),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: appController,
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'TARGET APP PACKAGE (OPTIONAL)',
                  hintText: 'e.g. com.whatsapp, com.android.chrome',
                  hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 11),
                  labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: JweTheme.accentCyan),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 12),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'START REC',
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final name = nameController.text.trim().replaceAll(' ', '_');
      final target = appController.text.trim().isEmpty ? null : appController.text.trim();
      final ok = await _service.startRecording(name: name, targetPackage: target);
      if (ok) {
        setState(() => _isRecording = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: JweTheme.panel,
              content: Text(
                'RECORDING STARTED: Floating HUD is live. Switch to any app. Tap [■ STOP] on HUD when done.',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 11),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _stopRecordingFlow() async {
    final macro = await _service.stopRecording();
    setState(() => _isRecording = false);
    if (macro != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: JweTheme.panel,
            content: Text(
              'MACRO SAVED: ${macro.name} (${macro.actionStepCount} actions)',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 11),
            ),
          ),
        );
      }
      _refreshState();
    }
  }

  void _showAccessibilityRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JweTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Row(
          children: [
            Icon(MdiIcons.shieldAlertOutline, color: JweTheme.accentAmber, size: 20),
            const SizedBox(width: 8),
            Text(
              'PERMISSION REQUIRED',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentAmber,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Input Reply requires the Arcane Accessibility Service enabled in Android Settings to record system-wide taps and dispatch automated gestures across other applications.',
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('DISMISS', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentCyan,
              foregroundColor: JweTheme.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _service.openAccessibilitySettings();
            },
            child: Text(
              'OPEN SETTINGS',
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runMacroFlow(InputReplyMacro macro) async {
    if (!_hasAccessibility) {
      _showAccessibilityRequiredDialog();
      return;
    }

    // Prepare runtime parameter controllers
    final paramControllers = <String, TextEditingController>{};
    for (final p in macro.parameters) {
      paramControllers[p.name] = TextEditingController(text: p.defaultValue);
    }

    double speed = 1.0;
    int repeatCount = 1;

    final shouldRun = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.playCircleOutline, color: JweTheme.accentCyan, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'EXECUTE: ${macro.name}',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.textWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Actions: ${macro.actionStepCount} | Est. Duration: ${macro.estimatedDurationSeconds.toStringAsFixed(1)}s',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                    ),
                    const Divider(height: 20),

                    // Runtime parameters inputs
                    if (macro.parameters.isNotEmpty) ...[
                      Text(
                        'PARAMETER SUBSTITUTIONS',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.accentAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...macro.parameters.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TextField(
                            controller: paramControllers[p.name],
                            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: '\$${p.name}',
                              hintText: p.description.isNotEmpty ? p.description : 'Enter text',
                              labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 11),
                              filled: true,
                              fillColor: JweTheme.bgCanvas,
                              isDense: true,
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: JweTheme.border),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    // Speed & repeat configuration
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SPEED: ${speed}x',
                                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                              ),
                              Slider(
                                value: speed,
                                min: 0.5,
                                max: 2.0,
                                divisions: 6,
                                activeColor: JweTheme.accentCyan,
                                inactiveColor: JweTheme.border,
                                onChanged: (v) => setModalState(() => speed = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REPEAT: ${repeatCount}x',
                                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                              ),
                              Slider(
                                value: repeatCount.toDouble(),
                                min: 1,
                                max: 10,
                                divisions: 9,
                                activeColor: JweTheme.accentAmber,
                                inactiveColor: JweTheme.border,
                                onChanged: (v) => setModalState(() => repeatCount = v.toInt()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: Text(
                          'EXECUTE MACRO',
                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: JweTheme.accentCyan,
                          foregroundColor: JweTheme.onAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldRun == true) {
      final runtimeParams = <String, dynamic>{};
      for (final entry in paramControllers.entries) {
        runtimeParams[entry.key] = entry.value.text;
      }

      setState(() => _isReplaying = true);
      final ok = await _service.playMacro(
        macro,
        params: runtimeParams,
        speed: speed,
        repeatCount: repeatCount,
      );

      if (mounted) {
        setState(() => _isReplaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: JweTheme.panel,
            content: Text(
              ok ? 'MACRO REPLAY FINISHED: ${macro.name}' : 'REPLAY ABORTED OR FAILED',
              style: GoogleFonts.jetBrainsMono(
                color: ok ? JweTheme.accentCyan : JweTheme.accentRed,
                fontSize: 11,
              ),
            ),
          ),
        );
      }
    }
  }

  void _inspectMacroSteps(InputReplyMacro macro) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.timelineTextOutline, color: JweTheme.accentCyan, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'TIMELINE: ${macro.name}',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, size: 18, color: JweTheme.textMuted),
                        tooltip: 'Copy JSON',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                            text: const JsonEncoder.withIndent('  ').convert(macro.toJson()),
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: JweTheme.panel,
                              content: Text(
                                'Macro JSON copied to clipboard',
                                style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 11),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: macro.steps.length,
                      separatorBuilder: (_, __) => Divider(color: JweTheme.lineSoft, height: 1),
                      itemBuilder: (context, i) {
                        final step = macro.steps[i];
                        return _buildStepTile(i + 1, step);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStepTile(int index, InputReplyStep step) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (step.type) {
      case 'wait':
        icon = MdiIcons.timerSand;
        color = JweTheme.textMuted;
        title = 'DELAY';
        subtitle = '${step.seconds?.toStringAsFixed(1) ?? '0.5'}s';
        break;
      case 'launch':
        icon = MdiIcons.rocketLaunchOutline;
        color = JweTheme.accentAmber;
        title = 'LAUNCH APP';
        subtitle = step.app ?? '';
        break;
      case 'click':
        icon = MdiIcons.cursorDefaultClickOutline;
        color = JweTheme.accentCyan;
        title = 'TAP';
        subtitle = step.desc?.isNotEmpty == true
            ? '"${step.desc}"'
            : (step.text?.isNotEmpty == true
                ? '"${step.text}"'
                : 'x: ${step.x?.toInt() ?? 0}, y: ${step.y?.toInt() ?? 0}');
        break;
      case 'long_click':
        icon = MdiIcons.gestureTapHold;
        color = JweTheme.accentAmber;
        title = 'LONG PRESS';
        subtitle = 'x: ${step.x?.toInt() ?? 0}, y: ${step.y?.toInt() ?? 0} (${step.duration ?? 600}ms)';
        break;
      case 'type':
        icon = MdiIcons.keyboardOutline;
        color = JweTheme.accentTeal;
        title = step.param != null ? 'TYPE (\$${step.param})' : 'TYPE TEXT';
        subtitle = '"${step.text ?? ''}"';
        break;
      case 'scroll':
        icon = MdiIcons.gestureSwipe;
        color = JweTheme.accentWarn;
        title = 'SWIPE / SCROLL';
        subtitle = step.direction?.toUpperCase() ?? 'DOWN';
        break;
      case 'key':
        icon = MdiIcons.keyboardBackspace;
        color = JweTheme.accentRed;
        title = 'GLOBAL KEY';
        subtitle = step.key ?? '';
        break;
      default:
        icon = MdiIcons.circleSmall;
        color = JweTheme.textMuted;
        title = step.type.toUpperCase();
        subtitle = '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
            ),
          ),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (step.package?.isNotEmpty == true)
            Text(
              step.package!.split('.').last,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9),
            ),
        ],
      ),
    );
  }

  Future<void> _parameterizeMacroDialog(InputReplyMacro macro) async {
    final typeSteps = <int, InputReplyStep>{};
    for (int i = 0; i < macro.steps.length; i++) {
      if (macro.steps[i].type == 'type' && (macro.steps[i].text?.isNotEmpty ?? false)) {
        typeSteps[i] = macro.steps[i];
      }
    }

    if (typeSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: JweTheme.panel,
          content: Text(
            'This macro has no recorded typing blocks to parameterize.',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 11),
          ),
        ),
      );
      return;
    }

    final paramNameController = TextEditingController(text: 'query');
    final descController = TextEditingController();
    int? selectedStepIndex = typeSteps.keys.first;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: JweTheme.panel,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: JweTheme.border),
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(
                'ADD PARAMETER TO MACRO',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentCyan,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a typing block to transform into a customizable runtime variable:',
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedStepIndex,
                    dropdownColor: JweTheme.panel,
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                    items: typeSteps.entries.map((e) {
                      return DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(
                          'Step ${e.key + 1}: "${e.value.text}"',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedStepIndex = v),
                    decoration: InputDecoration(
                      labelText: 'TARGET TYPING STEP',
                      labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10),
                      border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paramNameController,
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'VARIABLE NAME',
                      hintText: 'e.g. query, message, recipient',
                      labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10),
                      border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'DESCRIPTION / PROMPT',
                      hintText: 'e.g. What to search for in Chrome',
                      labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10),
                      border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JweTheme.accentCyan,
                    foregroundColor: JweTheme.onAccent,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'SAVE PARAMETER',
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true && selectedStepIndex != null) {
      final paramName = paramNameController.text.trim();
      final targetStep = typeSteps[selectedStepIndex]!;
      final newParam = InputReplyParam(
        name: paramName,
        description: descController.text.trim(),
        defaultValue: targetStep.text ?? '',
      );

      final newSteps = List<InputReplyStep>.from(macro.steps);
      newSteps[selectedStepIndex!] = targetStep.copyWith(param: paramName);

      final newParams = List<InputReplyParam>.from(macro.parameters)
        ..removeWhere((p) => p.name == paramName)
        ..add(newParam);

      final updatedMacro = macro.copyWith(parameters: newParams, steps: newSteps);
      await _service.saveRecording(updatedMacro);
      _refreshState();
    }
  }

  Future<void> _deleteMacro(InputReplyMacro macro) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: JweTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          'DELETE MACRO',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.accentRed,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${macro.name}"?',
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteRecording(macro.name);
      _refreshState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMacros = _macros.where((m) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.targetPackage.toLowerCase().contains(q) ||
          m.parameters.any((p) => p.name.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: JweTheme.bgCanvas,
      appBar: AppBar(
        backgroundColor: JweTheme.bgCanvas,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: JweTheme.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'INPUT REPLY // WHOLE-DEVICE REC',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.accentCyan,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: JweTheme.textMuted),
            tooltip: 'Refresh',
            onPressed: _refreshState,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: JweTheme.lineSoft, height: 1.0),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: JweTheme.accentCyan))
          : RefreshIndicator(
              onRefresh: _refreshState,
              color: JweTheme.accentCyan,
              backgroundColor: JweTheme.panel,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Accessibility banner
                  _buildAccessibilityBanner(),
                  const SizedBox(height: 14),

                  // Recorder hero card
                  _buildRecorderHeroCard(),
                  const SizedBox(height: 18),

                  // Macro list section header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SAVED MACROS [${_macros.length}]',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'input-reply-agent-v1',
                        style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search bar
                  if (_macros.length > 3) ...[
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Filter macros or parameters...',
                        hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                        prefixIcon: Icon(Icons.search, size: 16, color: JweTheme.textMuted),
                        filled: true,
                        fillColor: JweTheme.panel,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: JweTheme.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (filteredMacros.isEmpty)
                    _buildEmptyState()
                  else
                    ...filteredMacros.map(_buildMacroCard),
                ],
              ),
            ),
    );
  }

  Widget _buildAccessibilityBanner() {
    if (_hasAccessibility) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: JweTheme.accentCyan.withValues(alpha: 0.08),
          border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(MdiIcons.checkDecagramOutline, size: 16, color: JweTheme.accentCyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ACCESSIBILITY ACTIVE: Whole-device capture & automated execution armed.',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10.5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.accentAmber.withValues(alpha: 0.1),
        border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.alertCircleOutline, size: 18, color: JweTheme.accentAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ACCESSIBILITY SERVICE REQUIRED',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'To record actions across third-party apps and replay them autonomously, Arcane requires Accessibility permission in Android Settings.',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 10.5, height: 1.3),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.settings, size: 14),
              label: Text(
                'ENABLE PERMISSION',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: _service.openAccessibilitySettings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecorderHeroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border.all(color: _isRecording ? JweTheme.accentRed : JweTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? JweTheme.accentRed
                      : (_isReplaying ? JweTheme.accentCyan : JweTheme.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isRecording
                    ? 'SYSTEM RECORDER ACTIVE'
                    : (_isReplaying ? 'REPLAY IN PROGRESS' : 'UNIVERSAL MACRO RECORDER'),
                style: GoogleFonts.jetBrainsMono(
                  color: _isRecording
                      ? JweTheme.accentRed
                      : (_isReplaying ? JweTheme.accentCyan : JweTheme.textWhite),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording
                ? 'Floating HUD controller is active over your device. Switch between any apps, tap, scroll, and type freely. When finished, tap STOP on the HUD or here.'
                : 'Records entire sequences across apps—clicks, long presses, typing blocks, directional scrolls, and delays. Replay anytime with dynamic variable substitution.',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textMid,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_isRecording) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.stop, size: 16),
                    label: Text(
                      'STOP & SAVE REC',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JweTheme.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: _stopRecordingFlow,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.textMuted,
                    side: BorderSide(color: JweTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () async {
                    await _service.cancelRecording();
                    setState(() => _isRecording = false);
                  },
                  child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(fontSize: 11)),
                ),
              ] else if (_isReplaying) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.stop, size: 16),
                    label: Text(
                      'ABORT REPLAY',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JweTheme.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () async {
                      await _service.stopReplay();
                      setState(() => _isReplaying = false);
                    },
                  ),
                ),
              ] else ...[
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(MdiIcons.recordCircleOutline, size: 18),
                    label: Text(
                      'RECORD WHOLE DEVICE',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JweTheme.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: _startRecordingFlow,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(MdiIcons.gestureTap, size: 40, color: JweTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'NO MACROS RECORDED',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap [RECORD WHOLE DEVICE] above to start capturing your actions across Android apps.',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(InputReplyMacro macro) {
    final hasParams = macro.parameters.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border.all(color: JweTheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.codeBraces, size: 16, color: JweTheme.accentCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    macro.name,
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  color: JweTheme.panel,
                  icon: Icon(Icons.more_vert, size: 18, color: JweTheme.textMuted),
                  onSelected: (val) {
                    if (val == 'inspect') _inspectMacroSteps(macro);
                    if (val == 'params') _parameterizeMacroDialog(macro);
                    if (val == 'delete') _deleteMacro(macro);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'inspect',
                      child: Row(
                        children: [
                          Icon(MdiIcons.timelineTextOutline, size: 16, color: JweTheme.accentCyan),
                          const SizedBox(width: 8),
                          Text('Inspect Steps', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: JweTheme.textWhite)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'params',
                      child: Row(
                        children: [
                          Icon(MdiIcons.variable, size: 16, color: JweTheme.accentAmber),
                          const SizedBox(width: 8),
                          Text('Add Parameter', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: JweTheme.textWhite)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: JweTheme.accentRed),
                          const SizedBox(width: 8),
                          Text('Delete', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: JweTheme.accentRed)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${macro.actionStepCount} actions',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11),
                ),
                Text('•', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11)),
                Text(
                  '~${macro.estimatedDurationSeconds.toStringAsFixed(1)}s',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11),
                ),
                if (macro.targetPackage.isNotEmpty) ...[
                  Text('•', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11)),
                  Text(
                    macro.targetPackage.split('.').last,
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 11),
                  ),
                ],
              ],
            ),

            // Parameters tags
            if (hasParams) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: macro.parameters.map((p) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: JweTheme.accentCyan.withValues(alpha: 0.12),
                      border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '\$${p.name}',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: Text(
                      hasParams ? 'CONFIGURE & RUN' : 'RUN MACRO',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JweTheme.accentCyan,
                      foregroundColor: JweTheme.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => _runMacroFlow(macro),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(MdiIcons.timelineTextOutline, size: 18, color: JweTheme.textMid),
                  tooltip: 'Inspect Steps',
                  onPressed: () => _inspectMacroSteps(macro),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
