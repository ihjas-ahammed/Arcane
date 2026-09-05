import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Flutter UI representations of the Android home-screen widgets.
/// These are rendered offscreen to PNGs using HomeWidget.renderFlutterWidget.
/// 
/// Since they are rendered to a fixed logical size (400x200), we wrap them in
/// a fixed 400x200 Container to ensure layout stability and pixel-perfect results.

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/utils/task_calculations.dart';

class RunningTaskHomeWidget extends StatelessWidget {
  final bool hasTask;
  final String title;
  final String subtitle;
  final bool isRunning;
  final bool isCheckpoint;
  final int accumulatedSeconds;
  final double progress; // 0..1 — mirrors the missions screen subtask progress
  final bool isPhoenix; // Deprecated - Phoenix protocol removed
  final String capacity; // e.g. "2h40 / 4h30"; empty hides the readout
  final bool dayPlannerWidgetCheckable;
  final List<ResolvedDayPlanItem> topFiveTasks;
  final List<ResolvedDayPlanItem> multitaskTasks;

  static Color get _neonCyan => JweTheme.isLight ? JweTheme.accentCyan : const Color(0xFF00F0FF);
  static Color get _neonRed => JweTheme.isLight ? JweTheme.accentRed : const Color(0xFFFF2A4B);
  static Color get _textMuted => JweTheme.textMuted;

  const RunningTaskHomeWidget({
    super.key,
    required this.hasTask,
    required this.title,
    required this.subtitle,
    required this.isRunning,
    required this.isCheckpoint,
    required this.accumulatedSeconds,
    this.progress = 0.0,
    this.isPhoenix = false,
    this.capacity = '',
    this.dayPlannerWidgetCheckable = false,
    this.topFiveTasks = const [],
    this.multitaskTasks = const [],
  });

  HudTone _toneFor(Color c) {
    if (c == JweTheme.accentCyan || c == _neonCyan) return HudTone.cyan;
    if (c == JweTheme.accentTeal) return HudTone.teal;
    if (c == JweTheme.accentRed || c == _neonRed) return HudTone.red;
    return HudTone.amber;
  }

