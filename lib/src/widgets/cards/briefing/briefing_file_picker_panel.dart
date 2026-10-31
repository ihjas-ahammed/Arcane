import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/providers/briefing_file_picker_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:provider/provider.dart';

/// Compact panel with one row per briefing type. Picking a file copies that type's prompt.
/// Needs a [BriefingFilePickerProvider] above it in the tree.
class BriefingFilePickerPanel extends StatelessWidget {
  final Color accent;

  const BriefingFilePickerPanel({super.key, required this.accent});

  static const Map<BriefingType, String> _labels = {
    BriefingType.daily: "TODAY'S BRIEFING",
    BriefingType.weekly: "THIS WEEK'S REVIEW",
    BriefingType.monthly: "THIS MONTH'S BRIEFING",
  };

  @override
  Widget build(BuildContext context) {
    final picker = context.watch<BriefingFilePickerProvider>();
    final app = Provider.of<AppProvider>(context, listen: false);

    return HudPanel(
      clip: HudClip.both,
      accent: accent,
      allBrackets: true,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.fileDocumentOutline, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'OFFLINE JSON PICKER',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: accent,
                  ),
                ),
              ),
              Text(
                'PICK = CHECK + COPY PROMPT',
                style: GoogleFonts.jetBrainsMono(fontSize: 8, color: JweTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final type in BriefingFilePickerProvider.slotTypes) ...[
            _SlotRow(
              label: _labels[type]!,
              slot: picker.slot(type),
              accent: accent,
              enabled: !picker.isPicking,
              onPick: () => picker.pickFor(type: type, app: app),
            ),
            if (type != BriefingFilePickerProvider.slotTypes.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final String label;
  final BriefingFileSlot slot;
  final Color accent;
  final bool enabled;
  final VoidCallback onPick;

  const _SlotRow({
    required this.label,
    required this.slot,
    required this.accent,
    required this.enabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (slot.status) {
      BriefingSlotStatus.accepted => JweTheme.accentTeal,
      BriefingSlotStatus.rejected => JweTheme.accentRed,
      BriefingSlotStatus.empty => JweTheme.textMuted,
    };
    final statusIcon = switch (slot.status) {
      BriefingSlotStatus.accepted => Icons.check_circle_outline,
      BriefingSlotStatus.rejected => Icons.error_outline,
      BriefingSlotStatus.empty => Icons.radio_button_unchecked,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        border: Border(left: BorderSide(color: statusColor, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.orbitron(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: JweTheme.textWhite,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(statusIcon, size: 11, color: statusColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        slot.fileName != null ? '${slot.fileName}: ${slot.message}' : slot.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(fontSize: 9, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: enabled ? onPick : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: accent.withValues(alpha: enabled ? 0.6 : 0.2)),
                borderRadius: BorderRadius.circular(4),
                color: accent.withValues(alpha: enabled ? 0.1 : 0.03),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 13, color: enabled ? accent : JweTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'PICK',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: enabled ? accent : JweTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
