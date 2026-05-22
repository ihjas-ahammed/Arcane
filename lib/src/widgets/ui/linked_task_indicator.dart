import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class LinkedTaskIndicator extends StatelessWidget {
  final String label;
  final VoidCallback? onUnlink;

  const LinkedTaskIndicator({
    super.key,
    required this.label,
    this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.fhAccentPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.fhAccentPurple.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MdiIcons.linkVariant, size: 12, color: AppTheme.fhAccentPurple),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppTheme.fhAccentPurple,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontDisplay,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onUnlink != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onUnlink,
              child: Icon(Icons.close, size: 12, color: AppTheme.fhTextSecondary),
            )
          ]
        ],
      ),
    );
  }
}