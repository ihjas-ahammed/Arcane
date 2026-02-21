import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class SyncIndicator extends StatelessWidget {
  final bool isVisible;

  const SyncIndicator({super.key, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    // We use an AnimatedOpacity for smooth appearance/disappearance
    // ensuring layout doesn't jump.
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.fhAccentTeal,
                ),
              ),
              
            ],
          ),
        ),
      ),
    );
  }
}