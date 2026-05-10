import 'package:flutter/material.dart';
import 'package:missions/src/widgets/views/chatbot_view.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appProvider.initializeChatbotMemory();
    });

    // Simply return the view, no Scaffold/AppBar needed as it's inside the Home Scaffold
    return Container(
      color: AppTheme.fhBgDeepDark,
      child: const ChatbotView(),
    );
  }
}