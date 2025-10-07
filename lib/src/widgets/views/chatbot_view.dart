// lib/src/widgets/views/chatbot_view.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/game_provider.dart';
import 'package:arcane/src/models/game_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // For rendering graphs
import 'dart:convert'; // For jsonDecode if AI provides complex data

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
      // Ensure chatbot memory is initialized/loaded when view is first shown
      Provider.of<GameProvider>(context, listen: false).initializeChatbotMemory();
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

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    await gameProvider.sendMessageToChatbot(messageText);

    if (mounted) {
      setState(() => _isSending = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final theme = Theme.of(context);
    final chatbotMemory = gameProvider.chatbotMemory;
    final Color dynamicAccent = gameProvider.getSelectedTask()?.taskColor ?? theme.colorScheme.secondary;


    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Restart Session Button
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(MdiIcons.refresh, size: 16, color: AppTheme.fhTextSecondary),
                label: Text("Restart Session", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                            title: Text("Restart Chat?", style: TextStyle(color: dynamicAccent)),
                            content: const Text("This will clear the current conversation history, but remembered items and summaries will remain. Continue?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: ElevatedButton.styleFrom(backgroundColor: dynamicAccent),
                                child: Text("Restart", style: TextStyle(color: ThemeData.estimateBrightnessForColor(dynamicAccent) == Brightness.dark ? AppTheme.fhTextPrimary : AppTheme.fhBgDark)),
                              ),
                            ],
                          ));
                  if (confirm == true) {
                    gameProvider.chatbotMemory.conversationHistory.clear();
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
                      Icon(MdiIcons.robotHappyOutline, size: 48, color: dynamicAccent.withOpacity(0.7)),
                      const SizedBox(height: 16),
                      Text(
                        "Arcane Advisor Online",
                        style: theme.textTheme.headlineSmall?.copyWith(color: dynamicAccent),
                      ),
                       const SizedBox(height: 8),
                      Text(
                        "Ask about your past week's summary, completed goals, or tell me things to 'Remember'.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.fhTextSecondary),
                      ),
                    ],
                  ))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: chatbotMemory.conversationHistory.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                       if (_isSending && index == chatbotMemory.conversationHistory.length) {
                        return _buildMessageBubble(
                          ChatbotMessage(
                            id: 'typing',
                            text: '...',
                            sender: MessageSender.bot,
                            timestamp: DateTime.now(),
                          ),
                          theme,
                          dynamicAccent,
                          true 
                        );
                      }
                      final message = chatbotMemory.conversationHistory[index];
                      return _buildMessageBubble(message, theme, dynamicAccent, false);
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
                      hintText: 'Send a message to Arcane Advisor...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide(color: AppTheme.fhBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide(color: dynamicAccent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: dynamicAccent))
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

  Widget _buildMessageBubble(ChatbotMessage message, ThemeData theme, Color dynamicAccent, bool isTyping) {
    final bool isUser = message.sender == MessageSender.user;
    final Color bubbleColor = isUser ? dynamicAccent : AppTheme.fhBgMedium;
    final Color textColor = isUser 
        ? (ThemeData.estimateBrightnessForColor(dynamicAccent) == Brightness.dark ? AppTheme.fhTextPrimary : AppTheme.fhBgDark) 
        : AppTheme.fhTextPrimary;
    
    final CrossAxisAlignment crossAxisAlignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final MainAxisAlignment mainAxisAlignment = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;


    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        children: [
          Flexible( // Makes sure the bubble doesn't overflow
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Max width for bubble
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                ),
                border: Border.all(color: bubbleColor.withOpacity(0.5), width: 0.5)
              ),
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(color: textColor, fontSize: 13.5, height: 1.4),
                  ),
                  if (message.uiPayload != null) ...[
                    const SizedBox(height: 8),
                    _buildDynamicUiWidget(message.uiPayload!, theme, dynamicAccent),
                  ],
                  if (!isTyping) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(message.timestamp.toLocal()),
                      style: theme.textTheme.labelSmall?.copyWith(color: textColor.withOpacity(0.7), fontSize: 9),
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

  Widget _buildDynamicUiWidget(DynamicUiPayload payload, ThemeData theme, Color dynamicAccent) {
    switch (payload.type) {
      case DynamicUiType.graph:
        return _buildGraphFromPayload(payload.data, theme, dynamicAccent);
      case DynamicUiType.unknown:
      default:
        return Text(
          "[Dynamic UI Error: Unknown payload type or data error. Raw: ${jsonEncode(payload.data)}]",
          style: TextStyle(color: AppTheme.fhAccentRed.withOpacity(0.8), fontSize: 10, fontStyle: FontStyle.italic),
        );
    }
  }

  Widget _buildGraphFromPayload(Map<String, dynamic> data, ThemeData theme, Color dynamicAccent) {
    final String graphType = data['graphType'] as String? ?? '';
    final String title = data['title'] as String? ?? 'Graph';
    final String source = data['source'] as String? ?? '';
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    if (graphType == 'emotion_trend_bar' && source == 'emotion_logs') {
      List<MapEntry<String, double>> dailyAverageEmotions = [];
      final today = DateTime.now();
      for (int i = 6; i >= 0; i--) { // Last 7 days
        final date = today.subtract(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        final logsForDay = gameProvider.getEmotionLogsForDate(dateString);
        if (logsForDay.isNotEmpty) {
          double sum = logsForDay.fold(0, (prev, log) => prev + log.rating);
          dailyAverageEmotions.add(MapEntry(dateString, sum / logsForDay.length));
        } else {
           dailyAverageEmotions.add(MapEntry(dateString, 0.0)); // Represent no data as 0
        }
      }

      if (dailyAverageEmotions.where((e) => e.value > 0).isEmpty) {
        return Text("Not enough emotion data for the past 7 days to display a trend.", style: theme.textTheme.bodySmall);
      }

      return SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 5.5,
            minY: 0,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppTheme.fhBgMedium,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final dateEntry = dailyAverageEmotions[group.x.toInt()];
                  return BarTooltipItem(
                    '${DateFormat('MMM d').format(DateTime.parse(dateEntry.key))}\n',
                    TextStyle(color: dynamicAccent, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Avg: ${dateEntry.value.toStringAsFixed(1)}/5',
                        style: TextStyle(color: dynamicAccent, fontWeight: FontWeight.w500, fontFamily: AppTheme.fontBody),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final date = DateTime.parse(dailyAverageEmotions[value.toInt()].key);
                    return SideTitleWidget(
                      meta: meta,
                      space: 4.0,
                      child: Text(DateFormat('E').format(date).substring(0,1), style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  },
                  reservedSize: 18,
                ),
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 28, getTitlesWidget: (v,m) => Text(v.toInt().toString(), style: TextStyle(fontSize:10, color: AppTheme.fhTextSecondary)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: dailyAverageEmotions.asMap().entries.map((entry) {
              final index = entry.key;
              final avgRating = entry.value.value;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: avgRating > 0 ? avgRating : 0.1, // Show a tiny bar for 0 to indicate data point
                    color: avgRating > 0 ? dynamicAccent.withOpacity(0.8) : AppTheme.fhTextDisabled.withOpacity(0.3),
                    width: 16,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3)),
                  ),
                ],
              );
            }).toList(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.fhBorderColor.withOpacity(0.1), strokeWidth: 0.8),
            ),
          ),
        ),
      );
    }
    return Text(
      "[Dynamic UI Error: Graph type '$graphType' or source '$source' not supported. Data: ${jsonEncode(data)}]",
      style: TextStyle(color: AppTheme.fhAccentRed.withOpacity(0.8), fontSize: 10, fontStyle: FontStyle.italic),
    );
  }

   @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}