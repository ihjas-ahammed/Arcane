import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';

class SyncIndicator extends StatelessWidget {
  final bool isVisible;

  const SyncIndicator({super.key, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.fhAccentTeal.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.fhAccentTeal,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "SYNCING CLOUD...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: AppTheme.fontDisplay
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}