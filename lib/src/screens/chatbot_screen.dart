// lib/src/screens/chatbot_screen.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/widgets/views/chatbot_view.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appProvider.initializeChatbotMemory();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arcane Advisor'),
        backgroundColor: AppTheme.fhBgMedium,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.secondary.withOpacity(0.3),
                AppTheme.fhBgMedium,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: const ChatbotView(),
    );
  }
}