  String _ringLabel(double sec) {
    final s = sec.floor();
    if (s < 3600) {
      final m = (s ~/ 60).toString().padLeft(2, '0');
      final ss = (s % 60).toString().padLeft(2, '0');
      return '$m:$ss';
    }
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool primary,
    required Color accent,
    double? width,
  }) {
    final bg = primary ? accent : accent.withValues(alpha: JweTheme.isLight ? 0.08 : 0.12);
    final fg = primary ? JweTheme.onAccent : accent;
    final border = Border.all(color: accent, width: 1.2);

    return Container(
      width: width,
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckableList(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 400,
        height: 200,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 10.0),
          child: CustomPaint(
            foregroundPainter: TacticalCardBorderPainter(
              themeColor: _neonCyan,
              chamfer: 10.0,
              bracketSize: 12.0,
            ),
            child: Container(
              color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _neonCyan.withValues(alpha: 0.25))),
                ),
                child: Row(
                  children: [
                    const HudDot(tone: HudTone.cyan),
                    const SizedBox(width: 8),
                    Text(
                      'DAY PLAN // TACTICAL DISPATCH',
                      style: GoogleFonts.rajdhani(
                        color: _neonCyan,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const Spacer(),
                    if (capacity.isNotEmpty)
                      Text(
                        'CAP $capacity',
                        style: GoogleFonts.rajdhani(
                          color: _textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // List of top 5 tasks
              Expanded(
                child: topFiveTasks.isEmpty
                    ? Center(
                        child: Text(
                          'NO ACTIVE PLAN',
                          style: GoogleFonts.teko(
                            color: _textMuted,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          children: List.generate(5, (index) {
                            if (index >= topFiveTasks.length) {
                              return const SizedBox(height: 26);
                            }
                            final item = topFiveTasks[index];
                            return Container(
                              height: 26,
                              margin: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  // Task Indicator / Color bar
                                  Container(
                                    width: 3,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: item.color,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Task details (Name & Subtitle)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.name.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.rajdhani(
                                            color: JweTheme.textWhite,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          item.parentName.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.rajdhani(
                                            color: _textMuted,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Checkbox representation
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _neonCyan,
                                        width: 1.2,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 11,
                                      color: Colors.transparent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            );
                          }),
                        ),
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

  Widget _buildMultitaskWidget(BuildContext context) {
    final anyRunning = isRunning || multitaskTasks.any((t) => t.isRunning);
    final accentColor = anyRunning ? _neonRed : _neonCyan;
    final tone = _toneFor(accentColor);
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
                      child: _buildActionButton(
                        label: anyRunning ? 'HALT SESSION' : 'ENGAGE ALL',
                        icon: anyRunning ? MdiIcons.pause : MdiIcons.play,
                        primary: !anyRunning,
                        accent: anyRunning ? _neonRed : _neonCyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      label: 'CHECK',
                      icon: Icons.check,
                      primary: false,
                      accent: _neonCyan,
                      width: 80,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
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
        ? _neonRed
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
                            ? _neonCyan
                            : (JweTheme.isLight ? JweTheme.textMuted : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.totalCheckpoints > 0
                            ? '${item.completedCheckpoints}/${item.totalCheckpoints}'
                            : '0/0',
                        style: GoogleFonts.rajdhani(
                          color: item.totalCheckpoints > 0
                              ? _neonCyan
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

  Widget _buildSingleTaskWidget(BuildContext context) {
    final accent = !hasTask
        ? JweTheme.textMuted
        : (isCheckpoint
            ? JweTheme.accentCyan
            : JweTheme.accentAmber);
    final tone = _toneFor(accent);

    final statusLabel = !hasTask
        ? 'QUEUE EMPTY'
        : (isCheckpoint
            ? (isRunning ? 'CHECKPOINT · ENGAGED' : 'CHECKPOINT · STANDBY')
            : (isRunning ? 'ACTIVE · ENGAGED' : 'ACTIVE · STANDBY'));

    final ringSec = accumulatedSeconds.toDouble();
    final ringPct = ((ringSec % 3600) / 3600 * 100).clamp(0.0, 100.0);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 400,
        height: 200,
        child: ClipPath(
          clipper: const Chamfer4CornerClipper(chamfer: 10.0),
          child: CustomPaint(
            foregroundPainter: TacticalCardBorderPainter(
              themeColor: accent,
              chamfer: 10.0,
              bracketSize: 12.0,
            ),
            child: Container(
              color: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // ── Status Bar ──
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.25))),
                ),
                child: Row(
                  children: [
                    HudDot(tone: tone),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: GoogleFonts.rajdhani(
                        fontSize: 10.5,
                        color: accent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    if (isRunning)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          'REC',
                          style: GoogleFonts.rajdhani(
                            fontSize: 10,
                            color: accent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: JweTheme.lineSoft),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.formatListBulleted, size: 10, color: JweTheme.textMid),
                          const SizedBox(width: 4),
                          Text(
                            'DAY PLAN',
                            style: GoogleFonts.rajdhani(
                              fontSize: 9.5,
                              color: JweTheme.textMid,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      hasTask ? title.toUpperCase() : 'NO PLAN SET',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        height: 1.15,
                      ),
                    ),
                    if (hasTask && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.08),
                              border: Border(left: BorderSide(color: accent, width: 2)),
                            ),
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Text(
                              subtitle.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textMid,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        HudRing(
                          value: ringPct,
                          size: 52,
                          stroke: 4.5,
                          tone: tone,
                          label: _ringLabel(ringSec),
                          sub: isRunning ? 'SESSION' : 'TODAY',
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OPERATIONAL CAPACITY',
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.textMuted,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                capacity.isNotEmpty ? capacity : 'NO TARGET ESTIMATES SET',
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.textWhite,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ENGAGEMENT STATUS',
                                style: GoogleFonts.rajdhani(
                                  color: JweTheme.textMuted,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                isRunning ? 'REC LIVE TICKING' : 'STANDBY IDLE',
                                style: GoogleFonts.rajdhani(
                                  color: isRunning
                                      ? (JweTheme.isLight ? const Color(0xFF047857) : const Color(0xFF10B981))
                                      : JweTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Action Row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        label: hasTask ? (isRunning ? 'HALT SESSION' : 'ENGAGE') : 'OPEN PLAN',
                        icon: isRunning ? MdiIcons.pause : MdiIcons.play,
                        primary: !isRunning && hasTask,
                        accent: isRunning ? _neonRed : _neonCyan,
                      ),
                    ),
                    if (hasTask && isCheckpoint) ...[
                      const SizedBox(width: 8),
                      _buildActionButton(
                        label: 'CHECK',
                        icon: Icons.check,
                        primary: false,
                        accent: _neonCyan,
                        width: 80,
                      ),
                    ],
                    const SizedBox(width: 8),
                    _buildActionButton(
                      label: hasTask ? 'FINISH' : 'REFRESH',
                      icon: hasTask ? MdiIcons.checkAll : Icons.refresh,
                      primary: false,
                      accent: hasTask ? JweTheme.accentAmber : JweTheme.textMuted,
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

  @override
  Widget build(BuildContext context) {
    if (dayPlannerWidgetCheckable) {
      return _buildCheckableList(context);
    }

    if (multitaskTasks.length > 1) {
      return _buildMultitaskWidget(context);
    }

    return _buildSingleTaskWidget(context);
  }
}

class FinanceHomeWidget extends StatelessWidget {
  final double balance;
  final double todaySpend;
  final double monthSpend;
  final int budgetPct;

  const FinanceHomeWidget({
    super.key,
    required this.balance,
    required this.todaySpend,
    required this.monthSpend,
    required this.budgetPct,
  });

  String _fmtMoney(double val) {
    final abs = val.abs();
    final sign = val < 0 ? "-" : "";
    if (abs >= 10000000) {
      return "$sign₹${(abs / 10000000).toStringAsFixed(2)}Cr";
    } else if (abs >= 100000) {
      return "$sign₹${(abs / 100000).toStringAsFixed(2)}L";
    } else if (abs >= 1000) {
      return "$sign₹${(abs / 1000).toStringAsFixed(1)}K";
    } else {
      return "$sign₹${abs.toStringAsFixed(0)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final clampedPct = budgetPct.clamp(0, 100);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border.all(color: AppTheme.fhAccentGold, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: AppTheme.fhAccentGold,
                    ),
                    const SizedBox(width: 8),
                     Text(
                      "// WALLET",
                      style: TextStyle(
                        color: AppTheme.fhAccentGold,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat('HH:mm').format(DateTime.now()), // last updated time
                  style:   TextStyle(
                    color: AppTheme.fhTextDisabled,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Balance
            Text(
              _fmtMoney(balance),
              style:  TextStyle(
                color: AppTheme.fhAccentGold,
                fontFamily: AppTheme.fontDisplay,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Today / MTD / Budget Columns
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCol("TODAY", _fmtMoney(todaySpend), AppTheme.fhAccentTeal),
                _buildCol("MTD", _fmtMoney(monthSpend), AppTheme.fhAccentGold),
                _buildCol("BUDGET", "$budgetPct%", AppTheme.fhAccentTeal),
              ],
            ),
            const SizedBox(height: 6),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clampedPct / 100.0,
                minHeight: 6,
                backgroundColor: AppTheme.fhBorderColor,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.fhAccentGold),
              ),
            ),
            const SizedBox(height: 8),
            // Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child:   Text(
                      "+ INCOME",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child:   Text(
                      "− EXPENSE",
                      style: TextStyle(
                        color: AppTheme.fhTextPrimary,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCol(String label, String value, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:   TextStyle(
            color: AppTheme.fhTextDisabled,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valColor,
            fontFamily: AppTheme.fontDisplay,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class JournalHomeWidget extends StatelessWidget {
  final int count;
  final bool wake;
  final bool morn;
  final bool aft;
  final bool eve;
  final bool night;

  const JournalHomeWidget({
    super.key,
    required this.count,
    required this.wake,
    required this.morn,
    required this.aft,
    required this.eve,
    required this.night,
  });

  @override
  Widget build(BuildContext context) {
    final todayCount = [wake, morn, aft, eve, night].where((e) => e).length;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          border: Border.all(color: AppTheme.fhAccentTeal, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: AppTheme.fhAccentTeal,
                    ),
                    const SizedBox(width: 8),
                      Text(
                      "// REFLECTION LOG",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  "$count ${count == 1 ? 'ENTRY' : 'ENTRIES'}",
                  style:   TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                  Text(
                  "REFLECTION PROTOCOL",
                  style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  "$todayCount/5 COMPLETE",
                  style:   TextStyle(
                    color: AppTheme.fhAccentTeal,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress segments
            Row(
              children: [
                Expanded(child: _buildSegment("WAKE", wake)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("MORN", morn)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("AFT", aft)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("EVE", eve)),
                const SizedBox(width: 6),
                Expanded(child: _buildSegment("NIGHT", night)),
              ],
            ),
            const Spacer(),
            // Buttons Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child:   Text(
                      "+ NEW LOG",
                      style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 100,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.fhAccentGold, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child:  Text(
                    "ARCHIVE",
                    style: TextStyle(
                      color: AppTheme.fhAccentGold,
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(String label, bool isComplete) {
    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: isComplete ? AppTheme.fhAccentTeal : AppTheme.fhBgMedium,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isComplete ? AppTheme.fhAccentTeal : AppTheme.fhTextSecondary,
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class BusHomeWidget extends StatelessWidget {
  final String origin;
  final String destination;
  final String nextTime;
  final String nextSubStop;
  final bool isOnBus;
  final int speedKmh;
  final int minutesRemaining;

  const BusHomeWidget({
    super.key,
    required this.origin,
    required this.destination,
    required this.nextTime,
    this.nextSubStop = '',
    this.isOnBus = false,
    this.speedKmh = 0,
    this.minutesRemaining = -1,
  });

  @override
  Widget build(BuildContext context) {
    // Exact colors from Android widget_colors.xml
    const bgPanel = Color(0xFF0D1426);
    const bgDeep = Color(0xFF04060E);
    const accentAmber = Color(0xFFFFB547);
    const accentCyan = Color(0xFF5FE1D8);
    const accentTeal = Color(0xFF4AF3C2);
    const textWhite = Color(0xFFEAECF3);
    const textMid = Color(0xFFA8B3C7);
    const textMuted = Color(0xFF5E6C87);

    final statusBadge = isOnBus ? "[ ON BUS // TRANSIT ACTIVE ]" : "[ BUS RADAR // STANDBY ]";
    final speedLabel = isOnBus && speedKmh > 0 ? "SPEED: $speedKmh KM/H" : "GPS: ACTIVE";
    
    // Main Time: When on bus and remaining minutes >= 0: ETA ~14M TO EDAVANNAPPARA.
    // When not on bus: simply nextTime (no "(3m)")
    final mainTimeText = isOnBus && minutesRemaining >= 0
        ? "ETA ~${minutesRemaining}M TO ${destination.toUpperCase()}"
        : nextTime;

    final subStopInfo = nextSubStop.isNotEmpty
        ? (isOnBus ? "NEXT STOP: ${nextSubStop.toUpperCase()}" : "VIA: ${nextSubStop.toUpperCase()}")
        : (minutesRemaining >= 0 ? "DEPARTS IN $minutesRemaining MIN" : "CHECK SCHEDULE");

    final borderColor = isOnBus ? accentTeal : accentAmber;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgPanel,
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      color: isOnBus ? accentTeal : accentAmber,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  speedLabel,
                  style: const TextStyle(
                    color: textMuted,
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Route Name
            Text(
              "${origin.toUpperCase()} → ${destination.toUpperCase()}",
              style: const TextStyle(
                color: textMid,
                fontSize: 11,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Main Time (Bright white text matching widget_text_white)
            Text(
              mainTimeText,
              style: const TextStyle(
                color: textWhite,
                fontSize: 24,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Sub-Stop / Telemetry info
            Text(
              subStopInfo,
              style: const TextStyle(
                color: accentCyan,
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: accentAmber, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "⇄ SWAP",
                      style: TextStyle(
                        color: accentAmber,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: accentAmber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "TIMETABLE",
                      style: TextStyle(
                        color: bgDeep,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
