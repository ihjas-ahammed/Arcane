import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/journaling/person_detail_screen.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class MonthlyRelationshipAuditSection extends StatelessWidget {
  final List<dynamic> relationshipAudit;
  final AppProvider provider;

  const MonthlyRelationshipAuditSection({
    super.key,
    required this.relationshipAudit,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (relationshipAudit.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudSectionHead(label: 'RELATIONSHIP AUDIT', code: 'ALY', accent: HudTone.amber),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Builder(builder: (context) {
            final grouped = <String, List<Map<String, dynamic>>>{};
            for (final r in relationshipAudit) {
              final m = r as Map<String, dynamic>;
              final pName = m['name']?.toString() ?? '';
              final existingPerson = provider.chatbotMemory.people.firstWhereOrNull(
                  (e) => e.name.toLowerCase().trim() == pName.toLowerCase().trim());
              final category = existingPerson != null
                  ? PersonInfo.getRelationCategory(existingPerson.relation).toUpperCase()
                  : 'ACQUAINTANCES & OTHERS';
              grouped.putIfAbsent(category, () => []).add(m);
            }

            return Column(
              children: grouped.entries.map((entry) {
                final category = entry.key;
                final members = entry.value;
                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      '$category (${members.length})',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    children: members.map((m) {
                      final pName = m['name']?.toString() ?? 'Unknown';
                      final existingPerson = provider.chatbotMemory.people.firstWhereOrNull(
                          (e) => e.name.toLowerCase().trim() == pName.toLowerCase().trim());

                      return InkWell(
                        onTap: existingPerson != null
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PersonDetailScreen(personId: existingPerson.id),
                                  ),
                                )
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: JweTheme.bgBase.withValues(alpha: 0.6),
                            border: Border(left: BorderSide(color: JweTheme.accentAmber, width: 2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    pName.toUpperCase(),
                                    style: GoogleFonts.saira(
                                      color: JweTheme.accentAmber,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (existingPerson != null)
                                    Icon(MdiIcons.chevronRight, size: 14, color: JweTheme.accentAmber),
                                ],
                              ),
                              if ((m['trend']?.toString() ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  m['trend']?.toString() ?? '',
                                  style: TextStyle(
                                      color: JweTheme.textMid,
                                      fontSize: 12,
                                      height: 1.4),
                                ),
                              ],
                              if ((m['action']?.toString() ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(MdiIcons.sendOutline, size: 11, color: JweTheme.accentTeal),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        m['action']?.toString() ?? '',
                                        style: TextStyle(
                                            color: JweTheme.accentTeal,
                                            fontSize: 11.5,
                                            fontStyle: FontStyle.italic,
                                            height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0);
          }),
        ),
      ],
    );
  }
}
