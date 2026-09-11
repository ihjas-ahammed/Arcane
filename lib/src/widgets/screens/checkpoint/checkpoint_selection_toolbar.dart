import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class CheckpointSelectionToolbar extends StatelessWidget {
  final bool isSelectionMode;
  final int selectedCount;
  final int totalCount;
  final Color agentColor;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onCopySelected;
  final VoidCallback onCompleteSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onCancelSelection;
  final VoidCallback onEnterSelectionMode;

  const CheckpointSelectionToolbar({
    super.key,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.totalCount,
    required this.agentColor,
    required this.onToggleSelectAll,
    required this.onCopySelected,
    required this.onCompleteSelected,
    required this.onDeleteSelected,
    required this.onCancelSelection,
    required this.onEnterSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: JweTheme.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isSelectionMode) ...[
            Text(
              "$selectedCount SELECTED",
              style: GoogleFonts.jetBrainsMono(
                color: agentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.select_all, size: 18),
                  color: JweTheme.textWhite,
                  onPressed: onToggleSelectAll,
                  tooltip: selectedCount == totalCount
                      ? "Deselect All"
                      : "Select All",
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  color: agentColor,
                  onPressed: selectedCount == 0 ? null : onCopySelected,
                  tooltip: "Copy Selected",
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  color: agentColor,
                  onPressed: selectedCount == 0 ? null : onCompleteSelected,
                  tooltip: "Complete Selected",
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: JweTheme.accentRed,
                  onPressed: selectedCount == 0 ? null : onDeleteSelected,
                  tooltip: "Delete Selected",
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: JweTheme.textMuted,
                  onPressed: onCancelSelection,
                  tooltip: "Cancel",
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ] else ...[
            Text(
              "SUB-ROUTINES (NESTED)",
              style: TextStyle(
                color: JweTheme.textMid,
                fontSize: 12,
                letterSpacing: 1.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (totalCount > 0)
              IconButton(
                icon: Icon(Icons.playlist_add_check,
                    color: agentColor, size: 18),
                onPressed: onEnterSelectionMode,
                tooltip: "Select Multiple",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ],
      ),
    );
  }
}
