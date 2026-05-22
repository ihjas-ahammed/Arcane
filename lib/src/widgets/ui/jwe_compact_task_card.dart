import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class JweCompactTaskCard extends StatelessWidget {
  final MainTask task;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const JweCompactTaskCard({
    super.key,
    required this.task,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? JweTheme.accentCyan.withOpacity(0.1) : JweTheme.panel,
            border: Border(
              left: BorderSide(color: isSelected ? JweTheme.accentCyan : JweTheme.textMuted, width: 3),
              top: const BorderSide(color: JweTheme.border),
              right: const BorderSide(color: JweTheme.border),
              bottom: const BorderSide(color: JweTheme.border),
            ),
          ),
          child: Row(
            children: [
              Icon(
                MdiIcons.archiveOutline, 
                color: isSelected ? JweTheme.accentCyan : JweTheme.textMuted, 
                size: 18
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        color: isSelected ? JweTheme.textWhite : JweTheme.textMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                        decoration: TextDecoration.lineThrough,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "STANDBY / ARCHIVED",
                      style: TextStyle(
                        color: JweTheme.textMuted.withOpacity(0.7),
                        fontSize: 9,
                        fontFamily: 'RobotoMono',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}