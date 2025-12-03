import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isFullWidth;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: isFullWidth ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.fhTextSecondary, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.w500)),
            if (isFullWidth) ...[
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: AppTheme.fhTextSecondary, size: 14),
            ]
          ],
        ),
      ),
    );
  }
}