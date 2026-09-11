import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class StartDayInteractionsSection extends StatelessWidget {
  final List<dynamic>? savedContacts;
  final AppProvider provider;

  const StartDayInteractionsSection({
    super.key,
    required this.savedContacts,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final displaySuggestions = <Map<String, dynamic>>[];

    if (savedContacts != null && savedContacts!.isNotEmpty) {
      for (final c in savedContacts!) {
        final map = c as Map<String, dynamic>;
        final typeStr = map['type']?.toString() ?? 'CHECK IN';
        Color color = JweTheme.accentCyan;
        IconData icon = MdiIcons.accountNetworkOutline;
        if (typeStr.contains('RECONNECT')) {
          color = JweTheme.accentAmber;
          icon = MdiIcons.accountClockOutline;
        } else if (typeStr.contains('FOLLOW UP')) {
          color = JweTheme.accentRed;
          icon = MdiIcons.heartHalfFull;
        } else if (typeStr.contains('APPRECIATION')) {
          color = JweTheme.accentTeal;
          icon = MdiIcons.heartFlash;
        }
        displaySuggestions.add({
          'name': map['name'] ?? 'Contact',
          'relation': map['relation'] ?? 'Friend',
          'type': typeStr,
          'reason': map['reason'] ?? '',
          'icon': icon,
          'color': color,
        });
      }
    } else {
      final now = DateTime.now();
      final logs = provider.reflectionLogs;
      final people = provider.chatbotMemory.people;

      if (people.isEmpty) return const SizedBox.shrink();

      final recommendations = <Map<String, dynamic>>[];

      for (final person in people) {
        final personNameLower = person.name.toLowerCase();
        final personLogs = logs.where((l) {
          final text = '${l.trigger} ${l.emotion} ${l.reason} ${l.action}'.toLowerCase();
          return text.contains(personNameLower);
        }).toList();

        personLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (personLogs.isNotEmpty) {
          final latestLog = personLogs.first;
          final daysSince = now.difference(latestLog.timestamp).inDays;

          if (daysSince > 7 && daysSince <= 21) {
            recommendations.add({
              'name': person.name,
              'relation': person.relation,
              'type': 'RECONNECT',
              'reason': 'No contact recorded in $daysSince days. Plan a check-in.',
              'icon': MdiIcons.accountClockOutline,
              'color': JweTheme.accentAmber,
            });
          } else if (daysSince <= 7) {
            final negEmotions = ['stressed', 'anxious', 'sad', 'angry', 'overwhelmed', 'tired', 'frustrated', 'worried'];
            final isNeg = negEmotions.any((e) => latestLog.emotion.toLowerCase().contains(e) || latestLog.reason.toLowerCase().contains(e));
            if (isNeg) {
              recommendations.add({
                'name': person.name,
                'relation': person.relation,
                'type': 'FOLLOW UP',
                'reason': 'Follow up regarding recent tension or stress.',
                'icon': MdiIcons.heartHalfFull,
                'color': JweTheme.accentRed,
              });
            } else {
              recommendations.add({
                'name': person.name,
                'relation': person.relation,
                'type': 'APPRECIATION',
                'reason': 'Keep the momentum going. Share a quick word of support.',
                'icon': MdiIcons.heartFlash,
                'color': JweTheme.accentTeal,
              });
            }
          }
        } else {
          recommendations.add({
            'name': person.name,
            'relation': person.relation,
            'type': 'STAY IN TOUCH',
            'reason': 'No recent reflection logs mention them. Ping to catch up.',
            'icon': MdiIcons.accountNetworkOutline,
            'color': JweTheme.accentCyan,
          });
        }
      }

      displaySuggestions.addAll(recommendations.take(3));
    }

    if (displaySuggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(children: [
          Container(width: 3, height: 10, color: JweTheme.accentCyan),
          const SizedBox(width: 8),
          Icon(MdiIcons.accountMultipleOutline, size: 11, color: JweTheme.accentCyan),
          const SizedBox(width: 5),
          Text(
            'SUGGESTED INTERACTIONS (PEOPLE)',
            style: GoogleFonts.jetBrainsMono(
              color: JweTheme.accentCyan,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JweTheme.bgDeep.withValues(alpha: 0.65),
            border: Border.all(color: JweTheme.accentCyan.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: displaySuggestions.map((s) {
              final color = s['color'] as Color;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(s['icon'] as IconData, size: 14, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                (s['name'] as String).toUpperCase(),
                                style: GoogleFonts.saira(
                                  color: JweTheme.textWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${s['relation']})',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.textMuted,
                                  fontSize: 8.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  border: Border.all(color: color.withValues(alpha: 0.5)),
                                  color: color.withValues(alpha: 0.08),
                                ),
                                child: Text(
                                  s['type'] as String,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: color,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s['reason'] as String,
                            style: GoogleFonts.inter(
                              color: JweTheme.textMid,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
