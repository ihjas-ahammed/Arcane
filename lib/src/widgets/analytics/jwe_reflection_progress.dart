import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/dialogs/last_insight_dialog.dart';
import 'package:missions/src/widgets/screens/reflection_editor_screen.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:provider/provider.dart';

/// Operator HUD reflection-protocol completion strip.
class JweReflectionProgress extends StatelessWidget {
  final List<ReflectionLog> logs;
  final String dateStr;

  const JweReflectionProgress({super.key, required this.logs, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    bool wake = false, morn = false, aft = false, eve = false, night = false;
    ReflectionLog? lastLog;

    for (var log in logs) {
      if (lastLog == null || log.timestamp.isAfter(lastLog.timestamp)) lastLog = log;
      final h = log.timestamp.hour;
      if (h < 8) wake = true;
      else if (h < 12) morn = true;
      else if (h < 16) aft = true;
      else if (h < 19) eve = true;
      else night = true;
    }
    if (night) { eve = true; aft = true; morn = true; wake = true; }
    else if (eve) { aft = true; morn = true; wake = true; }
    else if (aft) { morn = true; wake = true; }
    else if (morn) { wake = true; }

    final segs = [wake, morn, aft, eve, night];
    final completed = segs.where((s) => s).length;
    final pct = (completed / 5 * 100).round();

    return HudPanel(
      clip: HudClip.br,
      accent: JweTheme.accentAmber,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: JweTheme.lineAmber, width: 1)),
          ),
          child: Row(children: [
            Container(width: 4, height: 12, color: JweTheme.accentAmber),
            const SizedBox(width: 10),
            Text('REFLECTION PROTOCOL',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                )),
            const Spacer(),
            Text('$completed/5 · $pct%',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.accentAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              for (var i = 0; i < 5; i++) ...[
                Expanded(child: _Segment(
                  label: const ['WAKE','MORN','AFT','EVE','NIGHT'][i],
                  on: segs[i],
                )),
                if (i < 4) const SizedBox(width: 4),
              ],
            ]),
            const SizedBox(height: 14),
            if (lastLog != null) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  'LAST · ${DateFormat('HH:mm').format(lastLog.timestamp)}',
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                if (lastLog.aiFeedback.isNotEmpty)
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => LastInsightDialog(log: lastLog!),
                      );
                    },
                    child: Text(
                      'VIEW INSIGHT ›',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
            ],
            Consumer<AppProvider>(builder: (ctx, appProvider, _) {
              final hasDraft = appProvider.settings.reflectionDraft != null;
              final label = hasDraft ? 'VIEW DRAFT' : '+ LOG INSIGHT';
              final icon = hasDraft
                  ? MdiIcons.notebookCheck
                  : MdiIcons.notebookEditOutline;
              final color = hasDraft ? JweTheme.accentCyan : JweTheme.accentAmber;
              final bgColor = hasDraft ? JweTheme.cyanSoft : JweTheme.amberSoft;
              final borderColor = hasDraft
                  ? JweTheme.accentCyan.withValues(alpha: 0.3)
                  : JweTheme.lineAmber;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ReflectionEditorScreen(dateStr: dateStr)),
                  );
                },
                child: ClipPath(
                  clipper: HudCutClipper(clip: HudClip.br, cut: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 8),
                      Text(label,
                          style: GoogleFonts.saira(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          )),
                    ]),
                  ),
                ),
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool on;
  const _Segment({required this.label, required this.on});

  @override
  Widget build(BuildContext context) {
    final color = on ? JweTheme.accentAmber : const Color(0x1AA8B3C7);
    return Column(children: [
      Container(
        height: 4,
        decoration: BoxDecoration(
          color: color,
          boxShadow: on ? [BoxShadow(color: JweTheme.accentAmber.withValues(alpha: 0.5), blurRadius: 4)] : null,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: on ? JweTheme.accentAmber : JweTheme.textMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    ]);
  }
}
