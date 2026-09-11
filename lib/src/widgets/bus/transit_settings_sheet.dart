import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Shows bottom sheet for transit telemetry and schedule configuration
Future<void> showTransitSettingsSheet(
  BuildContext context, {
  required VoidCallback onAddPlace,
  required VoidCallback onRawTransmission,
  required VoidCallback onEditNetwork,
  required VoidCallback onPreviewWidgets,
  required VoidCallback onResetDefaults,
}) async {
  return showModalBottomSheet(
    context: context,
    backgroundColor: JweTheme.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TRANSIT TELEMETRY CONFIG',
                  style: GoogleFonts.rajdhani(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: JweTheme.accentAmber,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(MdiIcons.mapMarkerPlus, color: JweTheme.accentAmber),
              title: Text(
                'Add New Place / Station',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.accentAmber,
                ),
              ),
              subtitle: Text(
                'Add custom cities, towns, colleges, or stops',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onAddPlace();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(MdiIcons.codeBrackets, color: JweTheme.accentAmber),
              title: Text(
                'Raw Transmission Data (Bulk Edit)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.accentAmber,
                ),
              ),
              subtitle: Text(
                'Edit raw comma-separated timetable for active route',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onRawTransmission();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(MdiIcons.busStopCovered, color: JweTheme.accentCyan),
              title: Text(
                'Edit Transit Network',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.accentCyan,
                ),
              ),
              subtitle: Text(
                'Manage routes, stops, distances & two-way timetables',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onEditNetwork();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(MdiIcons.widgetsOutline, color: JweTheme.accentTeal),
              title: Text(
                'Preview Android Homescreen Widget',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.accentTeal,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onPreviewWidgets();
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(MdiIcons.restore, color: JweTheme.accentRed),
              title: Text(
                'Restore Default Timetables',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: JweTheme.accentRed,
                ),
              ),
              subtitle: Text(
                'Re-feed pristine default schedules into DB',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onResetDefaults();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Confirmation dialog to restore defaults
Future<bool?> showResetTimetablesDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: JweTheme.panel,
      title: Text(
        "RESTORE DEFAULT TIMETABLES",
        style: GoogleFonts.chakraPetch(color: JweTheme.accentAmber, fontWeight: FontWeight.bold),
      ),
      content: Text(
        "Reset bus schedule to pristine default timetables for S.S College, Edavannappara, and Areekode? This will overwrite custom edits.",
        style: GoogleFonts.rajdhani(color: JweTheme.textWhite),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text("CANCEL", style: GoogleFonts.rajdhani(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentRed,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text("RESET & FEED DB", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
