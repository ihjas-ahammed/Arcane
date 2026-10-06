import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_icon.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
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

  Future<void> _startRecordingFlow({int initialTab = 0}) async {
    if (!_hasAccessibility) {
      _showAccessibilityRequiredDialog();
      return;
    }

    if (LauncherService.instance.apps.value.length <= 1) {
      await LauncherService.instance.init();
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _RecordingModeSheet(initialTab: initialTab),
    );

    if (result != null && mounted) {
      final rawName = (result['name'] ?? '').trim().replaceAll(' ', '_');
      final name = rawName.isNotEmpty
          ? rawName
          : 'Macro_${DateTime.now().millisecondsSinceEpoch % 100000}';
      final target = result['targetPackage'];
      final mode = result['mode'] ?? 'touch_sensor';
      final ok = await _service.startRecording(
        name: name,
        targetPackage: target?.isNotEmpty == true ? target : null,
        mode: mode,
      );
      if (ok) {
        setState(() => _isRecording = true);
        if (mounted) {
          final targetInfo = target?.isNotEmpty == true ? ' Target: $target' : '';
          final modeLabel = mode == 'touch_sensor' ? 'TOUCH SENSOR' : (mode == 'elements' ? 'UI ELEMENTS' : 'TOUCH SENSOR');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: JweTheme.panel,
              content: Text(
                'RECORDING STARTED [$modeLabel]: Floating HUD is live.$targetInfo Tap [■ STOP] on HUD when done.',
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
    String executionMode = macro.mode;

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

                    // Execution Mode Selector
                    Text(
                      'EXECUTION MODE',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => executionMode = 'touch_sensor'),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              decoration: BoxDecoration(
                                color: executionMode == 'touch_sensor'
                                    ? JweTheme.accentAmber.withValues(alpha: 0.15)
                                    : JweTheme.bgCanvas,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: executionMode == 'touch_sensor' ? JweTheme.accentAmber : JweTheme.border,
                                  width: executionMode == 'touch_sensor' ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(MdiIcons.gestureTap, size: 14, color: executionMode == 'touch_sensor' ? JweTheme.accentAmber : JweTheme.textMuted),
                                  const SizedBox(height: 2),
                                  Text(
                                    'TOUCH',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: executionMode == 'touch_sensor' ? JweTheme.accentAmber : JweTheme.textMid,
                                    ),
                                  ),
                                  Text(
                                    'Coordinates',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 8, color: JweTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => executionMode = 'elements'),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              decoration: BoxDecoration(
                                color: executionMode == 'elements'
                                    ? const Color(0xFF64B5F6).withValues(alpha: 0.15)
                                    : JweTheme.bgCanvas,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: executionMode == 'elements' ? const Color(0xFF64B5F6) : JweTheme.border,
                                  width: executionMode == 'elements' ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(MdiIcons.xml, size: 14, color: executionMode == 'elements' ? const Color(0xFF64B5F6) : JweTheme.textMuted),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ELEMENTS',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: executionMode == 'elements' ? const Color(0xFF64B5F6) : JweTheme.textMid,
                                    ),
                                  ),
                                  Text(
                                    'UI Nodes',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 8, color: JweTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

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
        mode: executionMode,
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

  void _inspectMacroSteps(InputReplyMacro initialMacro) {
    InputReplyMacro currentMacro = initialMacro;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(MdiIcons.timelineTextOutline, color: JweTheme.accentCyan, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'TIMELINE: ${currentMacro.name}',
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
                                text: const JsonEncoder.withIndent('  ').convert(currentMacro.toJson()),
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
                      const Divider(height: 12),

                      // Parameters section
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: JweTheme.bgCanvas,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: JweTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(MdiIcons.variable, size: 15, color: JweTheme.accentCyan),
                                    const SizedBox(width: 6),
                                    Text(
                                      'PARAMETERS [${currentMacro.parameters.length}]',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.accentCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () async {
                                    final res = await _parameterizeMacroDialog(currentMacro);
                                    if (res != null) {
                                      setModalState(() => currentMacro = res);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.add, size: 14, color: JweTheme.accentAmber),
                                        const SizedBox(width: 2),
                                        Text(
                                          'ADD VARIABLE',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: JweTheme.accentAmber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (currentMacro.parameters.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: currentMacro.parameters.map((p) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: JweTheme.panel,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: JweTheme.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '\$${p.name}',
                                          style: GoogleFonts.jetBrainsMono(
                                            color: JweTheme.accentCyan,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (p.defaultValue.isNotEmpty) ...[
                                          Text(
                                            ' = "${p.defaultValue}"',
                                            style: GoogleFonts.jetBrainsMono(
                                              color: JweTheme.textMid,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () async {
                                            final updated = await _service.removeParameter(
                                              macro: currentMacro,
                                              name: p.name,
                                            );
                                            setModalState(() => currentMacro = updated);
                                            _refreshState();
                                          },
                                          child: Icon(Icons.close, size: 14, color: JweTheme.accentRed),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Text(
                                'No parameters defined yet. Add variables to customize inputs at runtime.',
                                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Step list
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: currentMacro.steps.length,
                          separatorBuilder: (_, __) => Divider(color: JweTheme.lineSoft, height: 1),
                          itemBuilder: (context, i) {
                            final step = currentMacro.steps[i];
                            return _buildStepTile(
                              i + 1,
                              step,
                              currentMacro,
                              onParameterize: () async {
                                final res = await _parameterizeMacroDialog(
                                  currentMacro,
                                  initialText: step.text,
                                );
                                if (res != null) {
                                  setModalState(() => currentMacro = res);
                                }
                              },
                              onUnlinkParam: step.param != null
                                  ? () async {
                                      final updated = await _service.removeParameter(
                                        macro: currentMacro,
                                        name: step.param!,
                                      );
                                      setModalState(() => currentMacro = updated);
                                      _refreshState();
                                    }
                                  : null,
                            );
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
      },
    );
  }

  Widget _buildStepTile(
    int index,
    InputReplyStep step,
    InputReplyMacro macro, {
    VoidCallback? onParameterize,
    VoidCallback? onUnlinkParam,
  }) {
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
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.jetBrainsMono(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (step.type == 'type') ...[
                      const SizedBox(width: 6),
                      if (step.param != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: JweTheme.accentAmber.withValues(alpha: 0.15),
                            border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '\$${step.param}',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentAmber,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (onUnlinkParam != null)
                          IconButton(
                            icon: Icon(Icons.link_off, size: 13, color: JweTheme.accentRed),
                            tooltip: 'Unlink Variable',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(left: 4),
                            onPressed: onUnlinkParam,
                          ),
                      ] else if (onParameterize != null) ...[
                        InkWell(
                          onTap: onParameterize,
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: JweTheme.accentCyan.withValues(alpha: 0.12),
                              border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 10, color: JweTheme.accentCyan),
                                const SizedBox(width: 2),
                                Text(
                                  'VAR',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.accentCyan,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
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

  Future<InputReplyMacro?> _parameterizeMacroDialog(
    InputReplyMacro macro, {
    String? initialText,
  }) async {
    final typeSteps = macro.steps
        .where((s) => s.type == 'type' && (s.text?.isNotEmpty ?? false))
        .toList();

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
      return null;
    }

    final paramNameController = TextEditingController(
      text: 'var_${macro.parameters.length + 1}',
    );
    final valueController = TextEditingController(
      text: initialText ?? typeSteps.first.text ?? '',
    );
    final descController = TextEditingController();
    String? errorMessage;

    final updatedMacro = await showDialog<InputReplyMacro>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final paramName = paramNameController.text.trim();
            final paramValue = valueController.text;
            final isNameValid = InputReplyMacro.paramRegex.hasMatch(paramName);
            final isDuplicate = macro.parameters.any((p) => p.name == paramName);
            final canSave = isNameValid && !isDuplicate && paramValue.isNotEmpty;

            return AlertDialog(
              backgroundColor: JweTheme.panel,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: JweTheme.border),
                borderRadius: BorderRadius.circular(8),
              ),
              title: Row(
                children: [
                  Icon(MdiIcons.variable, size: 18, color: JweTheme.accentCyan),
                  const SizedBox(width: 8),
                  Text(
                    'ADD VARIABLE / PARAMETER',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replace a recorded word or typing block with a runtime variable.',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11),
                    ),
                    const SizedBox(height: 12),

                    // Quick suggestions from typed steps
                    Text(
                      'RECORDED TYPED STRINGS:',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: typeSteps.map((s) => s.text!).toSet().map((txt) {
                        final isSelected = valueController.text == txt;
                        return ChoiceChip(
                          label: Text(
                            txt.length > 20 ? '${txt.substring(0, 18)}...' : txt,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: isSelected ? JweTheme.onAccent : JweTheme.textWhite,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: JweTheme.accentCyan,
                          backgroundColor: JweTheme.bgCanvas,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onSelected: (_) {
                            setDialogState(() {
                              valueController.text = txt;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Value to parameterize
                    TextField(
                      controller: valueController,
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'TEXT / SUBSTRING TO REPLACE',
                        hintText: 'e.g. search query or exact word',
                        labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10),
                        filled: true,
                        fillColor: JweTheme.bgCanvas,
                        isDense: true,
                        border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                      ),
                      onChanged: (_) => setDialogState(() => errorMessage = null),
                    ),
                    const SizedBox(height: 12),

                    // Variable Name
                    TextField(
                      controller: paramNameController,
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'VARIABLE NAME',
                        hintText: 'e.g. query, recipient, title',
                        labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10),
                        errorText: isDuplicate
                            ? 'Variable already exists'
                            : (!isNameValid && paramName.isNotEmpty
                                ? 'Must start with letter/_ (max 40 chars)'
                                : null),
                        errorStyle: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.accentRed),
                        filled: true,
                        fillColor: JweTheme.bgCanvas,
                        isDense: true,
                        border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                      ),
                      onChanged: (_) => setDialogState(() => errorMessage = null),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descController,
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'PROMPT / DESCRIPTION (OPTIONAL)',
                        hintText: 'e.g. What to search for in Chrome',
                        labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10),
                        filled: true,
                        fillColor: JweTheme.bgCanvas,
                        isDense: true,
                        border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                      ),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: GoogleFonts.jetBrainsMono(color: JweTheme.accentRed, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSave ? JweTheme.accentCyan : JweTheme.panel2,
                    foregroundColor: canSave ? JweTheme.onAccent : JweTheme.textMuted,
                  ),
                  onPressed: canSave
                      ? () async {
                          try {
                            final updated = await _service.addParameter(
                              macro: macro,
                              name: paramName,
                              value: paramValue,
                              description: descController.text.trim(),
                            );
                            _refreshState();
                            if (ctx.mounted) {
                              Navigator.pop(ctx, updated);
                            }
                          } on ArgumentError catch (e) {
                            setDialogState(() => errorMessage = e.message.toString());
                          } catch (e) {
                            setDialogState(() => errorMessage = e.toString());
                          }
                        }
                      : null,
                  child: Text(
                    'SAVE VARIABLE',
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    return updatedMacro;
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
                padding: EdgeInsets.fromLTRB(
                  16.0,
                  16.0,
                  16.0,
                  24.0 + MediaQuery.of(context).padding.bottom,
                ),
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
                    icon: Icon(MdiIcons.recordCircleOutline, size: 16),
                    label: Text(
                      'WHOLE DEVICE',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JweTheme.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => _startRecordingFlow(initialTab: 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(MdiIcons.apps, size: 16),
                    label: Text(
                      'START IN APP',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JweTheme.accentAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => _startRecordingFlow(initialTab: 1),
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
            'Tap [WHOLE DEVICE] or [START IN APP] above to start capturing actions across Android apps.',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: Icon(MdiIcons.recordCircleOutline, size: 14),
                label: Text(
                  'WHOLE DEVICE',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JweTheme.accentRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => _startRecordingFlow(initialTab: 0),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(MdiIcons.apps, size: 14),
                label: Text(
                  'START IN APP',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JweTheme.accentAmber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => _startRecordingFlow(initialTab: 1),
              ),
            ],
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
                    if (val == 'mode') _changeMacroModeDialog(macro);
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
                      value: 'mode',
                      child: Row(
                        children: [
                          Icon(MdiIcons.targetVariant, size: 16, color: JweTheme.accentCyan),
                          const SizedBox(width: 8),
                          Text('Change Mode', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: JweTheme.textWhite)),
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
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Mode indicator badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: _modeColor(macro.mode).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: _modeColor(macro.mode).withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: Text(
                    macro.mode == 'elements' ? 'ELEM' : 'TOUCH',
                    style: GoogleFonts.jetBrainsMono(
                      color: _modeColor(macro.mode),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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

  Future<void> _changeMacroModeDialog(InputReplyMacro macro) async {
    String currentMode = macro.mode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.cogRefreshOutline, size: 20, color: JweTheme.accentCyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CHANGE ENGINE MODE: ${macro.name}',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textWhite,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select how Arcane executes clicks and gestures for this macro:',
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  _modeSelectionTile(
                    title: 'Touch (Recommended)',
                    desc: 'Replays your exact taps, swipes and long-presses at the coordinates you pressed. Typing is replayed as text so the keyboard never gets in the way.',
                    modeKey: 'touch_sensor',
                    current: currentMode,
                    icon: MdiIcons.gestureTap,
                    color: JweTheme.accentAmber,
                    onTap: () => setSheetState(() => currentMode = 'touch_sensor'),
                  ),
                  const SizedBox(height: 8),
                  _modeSelectionTile(
                    title: 'UI Elements (Strict Accessibility)',
                    desc: 'Strictly clicks accessibility node IDs, descriptions, and text. Never taps empty coordinates if element is missing.',
                    modeKey: 'elements',
                    current: currentMode,
                    icon: MdiIcons.xml,
                    color: const Color(0xFF64B5F6),
                    onTap: () => setSheetState(() => currentMode = 'elements'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JweTheme.accentCyan,
                        foregroundColor: JweTheme.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => Navigator.pop(ctx, currentMode),
                      child: Text(
                        'APPLY ENGINE MODE',
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null && selected != macro.mode && mounted) {
      await _service.updateMacroMode(macro: macro, mode: selected);
      _refreshState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: JweTheme.panel,
          content: Text(
            'UPDATED MODE TO ${selected.toUpperCase()}',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 11),
          ),
        ),
      );
    }
  }

  Widget _modeSelectionTile({
    required String title,
    required String desc,
    required String modeKey,
    required String current,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = current == modeKey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : JweTheme.bgCanvas,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : JweTheme.border, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: isSelected ? color : JweTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      color: isSelected ? color : JweTheme.textWhite,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 9.5, height: 1.3),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  Color _modeColor(String mode) {
    switch (mode) {
      case 'touch_sensor':
        return JweTheme.accentAmber;
      case 'elements':
        return const Color(0xFF64B5F6);
      default:
        return JweTheme.accentCyan;
    }
  }
}

class _RecordingModeSheet extends StatefulWidget {
  final int initialTab;

  const _RecordingModeSheet({this.initialTab = 0});

  @override
  State<_RecordingModeSheet> createState() => _RecordingModeSheetState();
}

class _RecordingModeSheetState extends State<_RecordingModeSheet> {
  late int _activeTab;
  late final TextEditingController _wholeDeviceNameCtrl;
  late final TextEditingController _wholeDeviceAppCtrl;
  late final TextEditingController _appModeNameCtrl;
  final TextEditingController _appSearchCtrl = TextEditingController();
  LauncherApp? _selectedApp;
  LauncherApp? _wholeDeviceSelectedApp;
  String _searchQuery = '';
  String _selectedMode = 'touch_sensor';

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    final defaultName = 'Macro_${DateTime.now().millisecondsSinceEpoch % 100000}';
    _wholeDeviceNameCtrl = TextEditingController(text: defaultName);
    _wholeDeviceAppCtrl = TextEditingController();
    _appModeNameCtrl = TextEditingController(text: defaultName);

    // Warm launcher cache if needed
    if (LauncherService.instance.apps.value.length <= 1) {
      LauncherService.instance.init();
    }
  }

  @override
  void dispose() {
    _wholeDeviceNameCtrl.dispose();
    _wholeDeviceAppCtrl.dispose();
    _appModeNameCtrl.dispose();
    _appSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAppSelectorSheet() async {
    if (LauncherService.instance.apps.value.length <= 1) {
      await LauncherService.instance.init();
    }
    if (!mounted) return;

    final selected = await showModalBottomSheet<LauncherApp?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetCtx) {
        String query = '';
        final searchCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: JweTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(MdiIcons.apps, color: JweTheme.accentCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'SELECT TARGET APPLICATION',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setSheetState(() => query = v),
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search app name or package...',
                      hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                      prefixIcon: Icon(Icons.search, size: 16, color: JweTheme.textMuted),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, size: 14, color: JweTheme.textMuted),
                              onPressed: () {
                                searchCtrl.clear();
                                setSheetState(() => query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: JweTheme.bgCanvas,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: JweTheme.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Option: Whole Device (All Apps)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, null),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _wholeDeviceSelectedApp == null
                            ? JweTheme.accentCyan.withValues(alpha: 0.12)
                            : JweTheme.bgCanvas,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _wholeDeviceSelectedApp == null
                              ? JweTheme.accentCyan
                              : JweTheme.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(MdiIcons.cellphoneCog, color: JweTheme.accentCyan, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'All Apps / Whole Device',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Record system-wide gestures across all applications',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_wholeDeviceSelectedApp == null)
                            Icon(Icons.check_circle, size: 16, color: JweTheme.accentCyan),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ValueListenableBuilder<List<LauncherApp>>(
                      valueListenable: LauncherService.instance.apps,
                      builder: (context, apps, _) {
                        final q = query.toLowerCase().trim();
                        final seen = <String>{};
                        final candidates = <LauncherApp>[];

                        for (final a in apps) {
                          if (a.kind == LauncherAppKind.web || a.package.isEmpty) continue;
                          if (!seen.add(a.package)) continue;
                          if (q.isNotEmpty) {
                            final labelMatch = a.displayLabel.toLowerCase().contains(q);
                            final pkgMatch = a.package.toLowerCase().contains(q);
                            if (!labelMatch && !pkgMatch) continue;
                          }
                          candidates.add(a);
                        }

                        if (candidates.isEmpty) {
                          return Center(
                            child: Text(
                              'No apps found matching query',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: candidates.length,
                          separatorBuilder: (_, __) => Divider(color: JweTheme.lineSoft, height: 1),
                          itemBuilder: (context, i) {
                            final app = candidates[i];
                            final isSelected = _wholeDeviceSelectedApp?.package == app.package;

                            return InkWell(
                              onTap: () => Navigator.pop(ctx, app),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? JweTheme.accentCyan.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    LauncherAppIcon(app: app, size: 28),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            app.displayLabel,
                                            style: GoogleFonts.jetBrainsMono(
                                              color: isSelected ? JweTheme.accentCyan : JweTheme.textWhite,
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            app.package,
                                            style: GoogleFonts.jetBrainsMono(
                                              color: JweTheme.textMuted,
                                              fontSize: 10,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle, size: 16, color: JweTheme.accentCyan),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
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

    if (!mounted) return;
    setState(() {
      _wholeDeviceSelectedApp = selected;
      _wholeDeviceAppCtrl.text = selected?.package ?? '';
      if (selected != null && _wholeDeviceNameCtrl.text.startsWith('Macro_')) {
        _wholeDeviceNameCtrl.text = '${selected.displayLabel.replaceAll(RegExp(r'\s+'), '_')}_Macro';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: JweTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Icon(MdiIcons.recordCircleOutline, color: JweTheme.accentRed, size: 20),
              const SizedBox(width: 8),
              Text(
                'RECORD AUTOMATION MACRO',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Engine Mode Selector (Touch, Elements)
          _buildEngineModeSelector(),
          const SizedBox(height: 12),

          // Mode Selector Tabs
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: JweTheme.bgCanvas,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: JweTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 0),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? JweTheme.panel : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: _activeTab == 0 ? Border.all(color: JweTheme.accentCyan) : null,
                      ),
                      child: Text(
                        'WHOLE DEVICE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 0 ? JweTheme.accentCyan : JweTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 1),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? JweTheme.panel : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: _activeTab == 1 ? Border.all(color: JweTheme.accentAmber) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            MdiIcons.apps,
                            size: 13,
                            color: _activeTab == 1 ? JweTheme.accentAmber : JweTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'START IN APP',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _activeTab == 1 ? JweTheme.accentAmber : JweTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab Content
          if (_activeTab == 0)
            _buildWholeDeviceTab()
          else
            Expanded(child: _buildStartInAppTab()),
        ],
      ),
    );
  }

  Widget _buildWholeDeviceTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: 24.0 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summons the floating HUD controller over all apps.\nEvery tap, gesture, typing block, and delay across the system will be recorded.',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textMid,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _wholeDeviceNameCtrl,
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
            decoration: InputDecoration(
              labelText: 'MACRO NAME',
              labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10),
              filled: true,
              fillColor: JweTheme.bgCanvas,
              isDense: true,
              border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
            ),
          ),
          const SizedBox(height: 12),

          // Searchable App Selector Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JweTheme.bgCanvas,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _wholeDeviceSelectedApp != null ? JweTheme.accentCyan : JweTheme.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'TARGET APP (OPTIONAL)',
                      style: GoogleFonts.jetBrainsMono(
                        color: _wholeDeviceSelectedApp != null ? JweTheme.accentCyan : JweTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    if (_wholeDeviceSelectedApp != null)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _wholeDeviceSelectedApp = null;
                            _wholeDeviceAppCtrl.clear();
                          });
                        },
                        child: Text(
                          'CLEAR',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentRed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _openAppSelectorSheet,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: JweTheme.panel,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: JweTheme.lineSoft),
                    ),
                    child: Row(
                      children: [
                        if (_wholeDeviceSelectedApp != null) ...[
                          LauncherAppIcon(app: _wholeDeviceSelectedApp!, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _wholeDeviceSelectedApp!.displayLabel,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _wholeDeviceSelectedApp!.package,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMuted,
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: JweTheme.accentCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CHANGE',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentCyan,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else ...[
                          Icon(MdiIcons.cellphoneCog, size: 24, color: JweTheme.textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'All Apps / Whole Device',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Tap to choose a specific app with search...',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.search, size: 18, color: JweTheme.accentCyan),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: JweTheme.accentAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(MdiIcons.keyboardClose, size: 16, color: JweTheme.accentAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TIP: While typing, the touch sensor steps aside for the keyboard. Close the keyboard before submitting any forms so your tap is captured via physical touch coordinates.',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMid,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.fiber_manual_record, size: 16),
              label: Text(
                'START SYSTEM RECORDING',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'name': _wholeDeviceNameCtrl.text.trim(),
                  'targetPackage': _wholeDeviceAppCtrl.text.trim().isEmpty
                      ? null
                      : _wholeDeviceAppCtrl.text.trim(),
                  'mode': _selectedMode,
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartInAppTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select an installed app from Arcane\'s launcher cache. The app will launch immediately and start recording under the floating HUD.',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMid,
            fontSize: 10.5,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: JweTheme.accentAmber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(MdiIcons.keyboardClose, size: 16, color: JweTheme.accentAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TIP: While typing, touch coordinates pause. Close the keyboard before tapping submit buttons so the physical touch is recorded.',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMid,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Search bar
        TextField(
          controller: _appSearchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Search installed apps...',
            hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
            prefixIcon: Icon(Icons.search, size: 16, color: JweTheme.textMuted),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, size: 14, color: JweTheme.textMuted),
                    onPressed: () {
                      _appSearchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: JweTheme.bgCanvas,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: JweTheme.border),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Apps list from LauncherService cache
        Expanded(
          child: ValueListenableBuilder<List<LauncherApp>>(
            valueListenable: LauncherService.instance.apps,
            builder: (context, apps, _) {
              final q = _searchQuery.toLowerCase().trim();
              final seen = <String>{};
              final candidates = <LauncherApp>[];

              for (final a in apps) {
                if (a.kind == LauncherAppKind.web || a.package.isEmpty) continue;
                if (!seen.add(a.package)) continue;
                if (q.isNotEmpty) {
                  final labelMatch = a.displayLabel.toLowerCase().contains(q);
                  final pkgMatch = a.package.toLowerCase().contains(q);
                  if (!labelMatch && !pkgMatch) continue;
                }
                candidates.add(a);
              }

              if (candidates.isEmpty) {
                return Center(
                  child: Text(
                    'No apps found in launcher cache',
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
                  ),
                );
              }

              return ListView.separated(
                itemCount: candidates.length,
                separatorBuilder: (_, __) => Divider(color: JweTheme.lineSoft, height: 1),
                itemBuilder: (context, i) {
                  final app = candidates[i];
                  final isSelected = _selectedApp?.package == app.package;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedApp = app;
                        _appModeNameCtrl.text =
                            '${app.displayLabel.replaceAll(RegExp(r'\s+'), '_')}_Macro';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? JweTheme.accentAmber.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          LauncherAppIcon(app: app, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.displayLabel,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: isSelected
                                        ? JweTheme.accentAmber
                                        : JweTheme.textWhite,
                                    fontSize: 12,
                                    fontWeight:
                                        isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  app.package,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, size: 16, color: JweTheme.accentAmber),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Selected app banner & Macro Name
        if (_selectedApp != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: JweTheme.bgCanvas,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                LauncherAppIcon(app: _selectedApp!, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedApp!.displayLabel,
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _selectedApp!.package,
                        style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appModeNameCtrl,
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
            decoration: InputDecoration(
              labelText: 'MACRO NAME',
              labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 10),
              filled: true,
              fillColor: JweTheme.bgCanvas,
              isDense: true,
              border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.rocket_launch, size: 16),
              label: Text(
                'LAUNCH & START RECORDING',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'name': _appModeNameCtrl.text.trim(),
                  'targetPackage': _selectedApp!.package,
                  'mode': _selectedMode,
                });
              },
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: JweTheme.bgCanvas,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: JweTheme.border),
            ),
            alignment: Alignment.center,
            child: Text(
              'Select an application above to arm recorder',
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEngineModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(MdiIcons.targetVariant, size: 13, color: JweTheme.accentCyan),
            const SizedBox(width: 6),
            Text(
              'ENGINE MODE',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentCyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildEngineModeOption(
              modeKey: 'touch_sensor',
              title: 'TOUCH',
              subtitle: 'Coordinates',
              icon: MdiIcons.gestureTap,
              accentColor: JweTheme.accentAmber,
            ),
            const SizedBox(width: 6),
            _buildEngineModeOption(
              modeKey: 'elements',
              title: 'ELEMENTS',
              subtitle: 'UI Hierarchy',
              icon: MdiIcons.xml,
              accentColor: const Color(0xFF64B5F6),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEngineModeOption({
    required String modeKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedMode == modeKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMode = modeKey),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withValues(alpha: 0.15) : JweTheme.bgCanvas,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? accentColor : JweTheme.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 14, color: isSelected ? accentColor : JweTheme.textMuted),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? accentColor : JweTheme.textMid,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8,
                  color: isSelected ? JweTheme.textWhite : JweTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
