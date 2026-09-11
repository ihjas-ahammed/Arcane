import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class StudioPreviewContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isLive;

  const StudioPreviewContainer({
    super.key,
    required this.title,
    required this.child,
    this.isLive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLive ? JweTheme.accentTeal.withValues(alpha: 0.4) : JweTheme.accentAmber.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLive ? MdiIcons.broadcast : MdiIcons.flaskEmptyOutline,
                size: 14,
                color: isLive ? JweTheme.accentTeal : JweTheme.accentAmber,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.rajdhani(
                    color: JweTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLive ? JweTheme.accentTeal.withValues(alpha: 0.15) : JweTheme.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLive ? "LIVE DATA" : "TEST OVERRIDE",
                  style: GoogleFonts.jetBrainsMono(
                    color: isLive ? JweTheme.accentTeal : JweTheme.accentAmber,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class StudioActionButtons extends StatelessWidget {
  final String syncLabel;
  final VoidCallback onSync;
  final VoidCallback onPin;
  final bool isSyncing;

  const StudioActionButtons({
    super.key,
    required this.syncLabel,
    required this.onSync,
    required this.onPin,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(MdiIcons.cellphoneArrowDown, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'ADD TO HOMESCREEN',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: JweTheme.accentAmber,
                side: BorderSide(color: JweTheme.accentAmber.withValues(alpha: 0.6), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: onPin,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              icon: isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(MdiIcons.upload, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  syncLabel,
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: isSyncing ? null : onSync,
            ),
          ),
        ),
      ],
    );
  }
}

class StudioTestControlsAccordion extends StatelessWidget {
  final bool isOverriding;
  final ValueChanged<bool> onToggleOverride;
  final Widget child;

  const StudioTestControlsAccordion({
    super.key,
    required this.isOverriding,
    required this.onToggleOverride,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: JweTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isOverriding ? JweTheme.accentAmber.withValues(alpha: 0.5) : JweTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          iconColor: JweTheme.accentAmber,
          collapsedIconColor: JweTheme.textMuted,
          title: Row(
            children: [
              Icon(MdiIcons.tuneVariant, size: 16, color: isOverriding ? JweTheme.accentAmber : JweTheme.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "INTERACTIVE TEST CONTROLS",
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isOverriding ? JweTheme.accentAmber : JweTheme.textWhite,
                  ),
                ),
              ),
              Text(
                isOverriding ? "CUSTOM" : "OPTIONAL",
                style: GoogleFonts.jetBrainsMono(
                  color: isOverriding ? JweTheme.accentAmber : JweTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: JweTheme.bgBase,
                      border: Border.all(color: JweTheme.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Override Realtime Feed",
                                style: TextStyle(color: JweTheme.textWhite, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Enable manual values for testing edge cases",
                                style: TextStyle(color: JweTheme.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isOverriding,
                          activeThumbColor: JweTheme.accentAmber,
                          onChanged: onToggleOverride,
                        ),
                      ],
                    ),
                  ),
                  if (isOverriding) ...[
                    child,
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "Live app data is currently streaming into this widget preview. Toggle override above to simulate custom metrics.",
                        style: TextStyle(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudioTextField extends StatelessWidget {
  final String label;
  final String initialValue;
  final Function(String) onChanged;

  const StudioTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey(initialValue),
      initialValue: initialValue,
      style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: JweTheme.isLight ? JweTheme.bgDeep : Colors.black12,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: JweTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: JweTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: JweTheme.accentAmber)),
      ),
      onChanged: onChanged,
    );
  }
}
