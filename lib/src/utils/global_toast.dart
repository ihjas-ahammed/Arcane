import 'package:flutter/material.dart';

import 'package:missions/src/theme/app_theme.dart';

/// Wired into [MaterialApp.scaffoldMessengerKey] so a toast can be shown from
/// anywhere — notably from notification action handlers that have no
/// BuildContext of their own.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Show a short snackbar-style toast. No-op when no UI is mounted (e.g. the
/// action fired while the app was killed) — the notification body still
/// reflects what happened.
void showGlobalToast(String message) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                color: AppTheme.fhTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.fhBgDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppTheme.fhBorderColor),
        ),
      ),
    );
}
