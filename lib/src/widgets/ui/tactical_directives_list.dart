import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TacticalDirectivesList extends StatelessWidget {
  final List<String> directives;

  const TacticalDirectivesList({super.key, required this.directives});

  @override
  Widget build(BuildContext context) {
    if (directives.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TACTICAL DIRECTIVES",
          style: TextStyle(
            color: AppTheme.fhAccentPurple,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5
          ),
        ),
        const SizedBox(height: 12),
        ...directives.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Icon(MdiIcons.chevronRight, size: 14, color: AppTheme.fhAccentPurple),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d,
                  style: const TextStyle(
                    color: AppTheme.fhTextPrimary,
                    fontSize: 13,
                    height: 1.3,
                    fontFamily: "RobotoCondensed"
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}