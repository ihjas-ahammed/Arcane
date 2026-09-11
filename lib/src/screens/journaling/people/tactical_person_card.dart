import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';

class TacticalPersonCard extends StatelessWidget {
  final PersonInfo person;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  // Selection fields
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const TacticalPersonCard({
    super.key,
    required this.person,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color categoryColor = _getCategoryColor(person.relation);

    // Parse level details if available
    int level = 1;
    String title = "Entity";
    if (person.details != null && person.details!.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(person.details!);
        level = parsed['level'] ?? 1;
        title = parsed['title'] ?? "Entity";
      } catch (_) {}
    }

    final rangeText = person.scanRangeStart != null && person.scanRangeEnd != null
        ? "${DateFormat('MM/dd').format(person.scanRangeStart!)} - ${DateFormat('MM/dd').format(person.scanRangeEnd!)}"
        : "No active scan";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? ArcSurfaces.deepPanelRaised : AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? PersonInfoTheme.spideyCyan : ArcStrokes.steel,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              children: [
                // Glowing Left side Category Indicator (or checkbox if selecting)
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: PersonInfoTheme.spideyCyan,
                    checkColor: JweTheme.onAccent,
                    side: BorderSide(color: ArcStrokes.steel),
                    onChanged: onSelectedChanged,
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withValues(alpha: 0.8),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Holographic Circle Avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.08),
                    border: Border.all(color: categoryColor.withValues(alpha: 0.3), width: 1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      person.name.isNotEmpty ? person.name[0].toUpperCase() : "?",
                      style: GoogleFonts.rajdhani(
                        color: categoryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Relation & Age & Scan info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.fhTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              person.relation.toUpperCase(),
                              style: GoogleFonts.rajdhani(
                                color: categoryColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (person.manualAge != null) ...[
                            Text(
                              "AGE: ${person.manualAge}",
                              style: GoogleFonts.rajdhani(
                                color: AppTheme.fhTextSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              "SCAN: $rangeText",
                              style: GoogleFonts.rajdhani(
                                color: AppTheme.fhTextDisabled,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // AI Level Indicators
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: ArcStrokes.steel),
                        borderRadius: BorderRadius.circular(4),
                        color: ArcSurfaces.deepPanel,
                      ),
                      child: Text(
                        "LVL $level",
                        style: GoogleFonts.rajdhani(
                          color: PersonInfoTheme.spideyCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String relation) {
    final cat = PersonInfo.getRelationCategory(relation);
    switch (cat) {
      case 'Family & Partner':
        return Colors.pinkAccent;
      case 'Friends':
        return Colors.greenAccent;
      case 'Professional & Mentors':
        return PersonInfoTheme.spideyCyan;
      default:
        return AppTheme.fhTextDisabled;
    }
  }
}
