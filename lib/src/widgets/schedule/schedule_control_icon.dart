import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class ScheduleControlIcon extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? accent;
  final String? tooltip;
  final bool loading;
  final VoidCallback? onLongPress;

  const ScheduleControlIcon({
    super.key,
    this.icon,
    this.onTap,
    this.onLongPress,
    this.accent,
    this.tooltip,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && onLongPress == null;
    final activeAccent = accent ?? JweTheme.accentCyan;
    Widget child = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: disabled ? JweTheme.lineSoft : activeAccent.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: loading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.6, valueColor: AlwaysStoppedAnimation<Color>(activeAccent)),
            )
          : Icon(icon, size: 16, color: disabled ? JweTheme.textMuted : activeAccent),
    );
    if (onTap != null || onLongPress != null) {
      child = InkWell(onTap: onTap, onLongPress: onLongPress, child: child);
    }
    if (tooltip != null) child = Tooltip(message: tooltip!, child: child);
    return child;
  }
}
