import 'package:flutter/material.dart';
import 'package:arcane/src/models/value_models.dart';
import 'package:arcane/src/theme/app_theme.dart';

class LifeValueCard extends StatelessWidget {
  final LifeValue value;
  final VoidCallback onTap;

  const LifeValueCard({super.key, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double progress = value.score / 100.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: AppTheme.fhBgDeepDark,
                    color: _getScoreColor(value.score),
                  ),
                ),
                Icon(
                  value.icon,
                  size: 28,
                  color: AppTheme.fhTextPrimary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value.title.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.fhTextPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${value.score}% Aligned",
              style: TextStyle(
                color: _getScoreColor(value.score),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.fhAccentGreen;
    if (score >= 50) return AppTheme.fhAccentGold;
    return AppTheme.fhAccentRed;
  }
}