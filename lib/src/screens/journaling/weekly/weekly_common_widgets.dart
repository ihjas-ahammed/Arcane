import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class TextBlock extends StatelessWidget {
  final String text;
  final Color accent;
  final IconData icon;
  final String label;

  const TextBlock({
    super.key,
    required this.text,
    required this.accent,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JweTheme.bgDeep.withOpacity(0.4),
            border: Border(left: BorderSide(color: accent, width: 2)),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: JweTheme.textWhite,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const SectionLabel({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class GTDItemCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const GTDItemCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.saira(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: JweTheme.textWhite,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FrictionCard extends StatelessWidget {
  final String struggle;
  final String adjustment;

  const FrictionCard({
    super.key,
    required this.struggle,
    required this.adjustment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: JweTheme.bgDeep.withOpacity(0.6),
        border: Border(left: BorderSide(color: JweTheme.accentRed, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: JweTheme.accentRed.withOpacity(0.15),
            child: Row(
              children: [
                Icon(MdiIcons.alertCircleOutline, size: 14, color: JweTheme.accentRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    struggle,
                    style: TextStyle(
                      color: JweTheme.textWhite,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(MdiIcons.arrowRightBottom, size: 16, color: JweTheme.accentAmber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    adjustment,
                    style: TextStyle(
                      color: JweTheme.textWhite,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class IdentityCard extends StatelessWidget {
  final String action;
  final String identity;

  const IdentityCard({
    super.key,
    required this.action,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.bgDeep.withOpacity(0.6),
        border: Border(left: BorderSide(color: JweTheme.accentCyan, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$action"',
            style: TextStyle(
              color: JweTheme.textMid,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(MdiIcons.checkDecagram, size: 14, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'VOTE CAST: $identity',
                  style: GoogleFonts.saira(
                    color: JweTheme.accentCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AARRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const AARRow({
    super.key,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: JweTheme.textWhite, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class EnergyColumn extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  final IconData icon;

  const EnergyColumn({
    super.key,
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('—', style: TextStyle(color: JweTheme.textMuted, fontSize: 11))
          else
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $e',
                    style: TextStyle(color: JweTheme.textMid, fontSize: 11.5, height: 1.35),
                  ),
                )),
        ],
      ),
    );
  }
}

class GratefulPersonCard extends StatelessWidget {
  final String name;
  final String reason;
  final String? category;
  final String? relation;

  const GratefulPersonCard({
    super.key,
    required this.name,
    required this.reason,
    this.category,
    this.relation,
  });

  @override
  Widget build(BuildContext context) {
    final cat = (category != null && category!.isNotEmpty)
        ? category!
        : (relation != null && relation!.isNotEmpty ? PersonInfo.getRelationCategory(relation!) : 'Allies');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.6),
        border: Border(
          left: BorderSide(color: JweTheme.accentAmber, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.saira(
                    color: JweTheme.accentAmber,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: JweTheme.accentAmber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: JweTheme.accentAmber.withOpacity(0.4), width: 0.8),
                ),
                child: Text(
                  cat.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    color: JweTheme.accentAmber,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          if (relation != null && relation!.trim().isNotEmpty && relation!.toLowerCase() != 'acquaintance') ...[
            const SizedBox(height: 2),
            Text(
              relation!.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMuted,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            reason,
            style: TextStyle(color: JweTheme.textMid, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
