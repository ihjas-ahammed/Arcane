import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
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
              child: Icon(MdiIcons.creation, size: 16, color: accentColor)
            ),
            
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78),
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
                      color: bubbleColor.withValues(alpha: 0.5), width: 0.5)),
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTyping)
                    Text(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor, fontSize: 13.5, height: 1.4),
                    )
                  else
                    MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                        h1: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        h2: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                        h3: TextStyle(color: textColor, fontSize: 14.5, fontWeight: FontWeight.bold),
                        code: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          color: isUser ? textColor : AppTheme.fhAccentPurple,
                          backgroundColor: isUser ? Colors.black12 : AppTheme.fhBgDark,
                        ),
                        codeblockPadding: const EdgeInsets.all(8),
                        codeblockDecoration: BoxDecoration(
                          color: isUser ? Colors.black26 : AppTheme.fhBgDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (isUser ? textColor : AppTheme.fhAccentPurple).withValues(alpha: 0.2)),
                        ),
                        listBullet: TextStyle(color: textColor, fontSize: 13.5),
                        strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(left: BorderSide(color: isUser ? textColor : AppTheme.fhAccentPurple, width: 3)),
                        ),
                        blockquote: TextStyle(color: textColor.withValues(alpha: 0.85), fontStyle: FontStyle.italic),
                        tableBody: TextStyle(color: textColor, fontSize: 12),
                        tableHead: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                        tableBorder: TableBorder.all(color: textColor.withValues(alpha: 0.2), width: 0.5),
                      ),
                    ),
                  if (!isTyping) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(message.timestamp.toLocal()),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: textColor.withValues(alpha: 0.7), fontSize: 9),
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