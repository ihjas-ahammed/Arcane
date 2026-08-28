import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/tracked_skill_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart';
import 'package:missions/src/widgets/dialogs/add_edit_skill_dialog.dart';
import 'package:missions/src/widgets/dialogs/add_edit_skill_log_dialog.dart';
import 'package:missions/src/widgets/skills/skill_icon_helper.dart';
import 'package:missions/src/widgets/skills/tactical_charts.dart';
import 'package:missions/src/widgets/skills/tactical_hud_widgets.dart';

class SkillDetailScreen extends StatefulWidget {
  final String skillId;

  const SkillDetailScreen({super.key, required this.skillId});

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  String _selectedMetric = "ELO RATING";
  bool _showAllLogs = false;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final skill = appProvider.trackedSkills.firstWhere(
      (s) => s.id == widget.skillId,
      orElse: () => TrackedSkill(
        id: "not_found",
        name: "UNKNOWN SKILL",
        currentValue: 0,
      ),
    );

    if (skill.id == "not_found") {
      return Scaffold(
        backgroundColor: TacColors.bgDark,
        appBar: AppBar(title: Text("SKILL NOT FOUND", style: GoogleFonts.chakraPetch(color: TacColors.textMain))),
        body: Center(child: Text("Skill not found", style: GoogleFonts.rajdhani(color: TacColors.textMuted))),
      );
    }

    final sortedLogs = List<SkillTrainingLog>.from(skill.logs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: TacColors.bgDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // ── Top Nav (Matching HTML .top-nav) ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back Button
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: TacColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),

