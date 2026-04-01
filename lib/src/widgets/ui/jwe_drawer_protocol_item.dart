import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:google_fonts/google_fonts.dart';

class JweDrawerProtocolItem extends StatelessWidget {
  final MainTask task;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final IconData icon;

  const JweDrawerProtocolItem({
    super.key,
    required this.task,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = task.taskColor;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : JweTheme.panel,
            border: Border(
              left: BorderSide(color: isSelected ? color : JweTheme.border, width: isSelected ? 4 : 2),
              top: BorderSide(color: isSelected ? color.withOpacity(0.3) : JweTheme.border),
              right: BorderSide(color: isSelected ? color.withOpacity(0.3) : JweTheme.border),
              bottom: BorderSide(color: isSelected ? color.withOpacity(0.3) : JweTheme.border),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.2) : Colors.black26,
                  border: Border.all(color: isSelected ? color : Colors.transparent),
                ),
                child: Icon(icon, size: 20, color: isSelected ? color : JweTheme.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name.toUpperCase(),
                      style: GoogleFonts.chakraPetch(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isSelected ? JweTheme.textWhite : JweTheme.textMuted,
                        letterSpacing: 1.0,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.theme.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9, 
                        color: isSelected ? color : JweTheme.textMuted.withOpacity(0.7),
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'RobotoMono'
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