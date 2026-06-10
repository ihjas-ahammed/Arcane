import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart' as helper;
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:provider/provider.dart';

/// Operator HUD drawer agent tile — hex code, theme caption,
/// today vs yesterday time delta with segmented bar.
class JweDrawerProtocolItem extends StatelessWidget {
  final MainTask task;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final IconData icon;

  const JweDrawerProtocolItem({
    super.key,
    required this.task,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.icon,
  });

  HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed) return HudTone.red;
    return HudTone.amber;
  }

  String _hexCode(String id) {
    final h = id.hashCode.abs() % 99 + 1;
    return h.toString().padLeft(2, '0');
  }

  /// Compact h/m formatter. <1m → 0m. ≥1h → 1h 12m. else 12m.
  String _compact(int sec) {
    if (sec < 60) return '0m';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final color = task.taskColor;
    final tone = _toneFor(color);

    final todaySec = task.dailyTimeSpent;
    final yesterdaySec = appProvider.getYesterdaysTimeForTask(task.id);

    // Bar pct: today / yesterday. Cap visual at 100% but keep raw for label.
    final rawPct = yesterdaySec > 0
        ? todaySec / yesterdaySec
        : (todaySec > 0 ? 1.0 : 0.0);
    final barPct = rawPct.clamp(0.0, 1.0);
    final pctLabel = yesterdaySec > 0 ? (rawPct * 100).round() : null;

    // Color the % vs yesterday: ≥100 teal, ≥60 amber, else cyan-dim
    final pctTone = pctLabel == null
        ? HudTone.neutral
        : (pctLabel >= 100 ? HudTone.teal : (pctLabel >= 60 ? HudTone.amber : HudTone.cyan));

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: HudPanel(
        clip: HudClip.br,
        accent: color,
        allBrackets: isSelected,
        padding: const EdgeInsets.all(12),
        background: isSelected ? color.withValues(alpha: 0.08) : JweTheme.panel,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            HudHexTag(code: _hexCode(task.id), color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(
                  'A-${_hexCode(task.id)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: isSelected ? color : color.withValues(alpha: 0.5),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.saira(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? JweTheme.textWhite : JweTheme.textMid,
                    letterSpacing: 0.4,
                  ),
                ),
              ]),
            ),
            Icon(icon, size: 18, color: isSelected ? color : color.withValues(alpha: 0.4)),
          ]),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(
                helper.formatTime(todaySec.toDouble()),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'TODAY',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: color.withValues(alpha: 0.4), letterSpacing: 1.2, fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              if (pctLabel != null) ...[
                Text(
                  '${pctLabel}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _toneColor(pctTone),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                'VS ${_compact(yesterdaySec)} YDAY',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: color.withValues(alpha: 0.4), letterSpacing: 1.2, fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          HudBar(value: barPct * 100, color: color, height: 3),
        ]),
      ),
    );
  }

  Color _toneColor(HudTone t) {
    switch (t) {
      case HudTone.amber: return JweTheme.accentAmber;
      case HudTone.cyan: return JweTheme.accentCyan;
      case HudTone.teal: return JweTheme.accentTeal;
      case HudTone.red: return JweTheme.accentRed;
      case HudTone.neutral: return JweTheme.textMid;
    }
  }
}
