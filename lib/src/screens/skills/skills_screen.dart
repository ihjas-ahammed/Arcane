import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/tracked_skill_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/skills/skill_detail_screen.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/helpers.dart';
import 'package:missions/src/widgets/dialogs/add_edit_skill_dialog.dart';
import 'package:missions/src/widgets/skills/skill_icon_helper.dart';
import 'package:missions/src/widgets/skills/tactical_hud_widgets.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  String _selectedCategoryFilter = "ALL";

  final List<String> _filterCategories = [
    "ALL",
    "MENTAL",
    "COGNITIVE",
    "PHYSICAL",
    "ENDURANCE",
    "REACTION",
    "DISCIPLINE",
    "GENERAL",
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final allSkills = appProvider.trackedSkills;

    final skills = _selectedCategoryFilter == "ALL"
        ? allSkills
        : allSkills.where((s) => s.category.toUpperCase() == _selectedCategoryFilter).toList();

    final overallIndex = appProvider.overallSkillsIndex;
    final overallTier = appProvider.overallSkillsTier;

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
                      // Back Button & Valorant Logo
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: TacColors.textMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          const ValorantLogoBadge(width: 22, height: 18),
                        ],
                      ),

                      // Center Title & Indicator Bar
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "SKILLS",
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

                      // Action Icons (Filter + Create)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(MdiIcons.tuneVariant, size: 20, color: TacColors.textMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: "Filter Category",
                            onPressed: () => _showFilterDialog(context),
                          ),
                          const SizedBox(width: 14),
                          IconButton(
                            icon: Icon(Icons.add, size: 22, color: TacColors.primaryRed),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: "Add Skill",
                            onPressed: () => AddEditSkillDialog.show(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Skills Content ─────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                    children: [
                      // ── Overview Hero Card ──────────────────────────────
                      _buildOverviewHeroCard(overallIndex, overallTier),

                      // ── Skill Cards ──────────────────────────────────────
                      if (skills.isEmpty)
                        TacticalChamferCard(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(MdiIcons.shieldSwordOutline, size: 40, color: TacColors.textDim),
                                const SizedBox(height: 10),
                                Text(
                                  "NO SKILLS IN THIS VECTOR",
                                  style: GoogleFonts.chakraPetch(
                                    color: TacColors.textMuted,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TacColors.primaryRed,
                                    foregroundColor: JweTheme.onAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  onPressed: () => AddEditSkillDialog.show(context),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(
                                    "CREATE SKILL",
                                    style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...skills.map((skill) => _buildSkillCard(skill)),

                      const SizedBox(height: 6),

                      // ── Add Skill Benchmark Action Button ────────────────
                      InkWell(
                        onTap: () => AddEditSkillDialog.show(context),
                        child: TacticalChamferCard(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          borderColor: TacColors.primaryRed.withValues(alpha: 0.35),
                          bgStart: TacColors.primaryRed.withValues(alpha: 0.08),
                          bgEnd: TacColors.primaryRed.withValues(alpha: 0.02),
                          showNotch: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, size: 16, color: TacColors.primaryRed),
                              const SizedBox(width: 8),
                              Text(
                                "+ CREATE NEW SKILL BENCHMARK",
                                style: GoogleFonts.chakraPetch(
                                  color: TacColors.primaryRed,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
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

  // ── Overview Hero Card ──────────────────────────────────────────────
  Widget _buildOverviewHeroCard(int overallIndex, String overallTier) {
    return TacticalHeroCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      accent: TacColors.primaryRed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: // SKILL PANEL / OVERVIEW / Track. Train. Improve.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      "// SKILL PANEL",
                      style: GoogleFonts.chakraPetch(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: TacColors.primaryRed,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "OVERVIEW",
                  style: GoogleFonts.chakraPetch(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: TacColors.textMain,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Track. Train. Improve.",
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: TacColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Right: Overall Index Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: TacColors.panelBase,
              border: Border.all(color: TacColors.borderOuter, width: 1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -9,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 2,
                    color: TacColors.primaryRed,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "OVERALL INDEX",
                      style: GoogleFonts.rajdhani(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: TacColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const ValorantChevronInsignia(width: 19, height: 23),
                        const SizedBox(width: 6),
                        Text(
                          "$overallIndex",
                          style: GoogleFonts.chakraPetch(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: TacColors.textMain,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overallTier.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: TacColors.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tactical Skill Card ─────────────────────────────────────────────
  Widget _buildSkillCard(TrackedSkill skill) {
    final progress = skill.progress;
    final tier = skill.effectiveTier;

    return TacticalChamferCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkillDetailScreen(skillId: skill.id),
          ),
        );
      },
      onLongPress: () => _showSkillActionSheet(context, skill),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Tactical Icon Box ─────────────────────────────
          TacticalIconBox(
            size: 58,
            accent: TacColors.primaryRed,
            icon: SkillIconHelper.buildSkillIconWidget(skill.iconName, size: 30, color: TacColors.primaryRed),
          ),
          const SizedBox(width: 12),

          // ── Middle Meta ───────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  skill.name.toUpperCase(),
                  style: GoogleFonts.chakraPetch(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: TacColors.textMain,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  skill.subtitle.isNotEmpty ? skill.subtitle.toUpperCase() : skill.category.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: TacColors.textMuted,
                    letterSpacing: 0.9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                TacticalProgressBar(
                  progress: progress,
                  height: 4.0,
                  accent: TacColors.primaryRed,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Right Stats ───────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
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
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: TacColors.primaryRed,
                      shadows: [
                        Shadow(
                          color: TacColors.primaryRedGlow,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  if (skill.unit.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text(
                      skill.unit.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: TacColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(width: 3),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: TacColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                tier,
                style: GoogleFonts.rajdhani(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: TacColors.primaryRed,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TacColors.panelBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "FILTER BY CATEGORY",
                style: GoogleFonts.chakraPetch(
                  color: TacColors.primaryRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _filterCategories.map((c) {
                  final isSel = c == _selectedCategoryFilter;
                  return ChoiceChip(
                    label: Text(c),
                    selected: isSel,
                    selectedColor: TacColors.primaryRed,
                    backgroundColor: TacColors.bgDark,
                    labelStyle: GoogleFonts.chakraPetch(
                      color: isSel ? JweTheme.onAccent : TacColors.textMuted,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedCategoryFilter = c);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSkillActionSheet(BuildContext context, TrackedSkill skill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TacColors.panelBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: TacColors.primaryRed),
                title: Text("Edit Skill Details", style: GoogleFonts.chakraPetch(color: TacColors.textMain, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  AddEditSkillDialog.show(context, initialSkill: skill);
                },
              ),
              ListTile(
                leading: Icon(MdiIcons.trashCanOutline, color: TacColors.redDark),
                title: Text("Delete Skill", style: GoogleFonts.chakraPetch(color: TacColors.redDark, fontWeight: FontWeight.bold)),
                onTap: () {
                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                  appProvider.deleteTrackedSkill(skill.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
