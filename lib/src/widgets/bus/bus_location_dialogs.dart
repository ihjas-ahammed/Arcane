import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/bus_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

/// Shows dialog to add or edit a transit location/station
Future<Map<String, String>?> showAddLocationDialog(
  BuildContext context, {
  String? initialName,
}) async {
  final nameCtrl = TextEditingController(text: initialName ?? "");
  final codeCtrl = TextEditingController();

  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: JweTheme.panel,
      title: Text(
        "NEW TRANSIT PLACE",
        style: GoogleFonts.chakraPetch(
          color: JweTheme.accentAmber,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 16,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Enter the name of the place or station to add to your transit network.",
            style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
            decoration: InputDecoration(
              labelText: "PLACE / STATION NAME",
              labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
              hintText: "e.g. Manjeri, Calicut, Kondotty",
              hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 11),
              filled: true,
              fillColor: JweTheme.bgBase,
              border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5)),
            ),
            onChanged: (val) {
              if (codeCtrl.text.isEmpty || codeCtrl.text.length <= 3) {
                final cleaned = val.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
                if (cleaned.isNotEmpty) {
                  codeCtrl.text = cleaned.substring(0, cleaned.length.clamp(1, 3));
                }
              }
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 4,
            style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 13),
            decoration: InputDecoration(
              labelText: "SHORT CODE (2-4 LETTERS)",
              labelStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
              hintText: "e.g. MJR, CLT, KDT",
              hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 11),
              filled: true,
              fillColor: JweTheme.bgBase,
              border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5)),
              counterText: "",
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text("CANCEL", style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentAmber,
            foregroundColor: JweTheme.onAccent,
          ),
          onPressed: () {
            final rawName = nameCtrl.text.trim();
            if (rawName.isEmpty) return;
            final formattedName = DefaultBusNetwork.formatPlaceName(rawName);
            var code = codeCtrl.text.trim().toUpperCase();
            if (code.isEmpty) {
              final cleaned = formattedName.replaceAll(RegExp(r'[^a-zA-Z]'), '');
              code = cleaned.substring(0, cleaned.length.clamp(1, 3)).toUpperCase();
            }
            Navigator.pop(ctx, {"name": formattedName, "code": code});
          },
          child: Text("ADD PLACE", style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

/// Manage / Edit / Delete an existing place
Future<void> showManageStopDialog(
  BuildContext context, {
  required BusStop stop,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) async {
  final isCore = ['ss_college', 'edavannappara', 'areekode'].contains(stop.id.toLowerCase());

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
                  'MANAGE PLACE: ${stop.name}',
                  style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
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
              leading: Icon(MdiIcons.pencilOutline, color: JweTheme.accentCyan),
              title: Text('Edit Place Details', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: JweTheme.textWhite)),
              subtitle: Text('Modify name and short code', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
            if (!isCore)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(MdiIcons.trashCanOutline, color: JweTheme.accentRed),
                title: Text('Delete Place', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: JweTheme.accentRed)),
                subtitle: Text('Removes ${stop.name} from transit network', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: JweTheme.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
          ],
        ),
      ),
    ),
  );
}
