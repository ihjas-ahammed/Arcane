import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/common/growing_text_field.dart';

class ActionPlanWhyCard extends StatefulWidget {
  final String initialWhy;
  final ValueChanged<String> onChanged;

  const ActionPlanWhyCard({
    super.key,
    required this.initialWhy,
    required this.onChanged,
  });

  @override
  State<ActionPlanWhyCard> createState() => _ActionPlanWhyCardState();
}

class _ActionPlanWhyCardState extends State<ActionPlanWhyCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialWhy);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("STRATEGIC INTENT (WHY)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark.withOpacity(0.5),
            border: Border(left: BorderSide(color: AppTheme.fhAccentTeal, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _controller,
            maxLines: null,
            minLines: 2,
            style: const TextStyle(color: AppTheme.fhTextPrimary, height: 1.5, fontSize: 14),
            decoration: const InputDecoration(
              hintText: "Reason for action...",
              hintStyle: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic),
              border: InputBorder.none,
            ),
            onChanged: widget.onChanged,
          ),
        )
      ],
    );
  }
}