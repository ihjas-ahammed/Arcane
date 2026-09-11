import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class ManualProgressInput extends StatefulWidget {
  final String mainTaskId;
  final SubTask subTask;
  final Color accentColor;
  final AppProvider provider;

  const ManualProgressInput({
    super.key,
    required this.mainTaskId,
    required this.subTask,
    required this.accentColor,
    required this.provider,
  });

  @override
  State<ManualProgressInput> createState() => _ManualProgressInputState();
}

class _ManualProgressInputState extends State<ManualProgressInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final pct = (widget.subTask.manualProgress * 100).round();
    _controller = TextEditingController(text: pct.toString());
  }

  @override
  void didUpdateWidget(covariant ManualProgressInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.subTask.manualProgress * 100).round() !=
        (widget.subTask.manualProgress * 100).round()) {
      final pct = (widget.subTask.manualProgress * 100).round();
      _controller.text = pct.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PROGRESS: ',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        Container(
          width: 44,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.40),
            ),
            color: widget.accentColor.withValues(alpha: 0.05),
          ),
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.textWhite,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            onSubmitted: (val) {
              final parsed = double.tryParse(val);
              if (parsed != null) {
                final mp = (parsed / 100.0).clamp(0.0, 1.0);
                widget.provider.taskActions.updateSubtask(
                  widget.mainTaskId,
                  widget.subTask.id,
                  {'manualProgress': mp},
                );
              }
            },
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '%',
          style: GoogleFonts.jetBrainsMono(
            color: widget.accentColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
