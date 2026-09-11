import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class CheckpointAddStepInput extends StatelessWidget {
  final TextEditingController controller;
  final String stepType;
  final bool aiMode;
  final bool aiLoading;
  final Color agentColor;
  final ValueChanged<String> onStepTypeChanged;
  final VoidCallback onToggleAiMode;
  final VoidCallback onAdd;

  const CheckpointAddStepInput({
    super.key,
    required this.controller,
    required this.stepType,
    required this.aiMode,
    required this.aiLoading,
    required this.agentColor,
    required this.onStepTypeChanged,
    required this.onToggleAiMode,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: JweTheme.panel.withValues(alpha: 0.5),
        border: Border.all(color: JweTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: PopupMenuButton<String>(
              icon: Icon(
                stepType == 'info'
                    ? MdiIcons.informationOutline
                    : MdiIcons.checkboxMarkedOutline,
                color: JweTheme.textMid,
                size: 20,
              ),
              onSelected: onStepTypeChanged,
              color: JweTheme.panel,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'check',
                  child: Text("Checkable",
                      style: TextStyle(color: JweTheme.textWhite)),
                ),
                PopupMenuItem(
                  value: 'info',
                  child: Text("Info",
                      style: TextStyle(color: JweTheme.textWhite)),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.chakraPetch(
                  color: JweTheme.textWhite, fontSize: 14),
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: aiMode
                    ? "DESCRIBE NESTED STEPS FOR AI..."
                    : "ADD NESTED STEP...   (try  Rep*8  or  Set %d * 4)",
                hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          IconButton(
            tooltip: aiMode ? "AI mode on" : "Turn on AI mode",
            icon: Icon(
              MdiIcons.autoFix,
              color: aiMode ? agentColor : JweTheme.textMid,
            ),
            onPressed: aiLoading ? null : onToggleAiMode,
          ),
          aiLoading
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(agentColor),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.add, color: agentColor),
                  onPressed: onAdd,
                ),
        ],
      ),
    );
  }
}
