import 'package:flutter/material.dart';
import 'package:arcane/src/widgets/views/settings_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return  Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: SettingsView(),
      ),
    );
  }
}