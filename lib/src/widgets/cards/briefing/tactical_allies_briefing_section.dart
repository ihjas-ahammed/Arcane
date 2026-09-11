import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class TacticalAlliesBriefingSection extends StatelessWidget {
  final List<dynamic> gratefulPeople;
  final DateTime? date;

  const TacticalAlliesBriefingSection({
    super.key,
    required this.gratefulPeople,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    if (gratefulPeople.isEmpty) return const SizedBox.shrink();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(children: [
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
        ]),
        const SizedBox(height: 10),
        ...gratefulPeople.map((person) {
          final p = person as Map<String, dynamic>;
          final pName = p['name'] as String? ?? '';
          final express = p['express'] as String? ?? '';
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
    );
  }
}
