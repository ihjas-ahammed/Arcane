import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/valorant/valorant_expansion_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TacticalBriefingCard extends StatelessWidget {
  final Map<String, dynamic> briefingData;
  final VoidCallback? onSave;
  final bool isSaved;

  const TacticalBriefingCard({
    super.key,
    required this.briefingData,
    this.onSave,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    final summary = briefingData['summary'] as String? ?? "No intel available.";
    final improvements = briefingData['improvements'] as List<dynamic>? ?? [];

    return ValorantExpansionCard(
      title: "TACTICAL BRIEFING",
      icon: MdiIcons.clipboardTextOutline,
      accentColor: AppTheme.fhAccentGold,
      trailing: !isSaved && onSave != null
          ? InkWell(
              onTap: onSave,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.fhAccentTeal),
                    color: AppTheme.fhAccentTeal.withValues(alpha: 0.1)),
                child: const Text("SAVE",
                    style: TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            )
          : (isSaved
              ? Icon(MdiIcons.checkBold, color: AppTheme.fhAccentTeal, size: 16)
              : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: const TextStyle(
                color: AppTheme.fhTextSecondary,
                height: 1.5,
                fontSize: 13,
                fontStyle: FontStyle.italic),
          ).animate().fadeIn(duration: 500.ms),
          if (improvements.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 12),
            const Text(
              "IMPROVEMENTS",
              style: TextStyle(
                  color: AppTheme.fhAccentGold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),
            ...improvements.map((imp) {
              final map = imp as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(MdiIcons.arrowUpBold,
                        size: 12, color: AppTheme.fhAccentGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(children: [
                          TextSpan(
                              text: "${map['ability']}: ",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.fhTextPrimary,
                                  fontSize: 12)),
                          TextSpan(
                              text: map['insight'] ?? '',
                              style: const TextStyle(
                                  color: AppTheme.fhTextSecondary,
                                  fontSize: 12))
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    );
  }
}