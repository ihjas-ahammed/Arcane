// lib/src/widgets/views/chatbot_view.dart
import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/ui/nora_message_bubble.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:convert';

class ChatbotView extends StatefulWidget {
  const ChatbotView({super.key});

  @override
  State<ChatbotView> createState() => _ChatbotViewState();
}

class _ChatbotViewState extends State<ChatbotView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false)
          .initializeChatbotMemory();
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(covariant ChatbotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.sendMessageToChatbot(messageText);

    if (mounted) {
      setState(() => _isSending = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    final chatbotMemory = appProvider.chatbotMemory;
    final Color dynamicAccent =
        appProvider.getSelectedTask()?.taskColor ?? theme.colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(MdiIcons.refresh,
                    size: 16, color: AppTheme.fhTextSecondary),
                label: const Text("Restart Session",
                    style: TextStyle(
                        color: AppTheme.fhTextSecondary, fontSize: 12)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                            title: Text("Restart Chat?",
                                style: TextStyle(color: dynamicAccent)),
                            content: const Text(
                                "This will clear the current conversation history, but remembered items and summaries will remain. Continue?"),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text("Cancel")),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: dynamicAccent),
                                child: Text("Restart",
                                    style: TextStyle(
                                        color: ThemeData
                                                    .estimateBrightnessForColor(
                                                        dynamicAccent) ==
                                                Brightness.dark
                                            ? AppTheme.fhTextPrimary
                                            : AppTheme.fhBgDark)),
                              ),
                            ],
                          ));
                  if (confirm == true) {
                    appProvider.chatbotMemory.conversationHistory.clear();
                  }
                },
              ),
            ),
          ),
          Expanded(
            child: chatbotMemory.conversationHistory.isEmpty && !_isSending
                ? Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(MdiIcons.robotHappyOutline,
                          size: 48,
                          color: dynamicAccent.withValues(alpha: 0.7)),
                      const SizedBox(height: 16),
                      Text(
                        "Missions Advisor Online",
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(color: dynamicAccent),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Ask about your past week's summary, completed goals, or tell me things to 'Remember'.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.fhTextSecondary),
                      ),
                    ],
                  ))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: chatbotMemory.conversationHistory.length +
                        (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isSending &&
                          index == chatbotMemory.conversationHistory.length) {
                        return NoraMessageBubble(
                          message: ChatbotMessage(
                            id: 'typing',
                            text: '...',
                            sender: MessageSender.bot,
                            timestamp: DateTime.now(),
                          ),
                          accentColor: dynamicAccent,
                          isTyping: true,
                        );
                      }
                      final message = chatbotMemory.conversationHistory[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NoraMessageBubble(
                            message: message, 
                            accentColor: dynamicAccent, 
                            isTyping: false
                          ),
                          if (message.uiPayload != null)
                             _buildDynamicUiWidget(message.uiPayload!, theme, dynamicAccent),
                        ],
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Send a message to Missions Advisor...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide:
                            const BorderSide(color: AppTheme.fhBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide:
                            BorderSide(color: dynamicAccent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(
                        color: AppTheme.fhTextPrimary, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: dynamicAccent))
                      : Icon(MdiIcons.sendCircleOutline, color: dynamicAccent),
                  onPressed: _isSending ? null : _sendMessage,
                  iconSize: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicUiWidget(
      DynamicUiPayload payload, ThemeData theme, Color dynamicAccent) {
    switch (payload.type) {
      case DynamicUiType.graph:
        return _buildGraphFromPayload(payload.data, theme, dynamicAccent);
      case DynamicUiType.unknown:
        return Text(
          "[Dynamic UI Error: Unknown payload type or data error. Raw: ${jsonEncode(payload.data)}]",
          style: TextStyle(
              color: AppTheme.fhAccentRed.withValues(alpha: 0.8),
              fontSize: 10,
              fontStyle: FontStyle.italic),
        );
    }
  }

  Widget _buildGraphFromPayload(
      Map<String, dynamic> data, ThemeData theme, Color dynamicAccent) {
    final String graphType = data['graphType'] as String? ?? '';
    final String source = data['source'] as String? ?? '';

    // Emotion tracking removed, returning error for legacy emotion graphs.
    if (graphType == 'emotion_trend_bar' || source == 'emotion_logs') {
      return const Text("Emotion tracking is no longer supported.",
          style: TextStyle(
              color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic));
    }

    return Text(
      "[Dynamic UI Error: Graph type '$graphType' or source '$source' not supported. Data: ${jsonEncode(data)}]",
      style: TextStyle(
          color: AppTheme.fhAccentRed.withValues(alpha: 0.8),
          fontSize: 10,
          fontStyle: FontStyle.italic),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}