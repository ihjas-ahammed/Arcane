import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/utils/task_calculations.dart';
import 'running_task_action_button.dart';

class RunningTaskMultitaskWidget extends StatelessWidget {
  final List<ResolvedDayPlanItem> multitaskTasks;
  final bool isRunning;
  final String capacity;
  final Color neonCyan;
  final Color neonRed;
  final HudTone Function(Color) toneFor;

  const RunningTaskMultitaskWidget({
    super.key,
    required this.multitaskTasks,
    required this.isRunning,
    required this.capacity,
    required this.neonCyan,
    required this.neonRed,
    required this.toneFor,
  });

  @override
  Widget build(BuildContext context) {
    final anyRunning = isRunning || multitaskTasks.any((t) => t.isRunning);
    final accentColor = anyRunning ? neonRed : neonCyan;
    final tone = toneFor(accentColor);
    final items = multitaskTasks.take(3).toList();

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 400,
        height: 200,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 10.0),
          child: CustomPaint(
            foregroundPainter: TacticalCardBorderPainter(
              themeColor: accentColor,
              chamfer: 10.0,
              bracketSize: 12.0,
            ),
            child: Container(
              color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header Row ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.25))),
                    ),
                    child: Row(
                      children: [
                        HudDot(tone: tone),
                        const SizedBox(width: 8),
                        Text(
                          'MULTITASK PROTOCOL · [0${items.length} ACTIVE]',
                          style: GoogleFonts.rajdhani(
                            color: accentColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        if (anyRunning)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'REC',
                              style: GoogleFonts.rajdhani(
                                fontSize: 10,
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                        if (capacity.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(color: JweTheme.lineSoft),
                            ),
                            child: Text(
                              'CAP $capacity',
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textMid,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Multitask Cards Row ──
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: _buildMiniCard(items[i], i + 1),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Buttons Row ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: RunningTaskActionButton(
                            label: anyRunning ? 'HALT SESSION' : 'ENGAGE ALL',
                            icon: anyRunning ? MdiIcons.pause : MdiIcons.play,
                            primary: !anyRunning,
                            accent: anyRunning ? neonRed : neonCyan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RunningTaskActionButton(
                          label: 'CHECK',
                          icon: Icons.check,
                          primary: false,
                          accent: neonCyan,
                          width: 80,
                        ),
                        const SizedBox(width: 8),
                        RunningTaskActionButton(
                          label: 'FINISH',
                          icon: MdiIcons.checkAll,
                          primary: false,
                          accent: JweTheme.accentAmber,
                          width: 80,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCard(ResolvedDayPlanItem item, int index) {
    final itemBorderColor = item.isRunning
        ? neonRed
        : JweTheme.calibrate(item.color);

    return ClipPath(
      clipper: const Chamfer4CornerClipper(chamfer: 6.0),
      child: CustomPaint(
        foregroundPainter: TacticalCardBorderPainter(
          themeColor: itemBorderColor,
          chamfer: 6.0,
          bracketSize: 8.0,
        ),
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.all(7),
          color: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF05080C),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.parentName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rajdhani(
                            color: JweTheme.calibrate(item.color),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Text(
                        '0$index',
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.textMuted.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rajdhani(
                      color: JweTheme.textWhite,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 10,
                        color: item.totalCheckpoints > 0
                            ? neonCyan
                            : (JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.totalCheckpoints > 0
                            ? '${item.completedCheckpoints}/${item.totalCheckpoints}'
                            : '0/0',
                        style: GoogleFonts.rajdhani(
                          color: item.totalCheckpoints > 0
                              ? neonCyan
                              : (JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF64748B)),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
