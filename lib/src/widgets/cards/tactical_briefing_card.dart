import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:collection/collection.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/utils/goal_briefing_helper.dart';
import 'package:missions/src/widgets/ui/task_progress_snapshot_view.dart';

class TacticalBriefingCard extends StatelessWidget {
  final Map<String, dynamic> briefingData;
  final VoidCallback? onSave;
  final VoidCallback? onDeleteAndRetry;
  final bool isSaved;
  final DateTime? date;

  const TacticalBriefingCard({
    super.key,
    required this.briefingData,
    this.onSave,
    this.onDeleteAndRetry,
    this.isSaved = false,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final summary      = briefingData['summary']        as String?        ?? "No intel available.";
    final quoteReflections = briefingData['quote_reflections'] as List<dynamic>? ?? [];
    final improvements = briefingData['improvements']   as List<dynamic>? ?? [];
    final gratefulPeople  = briefingData['grateful_people']  as List<dynamic>? ?? [];
    final gratefulToday = (briefingData['grateful_today'] as List<dynamic>?)
        ?? (briefingData['grateful_assets'] as List<dynamic>?)
        ?? [];
    final savorMoment       = briefingData['savor_moment']       as String? ?? '';
    final smallWin          = briefingData['small_win']          as String? ?? '';
    final tomorrowIntention = briefingData['tomorrow_intention'] as String? ?? '';
    final suggestedActivities = briefingData['suggested_activities'] as List<dynamic>? ?? [];
    final financeBriefing   = briefingData['finance_briefing']   as Map<String, dynamic>?;

    return HudPanel(
      clip: HudClip.both,
      accent: JweTheme.accentAmber,
      allBrackets: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Panel header ─────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: JweTheme.accentAmber.withValues(alpha: 0.22))),
            ),
            child: Row(children: [
              Container(width: 4, height: 14, color: JweTheme.accentAmber),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TACTICAL BRIEFING',
                    maxLines: 1,
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (!isSaved && onSave != null) ...[
                Tooltip(
                  message: 'Save briefing to daily log',
                  child: InkWell(
                    onTap: onSave,
                    child: ClipPath(
                      clipper: HudCutClipper(clip: HudClip.br, cut: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: JweTheme.accentCyan.withValues(alpha: 0.10),
                          border: Border.all(
                              color: JweTheme.accentCyan.withValues(alpha: 0.45)),
                        ),
                        child: Text('SAVE',
                            style: GoogleFonts.jetBrainsMono(
                              color: JweTheme.accentCyan,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            )),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (onDeleteAndRetry != null) ...[
                Tooltip(
                  message: 'Delete & Retry Briefing',
                  child: InkWell(
                    onTap: onDeleteAndRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: JweTheme.accentRed.withValues(alpha: 0.10),
                        border: Border.all(
                            color: JweTheme.accentRed.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.refresh, color: JweTheme.accentRed, size: 10),
                          const SizedBox(width: 3),
                          Text('RETRY',
                              style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentRed,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (isSaved) ...[
                Icon(MdiIcons.checkBold, color: JweTheme.accentCyan, size: 15),
                const SizedBox(width: 6),
              ],
              HudDot(tone: HudTone.amber, size: 5),
            ]),
          ),

          // ── Content ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Intel summary
                HudSectionHead(
                  label: 'INTEL SUMMARY',
                  accent: HudTone.amber,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: GoogleFonts.inter(
                    color: JweTheme.textWhite,
                    fontSize: 13,
                    height: 1.55,
                    fontStyle: FontStyle.italic,
                  ),
                ).animate().fadeIn(duration: 500.ms),

                // Quoted Reflections & AI Comments
                if (quoteReflections.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'QUOTED HIGHLIGHTS & AI APPRECIATION',
                    accent: HudTone.cyan,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  ...quoteReflections.map((item) {
                    final map = item as Map<String, dynamic>;
                    final userQuote = map['user_quote'] as String? ?? '';
                    final aiComment = map['ai_comment'] as String? ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: JweTheme.bgDeep.withValues(alpha: 0.6),
                        border: Border(
                            left: BorderSide(color: JweTheme.accentCyan, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            color: JweTheme.accentCyan.withValues(alpha: 0.08),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(MdiIcons.formatQuoteOpen,
                                    size: 14, color: JweTheme.accentCyan),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '"$userQuote"',
                                    style: GoogleFonts.inter(
                                      color: JweTheme.textWhite,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(MdiIcons.brain,
                                    size: 13, color: JweTheme.accentAmber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    aiComment,
                                    style: GoogleFonts.inter(
                                      color: JweTheme.textMid,
                                      fontSize: 12,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms);
                  }),
                ],

                // Goal Tactical Intel Section
                _buildTacticalGoalsSection(context, Provider.of<AppProvider>(context), date ?? DateTime.now()),

                // Daily Finance Briefing HUD
                if (financeBriefing != null) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'DAILY FINANCE BRIEFING',
                    accent: HudTone.amber,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.accentAmber.withValues(alpha: 0.05),
                      border: Border.all(
                          color: JweTheme.accentAmber.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('INFLOW',
                                    style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.textMuted,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 3),
                                Text('₹${financeBriefing['income'] ?? 0}',
                                    style: GoogleFonts.chakraPetch(
                                        color: JweTheme.accentTeal,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(width: 1, height: 24, color: JweTheme.lineSoft),
                            Column(
                              children: [
                                Text('OUTFLOW',
                                    style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.textMuted,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 3),
                                Text('₹${financeBriefing['expense'] ?? 0}',
                                    style: GoogleFonts.chakraPetch(
                                        color: JweTheme.accentRed,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(width: 1, height: 24, color: JweTheme.lineSoft),
                            Column(
                              children: [
                                Text('NET',
                                    style: GoogleFonts.jetBrainsMono(
                                        color: JweTheme.textMuted,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 3),
                                Text('₹${financeBriefing['net'] ?? 0}',
                                    style: GoogleFonts.chakraPetch(
                                        color: JweTheme.accentAmber,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        if ((financeBriefing['ai_feedback']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Divider(color: JweTheme.lineSoft, height: 1),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(MdiIcons.finance, size: 13, color: JweTheme.accentAmber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  financeBriefing['ai_feedback'].toString(),
                                  style: GoogleFonts.inter(
                                      color: JweTheme.textWhite,
                                      fontSize: 11.5,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ],

                // Suggested New Activities based on day's log
                if (suggestedActivities.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'SUGGESTED NEW ACTIVITIES',
                    accent: HudTone.teal,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  ...suggestedActivities.map((act) {
                    final m = act as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: JweTheme.accentTeal.withValues(alpha: 0.06),
                        border: Border(left: BorderSide(color: JweTheme.accentTeal, width: 2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(MdiIcons.compassOutline, size: 14, color: JweTheme.accentTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(children: [
                                TextSpan(
                                  text: '${m['activity']}: ',
                                  style: GoogleFonts.saira(
                                    fontWeight: FontWeight.w700,
                                    color: JweTheme.accentTeal,
                                    fontSize: 12.5,
                                  ),
                                ),
                                TextSpan(
                                  text: m['reason'] ?? '',
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textMid,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Savor moment (savoring - relive the day's best moment)
                if (savorMoment.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'SAVOR THIS',
                    accent: HudTone.teal,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.accentTeal.withValues(alpha: 0.05),
                      border: Border(
                          left: BorderSide(color: JweTheme.accentTeal, width: 3)),
                    ),
                    child: Text(
                      savorMoment,
                      style: GoogleFonts.inter(
                        color: JweTheme.textWhite,
                        fontSize: 12.5,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ],

                // Small win (progress principle)
                if (smallWin.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'SMALL WIN LOGGED',
                    accent: HudTone.amber,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(MdiIcons.trophyVariantOutline,
                          size: 14, color: JweTheme.accentAmber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          smallWin,
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                ],

                // Ability improvements
                if (improvements.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'ABILITY IMPROVEMENTS',
                    accent: HudTone.amber,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  ...improvements.map((imp) {
                    final m = imp as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(MdiIcons.arrowUpBold,
                              size: 13, color: JweTheme.accentCyan),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(children: [
                                TextSpan(
                                  text: '${m['ability']}: ',
                                  style: GoogleFonts.saira(
                                    fontWeight: FontWeight.w700,
                                    color: JweTheme.textWhite,
                                    fontSize: 13,
                                  ),
                                ),
                                TextSpan(
                                  text: m['insight'] ?? '',
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textMid,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Allies
                if (gratefulPeople.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Builder(builder: (context) {
                    final provider = Provider.of<AppProvider>(context);

                    bool personNeedsUpdate(dynamic person) {
                      final p = person as Map<String, dynamic>;
                      final pName = p['name'] as String? ?? '';
                      final existing = provider.chatbotMemory.people.firstWhereOrNull(
                          (e) => e.name.toLowerCase().trim() == pName.toLowerCase().trim());
                      return existing != null &&
                          !provider.journalingActions.isPersonUpdating(existing.id) &&
                          (existing.details == null ||
                              existing.details!.isEmpty ||
                              existing.lastUpdated == null ||
                              (date != null && existing.lastUpdated!.isBefore(date!)));
                    }

                    final pendingIds = <String>[];
                    for (final person in gratefulPeople) {
                      if (personNeedsUpdate(person)) {
                        final pName = (person as Map<String, dynamic>)['name'] as String? ?? '';
                        final existing = provider.chatbotMemory.people.firstWhereOrNull(
                            (e) => e.name.toLowerCase().trim() == pName.toLowerCase().trim());
                        if (existing != null) pendingIds.add(existing.id);
                      }
                    }

                    return Row(children: [
                      const Expanded(
                        child: HudSectionHead(
                          label: 'ALLIES DETECTED',
                          accent: HudTone.cyan,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      if (pendingIds.length >= 2)
                        InkWell(
                          onTap: () {
                            provider.journalingActions.generateAllPersonDetails(pendingIds);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: JweTheme.accentCyan.withValues(alpha: 0.1),
                              border: Border.all(
                                  color: JweTheme.accentCyan.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              'UPDATE ALL (${pendingIds.length})',
                              style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.accentCyan,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ]);
                  }),
                  const SizedBox(height: 10),
                  ...gratefulPeople.map((person) {
                    final p = person as Map<String, dynamic>;
                    final pName = p['name'] as String? ?? '';
                    final express = p['express'] as String? ?? '';
                    final provider = Provider.of<AppProvider>(context);
                    final existingPerson = provider.chatbotMemory.people.firstWhereOrNull(
                        (e) => e.name.toLowerCase().trim() == pName.toLowerCase().trim());

                    final isUpdating = existingPerson != null &&
                        provider.journalingActions.isPersonUpdating(existingPerson.id);
                    final needsUpdate = existingPerson != null && (
                      existingPerson.details == null ||
                      existingPerson.details!.isEmpty ||
                      existingPerson.lastUpdated == null ||
                      (date != null && existingPerson.lastUpdated!.isBefore(date!))
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JweTheme.bgBase,
                        border: Border(
                            left: BorderSide(
                                color: JweTheme.accentCyan, width: 3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                pName.toUpperCase(),
                                style: GoogleFonts.chakraPetch(
                                    fontWeight: FontWeight.bold,
                                    color: JweTheme.accentCyan,
                                    fontSize: 12),
                              ),
                              if (existingPerson != null && (needsUpdate || isUpdating))
                                InkWell(
                                  onTap: isUpdating
                                      ? null
                                      : () async {
                                          await provider.journalingActions.generatePersonDetails(existingPerson.id);
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: JweTheme.accentCyan.withValues(alpha: 0.1),
                                      border: Border.all(
                                          color: JweTheme.accentCyan
                                              .withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      isUpdating ? "SCANNING..." : "UPDATE PROFILE",
                                      style: GoogleFonts.jetBrainsMono(
                                          color: JweTheme.accentCyan,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(p['reason'] ?? '',
                              style: GoogleFonts.inter(
                                  color: JweTheme.textMid,
                                  fontSize: 12,
                                  height: 1.4)),
                          if (express.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(MdiIcons.sendOutline,
                                    size: 11, color: JweTheme.accentTeal),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'SAY IT: "$express"',
                                    style: GoogleFonts.inter(
                                        color: JweTheme.accentTeal,
                                        fontSize: 11,
                                        height: 1.4,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ).animate().slideX(begin: 0.08, end: 0).fadeIn();
                  }),
                ],

                // Small Sized Gratitude Text Chips
                if (gratefulToday.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'GRATITUDE INTEL (${gratefulToday.length} NOTES)',
                    accent: HudTone.teal,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(gratefulToday.length, (i) {
                      final rawItem = gratefulToday[i];
                      final item = rawItem is Map<String, dynamic>
                          ? rawItem
                          : (rawItem is Map ? Map<String, dynamic>.from(rawItem) : {'text': rawItem.toString()});
                      final text = (item['text'] as String?)?.isNotEmpty == true
                          ? item['text'] as String
                          : (item['name'] ?? item['why'] ?? item['reason'] ?? '').toString();
                      if (text.isEmpty) return const SizedBox.shrink();
                      final iconType = item['icon_type']?.toString().toLowerCase() ?? 'general';
                      IconData getIcon(String type) {
                        switch (type) {
                          case 'people': return MdiIcons.accountGroup;
                          case 'nature': return MdiIcons.leaf;
                          case 'health': return MdiIcons.heartPulse;
                          case 'learning': return MdiIcons.bookOpenVariant;
                          case 'work': return MdiIcons.briefcaseOutline;
                          case 'home': return MdiIcons.homeOutline;
                          case 'food': return MdiIcons.foodApple;
                          case 'social': return MdiIcons.messageTextOutline;
                          case 'growth': return MdiIcons.trendingUp;
                          case 'mind': return MdiIcons.brain;
                          case 'moment': return MdiIcons.clockOutline;
                          default: return MdiIcons.heartOutline;
                        }
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: JweTheme.accentTeal.withValues(alpha: 0.08),
                          border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(getIcon(iconType), size: 13, color: JweTheme.accentTeal),
                            const SizedBox(width: 6),
                            Text(
                              text,
                              style: GoogleFonts.inter(
                                color: JweTheme.textWhite,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ).animate().fadeIn(duration: 400.ms),
                ],

                // Tomorrow's implementation intention (bridge to next day)
                if (tomorrowIntention.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  HudSectionHead(
                    label: 'TOMORROW INTENTION',
                    accent: HudTone.cyan,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: JweTheme.accentCyan.withValues(alpha: 0.06),
                      border: Border.all(
                          color: JweTheme.accentCyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('> ',
                            style: GoogleFonts.jetBrainsMono(
                                color: JweTheme.accentCyan,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        Expanded(
                          child: Text(
                            tomorrowIntention,
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalGoalsSection(BuildContext context, AppProvider provider, DateTime briefingDate) {
    final yesterdayCompleted = GoalBriefingHelper.getYesterdayCompletedGoals(provider, briefingDate);
    final todayGoalsMap = GoalBriefingHelper.getTodayGoalsForBriefing(provider, briefingDate);
    final completedToday = todayGoalsMap['completed']!;
    final inProgressToday = todayGoalsMap['inProgress']!;
    final weeklyGoals = provider.getGoalsForDate(briefingDate, GoalScope.weekly);
    final monthlyGoals = provider.getGoalsForDate(briefingDate, GoalScope.monthly);
    final periodGoals = [...weeklyGoals, ...monthlyGoals];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        HudSectionHead(
          label: 'GOAL TACTICAL INTEL',
          accent: HudTone.cyan,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JweTheme.bgDeep.withValues(alpha: 0.6),
            border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Yesterday's Completed Goals
              Row(
                children: [
                  Icon(MdiIcons.trophyOutline, size: 13, color: JweTheme.accentTeal),
                  const SizedBox(width: 6),
                  Text(
                    "YESTERDAY'S COMPLETED",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentTeal,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (yesterdayCompleted.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: yesterdayCompleted.map((g) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: JweTheme.accentTeal.withValues(alpha: 0.12),
                        border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(MdiIcons.checkDecagram, size: 12, color: JweTheme.accentTeal),
                          const SizedBox(width: 5),
                          Text(
                            g.title,
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'No completed goals recorded from yesterday.',
                    style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 10),
              Divider(color: JweTheme.accentCyan.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 10),

              // 2. Today's Goals
              Row(
                children: [
                  Icon(MdiIcons.bullseyeArrow, size: 13, color: JweTheme.accentCyan),
                  const SizedBox(width: 6),
                  Text(
                    "TODAY'S GOALS",
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.accentCyan,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Completed goals FIRST
              if (completedToday.isNotEmpty) ...[
                ...completedToday.map((g) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: JweTheme.accentTeal.withValues(alpha: 0.1),
                    border: Border.all(color: JweTheme.accentTeal.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    children: [
                      Icon(MdiIcons.checkCircleOutline, size: 14, color: JweTheme.accentTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          g.title,
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: JweTheme.accentTeal,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: JweTheme.accentTeal.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '100% DONE',
                          style: GoogleFonts.jetBrainsMono(color: JweTheme.accentTeal, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )),
              ],

              // In-Progress goals SECOND
              if (inProgressToday.isNotEmpty) ...[
                ...inProgressToday.map((g) {
                  final ratio = g.getProgressRatio();
                  final pctStr = (ratio * 100).toStringAsFixed(0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: JweTheme.accentAmber.withValues(alpha: 0.05),
                      border: Border.all(color: JweTheme.accentAmber.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(MdiIcons.progressClock, size: 13, color: JweTheme.accentAmber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                g.title,
                                style: GoogleFonts.saira(
                                  color: JweTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              '$pctStr%',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TaskDeltaProgressBar(
                          liveProgress: ratio,
                          delta: 0.0,
                          defaultColor: JweTheme.accentAmber,
                          segments: 20,
                          height: 5,
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (completedToday.isEmpty && inProgressToday.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'No daily goals set for today.',
                    style: GoogleFonts.inter(color: JweTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),

              // 3. Weekly & Monthly Goals (Today's Increment)
              if (periodGoals.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: JweTheme.accentCyan.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(MdiIcons.trendingUp, size: 13, color: JweTheme.accentCyan),
                    const SizedBox(width: 6),
                    Text(
                      "PERIOD GOALS",
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Column(
                  children: periodGoals.map((g) {
                    final incInfo = GoalBriefingHelper.getDailyBriefingIncrement(provider, g, briefingDate);
                    final liveProgress = g.getProgressRatio();
                    final delta = incInfo.ratioIncrement;
                    final defaultColor = g.scope == GoalScope.weekly ? JweTheme.accentCyan : JweTheme.accentAmber;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: JweTheme.bgDeep.withValues(alpha: 0.4),
                        border: Border.all(color: defaultColor.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: defaultColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  g.scope.name.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: defaultColor,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  g.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textWhite,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (delta > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    '+${(delta * 100).round()}%',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.accentTeal,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Text(
                                '${(liveProgress * 100).round()}%',
                                style: GoogleFonts.jetBrainsMono(
                                  color: defaultColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          TaskDeltaProgressBar(
                            liveProgress: liveProgress,
                            delta: delta,
                            defaultColor: defaultColor,
                            segments: 20,
                            height: 4,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
