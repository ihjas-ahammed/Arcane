import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class ActionPlanOutcomeCard extends StatefulWidget {
  final String initialWhat;
  final ValueChanged<String> onChanged;

  const ActionPlanOutcomeCard({
    super.key,
    required this.initialWhat,
    required this.onChanged,
  });

  @override
  State<ActionPlanOutcomeCard> createState() => _ActionPlanOutcomeCardState();
}

class _ActionPlanOutcomeCardState extends State<ActionPlanOutcomeCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialWhat);
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
        const Text("EXPECTED OUTCOME (WHAT)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark.withOpacity(0.5),
            border: Border(left: BorderSide(color: AppTheme.fhAccentGold, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _controller,
            maxLines: null,
            minLines: 2,
            style: const TextStyle(color: AppTheme.fhTextPrimary, height: 1.5, fontSize: 14),
            decoration: const InputDecoration(
              hintText: "Result or Reward...",
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