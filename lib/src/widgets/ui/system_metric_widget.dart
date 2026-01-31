import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class SystemMetricWidget extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;

  const SystemMetricWidget({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? _determineColor(value);
    final clampedValue = value.clamp(0, 100);
    final widthFactor = clampedValue / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppTheme.fhTextPrimary.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              "$value%",
              style: TextStyle(
                color: effectiveColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'RobotoMono',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.fhBgDeepDark,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  decoration: BoxDecoration(
                    color: effectiveColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: effectiveColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                      )
                    ]
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _determineColor(int val) {
    if (val >= 80) return AppTheme.fhAccentTeal;
    if (val >= 50) return AppTheme.fhAccentGold;
    return AppTheme.fhAccentRed;
  }
}