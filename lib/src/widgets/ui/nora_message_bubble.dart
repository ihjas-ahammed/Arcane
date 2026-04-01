import 'package:flutter/material.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';

class NoraMessageBubble extends StatelessWidget {
  final ChatbotMessage message;
  final Color accentColor;
  final bool isTyping;

  const NoraMessageBubble({
    super.key,
    required this.message,
    required this.accentColor,
    required this.isTyping,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    final theme = Theme.of(context);
    
    final Color bubbleColor = isUser ? accentColor : AppTheme.fhBgMedium;
    final Color textColor = isUser
        ? (ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
            ? AppTheme.fhTextPrimary
            : AppTheme.fhBgDark)
        : AppTheme.fhTextPrimary;

    final CrossAxisAlignment crossAxisAlignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final MainAxisAlignment mainAxisAlignment =
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) 
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 4), 
              child: Icon(MdiIcons.brain, size: 16, color: accentColor)
            ),
            
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                  border: Border.all(
                      color: bubbleColor.withOpacity(0.5), width: 0.5)),
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor, fontSize: 13.5, height: 1.4),
                  ),
                  if (!isTyping) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(message.timestamp.toLocal()),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: textColor.withOpacity(0.7), fontSize: 9),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}