                      // Center Title & Indicator Bar
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "SKILL DETAIL",
                            style: GoogleFonts.chakraPetch(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3.0,
                              color: TacColors.primaryRed,
                              shadows: [
                                Shadow(
                                  color: TacColors.primaryRedGlow,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: 76,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: TacColors.primaryRed,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: TacColors.primaryRed,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Options Popup Menu
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz, size: 20, color: TacColors.textMuted),
                        color: TacColors.panelBase,
                        onSelected: (val) {
                          if (val == "log") {
                            AddEditSkillLogDialog.show(
                              context,
                              skillId: skill.id,
                              skillName: skill.name,
                              unit: skill.unit,
                            );
                          } else if (val == "edit") {
                            AddEditSkillDialog.show(context, initialSkill: skill);
                          } else if (val == "delete") {
                            appProvider.deleteTrackedSkill(skill.id);
                            Navigator.pop(context);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: "log",
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 16, color: TacColors.primaryRed),
                                const SizedBox(width: 8),
                                Text("Log Training", style: GoogleFonts.chakraPetch(color: TacColors.textMain, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: "edit",
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16, color: TacColors.textMain),
                                const SizedBox(width: 8),
                                Text("Edit Skill", style: GoogleFonts.chakraPetch(color: TacColors.textMain, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: "delete",
                            child: Row(
                              children: [
                                Icon(MdiIcons.trashCanOutline, size: 16, color: TacColors.primaryRed),
                                const SizedBox(width: 8),
                                Text("Delete Skill", style: GoogleFonts.chakraPetch(color: TacColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Detail Content ─────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    children: [
                      // ── 1. Detail Hero Header Box ───────────────────────
                      _buildDetailHeroBox(skill),

                      // ── 2. Four Metric Stats Grid ───────────────────────
                      _buildStatTilesGrid(skill),

                      // ── 3. Progress Over Time Line Chart ────────────────
                      _buildProgressChartCard(skill, sortedLogs),

                      // ── 4. Training Log Table Card ──────────────────────
                      _buildTrainingLogCard(skill, sortedLogs),

                      // ── 5. Trials vs Outcome Bar Chart Card ─────────────
                      _buildTrialsOutcomeCard(sortedLogs),

                      const SizedBox(height: 12),

                      // ── 6. Log Training Button ──────────────────────────
                      InkWell(
                        onTap: () => AddEditSkillLogDialog.show(
                          context,
                          skillId: skill.id,
                          skillName: skill.name,
                          unit: skill.unit,
                        ),
                        child: TacticalChamferCard(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          borderColor: TacColors.primaryRed.withValues(alpha: 0.6),
                          bgStart: TacColors.primaryRed.withValues(alpha: 0.18),
                          bgEnd: TacColors.primaryRed.withValues(alpha: 0.06),
                          showNotch: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_task, size: 16, color: TacColors.primaryRed),
                              const SizedBox(width: 8),
                              Text(
                                "+ LOG TRAINING ENTRY",
                                style: GoogleFonts.chakraPetch(
                                  color: TacColors.primaryRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Detail Hero Header Box ──────────────────────────────────────────
  Widget _buildDetailHeroBox(TrackedSkill skill) {
    final lastUpdatedStr = DateFormat("dd MMM yyyy").format(skill.lastUpdated).toUpperCase();

    return TacticalChamferCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tactical Icon Box (64x64)
          TacticalIconBox(
            size: 64,
            accent: TacColors.primaryRed,
            icon: SkillIconHelper.buildSkillIconWidget(skill.iconName, size: 34, color: TacColors.primaryRed),
          ),
          const SizedBox(width: 12),

          // Middle Text Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name.toUpperCase(),
                  style: GoogleFonts.chakraPetch(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: TacColors.textMain,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  skill.subtitle.isNotEmpty ? skill.subtitle.toUpperCase() : skill.category.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: TacColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Category Pill Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: TacColors.primaryRed.withValues(alpha: 0.08),
                    border: Border.all(color: TacColors.primaryRed.withValues(alpha: 0.45), width: 1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    skill.category.toUpperCase(),
                    style: GoogleFonts.rajdhani(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: TacColors.primaryRed,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                if (skill.description.isNotEmpty)
                  Text(
                    skill.description,
                    style: GoogleFonts.rajdhani(
                      fontSize: 10.5,
                      color: TacColors.textMuted,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right Stats Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "LATEST",
                style: GoogleFonts.rajdhani(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: TacColors.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatCompactXp(skill.currentValue),
                    style: GoogleFonts.chakraPetch(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: TacColors.primaryRed,
                    ),
                  ),
                  if (skill.unit.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text(
                      skill.unit.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: TacColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(
                skill.effectiveTier,
                style: GoogleFonts.rajdhani(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: TacColors.primaryRed,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              TacticalProgressBar(
                progress: skill.progress,
                width: 82,
                height: 3.5,
                accent: TacColors.primaryRed,
              ),
              const SizedBox(height: 6),
              Text(
                "LAST UPDATED: $lastUpdatedStr",
                style: GoogleFonts.rajdhani(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: TacColors.textDim,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4 Stats Grid ────────────────────────────────────────────────────
  Widget _buildStatTilesGrid(TrackedSkill skill) {
    final bestValStr = formatCompactXp(skill.bestValue);
    final sessionsCount = skill.totalSessions;
    final winRateVal = skill.winRate.round();

    final totalSec = skill.totalTimeSpentSeconds;
    final hours = totalSec ~/ 3600;
    final mins = (totalSec % 3600) ~/ 60;
    final timeStr = hours > 0 ? "${hours}h ${mins}m" : "${mins}m";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: _buildStatTile("BEST RATING", bestValStr, MdiIcons.trophyOutline)),
          const SizedBox(width: 6),
          Expanded(child: _buildStatTile("GAMES PLAYED", "$sessionsCount", MdiIcons.targetAccount)),
          const SizedBox(width: 6),
          Expanded(child: _buildStatTile("WIN RATE", "$winRateVal%", MdiIcons.speedometer)),
          const SizedBox(width: 6),
          Expanded(child: _buildStatTile("TIME SPENT", timeStr, MdiIcons.clockOutline)),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: TacColors.statTileBg,
        border: Border.all(color: TacColors.statTileBorder, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: TacColors.notchColor, width: 1),
                  right: BorderSide(color: TacColors.notchColor, width: 1),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: TacColors.textMuted),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rajdhani(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: TacColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.chakraPetch(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: TacColors.textMain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Progress Over Time Line Chart Card ──────────────────────────────
  Widget _buildProgressChartCard(TrackedSkill skill, List<SkillTrainingLog> sortedLogs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: TacColors.panelBase,
        border: Border.all(color: TacColors.borderOuter, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -1,
            left: 12,
            child: Container(
              width: 24,
              height: 1,
              color: TacColors.notchColor,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "PROGRESS OVER TIME",
                    style: GoogleFonts.chakraPetch(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: TacColors.textMain,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: TacColors.cardBgEnd,
                      border: Border.all(color: TacColors.borderOuter, width: 1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedMetric,
                          style: GoogleFonts.rajdhani(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: TacColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 10, color: TacColors.textMuted),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // SVG-matched Canvas Line Chart
              TacticalProgressLineChart(
                logs: sortedLogs,
                currentValue: skill.currentValue,
                accent: TacColors.primaryRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Training Log Table Card ─────────────────────────────────────────
  Widget _buildTrainingLogCard(TrackedSkill skill, List<SkillTrainingLog> sortedLogs) {
    final displayedLogs = _showAllLogs ? sortedLogs : sortedLogs.take(5).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: TacColors.panelBase,
        border: Border.all(color: TacColors.borderOuter, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TRAINING LOG",
                style: GoogleFonts.chakraPetch(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: TacColors.textMain,
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showAllLogs = !_showAllLogs),
                child: Text(
                  _showAllLogs ? "COLLAPSE" : "VIEW ALL",
                  style: GoogleFonts.rajdhani(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: TacColors.primaryRed,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: TacColors.tableHeaderBorder, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text("DATE", style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text("MODE", style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Text("RATING", style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Text("RESULT", textAlign: TextAlign.right, style: _tableHeaderStyle)),
              ],
            ),
          ),

          if (displayedLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  "No training sessions logged yet.",
                  style: GoogleFonts.rajdhani(color: TacColors.textMuted, fontSize: 11),
                ),
              ),
            )
          else
            ...displayedLogs.map((log) {
              final dateStr = DateFormat("dd MMM yyyy").format(log.timestamp).toUpperCase();
              final isPositive = log.delta != null && log.delta! > 0;
              final isNegative = log.delta != null && log.delta! < 0;

              final deltaColor = isPositive
                  ? TacColors.accentTeal
                  : (isNegative ? TacColors.primaryRed : TacColors.textMuted);

              final deltaStr = log.delta != null
                  ? (log.delta! > 0 ? "+${log.delta!.toInt()}" : log.delta!.toInt().toString())
                  : (log.resultType == "WIN" ? "WIN" : (log.resultType == "LOSS" ? "LOSS" : "-"));

              return InkWell(
                onTap: () => AddEditSkillLogDialog.show(
                  context,
                  skillId: skill.id,
                  skillName: skill.name,
                  unit: skill.unit,
                  initialLog: log,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: TacColors.tableRowBorder, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          dateStr,
                          style: GoogleFonts.rajdhani(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: TacColors.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          log.mode.toUpperCase(),
                          style: GoogleFonts.rajdhani(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: TacColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formatCompactXp(log.value),
                          style: GoogleFonts.chakraPetch(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: TacColors.textMain,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          deltaStr,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: deltaColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  TextStyle get _tableHeaderStyle => GoogleFonts.rajdhani(
        color: TacColors.textDim,
        fontSize: 8.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      );

  // ── Trials vs Outcome Bar Chart Card ────────────────────────────────
  Widget _buildTrialsOutcomeCard(List<SkillTrainingLog> sortedLogs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: TacColors.panelBase,
        border: Border.all(color: TacColors.borderOuter, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TRIALS vs OUTCOME",
                style: GoogleFonts.chakraPetch(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: TacColors.textMain,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: [
                  _buildLegendDot("WINS", TacColors.accentTeal),
                  const SizedBox(width: 8),
                  _buildLegendDot("LOSSES", TacColors.primaryRed),
                  const SizedBox(width: 8),
                  _buildLegendDot("DRAWS", TacColors.accentDraw),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TacticalTrialsOutcomeChart(logs: sortedLogs),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.rajdhani(
            color: TacColors.textMuted,
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
