import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class ActionPlanOutcomeCard extends StatefulWidget {
  final String initialWhat;
  final ValueChanged<String> onChanged;
  final Color accentColor;

  const ActionPlanOutcomeCard({
    super.key,
    required this.initialWhat,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  State<ActionPlanOutcomeCard> createState() => _ActionPlanOutcomeCardState();
}

class _ActionPlanOutcomeCardState extends State<ActionPlanOutcomeCard> {
  late TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialWhat);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      widget.onChanged(val);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Container(
          margin: const EdgeInsets.only(top: 15, bottom: 5),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: widget.accentColor, width: 2)),
          ),
          child: const Text(
            "EXPECTED OUTCOME (WHAT)",
            style: TextStyle(
              color: AppTheme.fhTextSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        TextField(
          controller: _controller,
          maxLines: null,
          minLines: 2,
          style: GoogleFonts.chakraPetch(color: AppTheme.fhTextPrimary, height: 1.5, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Result or Reward...",
            hintStyle: const TextStyle(color: AppTheme.fhTextDisabled),
            filled: true,
            fillColor: AppTheme.fhBgDark.withOpacity(0.5),
            border: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.fhBorderColor)),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.fhBorderColor)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.accentColor)),
            contentPadding: const EdgeInsets.all(12),
          ),
          onChanged: _onTextChanged,
        )
      ],
    );
  }
}