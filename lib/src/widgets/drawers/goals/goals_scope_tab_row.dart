import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class GoalsScopeTabRow extends StatelessWidget {
  final GoalScope activeScope;
  final Color themeColor;
  final bool isLight;
  final ValueChanged<GoalScope> onScopeChanged;

  const GoalsScopeTabRow({
    super.key,
    required this.activeScope,
    required this.themeColor,
    required this.isLight,
    required this.onScopeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFE8E4DA) : const Color(0xFF14151E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.12)
                : JweTheme.lineSoft.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: GoalScope.values.asMap().entries.map((entry) {
            final idx = entry.key;
            final scope = entry.value;
            final isSelected = scope == activeScope;
            final label = scope.name.toUpperCase();

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  border: idx < GoalScope.values.length - 1 && !isSelected
                      ? Border(
                          right: BorderSide(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        )
                      : null,
                ),
                child: GestureDetector(
                  onTap: () => onScopeChanged(scope),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? themeColor.withValues(alpha: isLight ? 0.22 : 0.20)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(color: themeColor, width: 1.2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.orbitron(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: isSelected
                              ? (isLight ? Colors.black87 : Colors.white)
                              : (isLight
                                  ? const Color(0xFF475569)
                                  : const Color(0xFF8E9BAE)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
