import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class DateNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const DateNavBtn({
    super.key,
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: JweTheme.border)),
        ),
        child: Icon(
          icon,
          color: enabled
              ? JweTheme.textMid
              : JweTheme.textMuted.withValues(alpha: 0.3),
          size: 20,
        ),
      ),
    );
  }
}
