import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';

class SettingsSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color? iconColor;

  const SettingsSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ??
        (appProvider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed);

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: effectiveIconColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Divider(
              height: 24,
              thickness: 0.5,
              color: AppTheme.fhBorderColor.withValues(alpha: 0.5),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
