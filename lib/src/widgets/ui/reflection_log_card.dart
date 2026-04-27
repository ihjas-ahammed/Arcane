import 'package:flutter/material.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ReflectionLogCard extends StatelessWidget {
  final ReflectionLog log;
  final bool isSelected;

  const ReflectionLogCard({
    super.key, 
    required this.log,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalXp = log.xpGained.values.fold(0, (sum, xp) => sum + xp);

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? JweTheme.accentCyan.withOpacity(0.1) : JweTheme.panel,
        border: Border.all(
          color: isSelected ? JweTheme.accentCyan : JweTheme.border, 
          width: isSelected ? 2.0 : 1.0
        ),
      ),
      child: Stack(
        children:[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[
                    Expanded(
                      child: Text(
                        log.trigger.isNotEmpty ? log.trigger.toUpperCase() : "REFLECTION LOG",
                        style: GoogleFonts.chakraPetch(
                          color: isSelected ? JweTheme.accentCyan : JweTheme.textWhite, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 16
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (totalXp > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: JweTheme.accentAmber.withOpacity(0.1),
                          border: Border.all(color: JweTheme.accentAmber.withOpacity(0.5))
                        ),
                        child: Text(
                          "+$totalXp XP", 
                          style: const TextStyle(
                            color: JweTheme.accentAmber, 
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                            fontFamily: 'RobotoMono'
                          )
                        ),
                      )
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(log.timestamp),
                  style: const TextStyle(color: JweTheme.textMuted, fontSize: 10, fontFamily: 'RobotoMono'),
                ),
                const SizedBox(height: 12),
                if (log.emotion.isNotEmpty)
                   _buildRow("HOW", log.emotion),
                if (log.reason.isNotEmpty)
                   _buildRow("WHY", log.reason),
                if (log.action.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "ACTION: ${log.action}",
                    style: const TextStyle(
                      color: JweTheme.textWhite, 
                      fontSize: 12, 
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (log.aiFeedback.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: const Border(left: BorderSide(color: JweTheme.accentCyan, width: 2))
                    ),
                    child: Text(
                      log.aiFeedback,
                      style: const TextStyle(
                        color: JweTheme.textMuted, 
                        fontSize: 11, 
                        fontStyle: FontStyle.italic,
                        height: 1.4
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                ]
              ],
            ),
          ),
          if (isSelected)
            const Positioned(
              right: 16,
              bottom: 16,
              child: Icon(Icons.check_circle, color: JweTheme.accentCyan, size: 24),
            )
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                color: JweTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: JweTheme.textWhite,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}