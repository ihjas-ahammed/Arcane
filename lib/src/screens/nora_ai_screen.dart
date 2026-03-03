import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';

class NoraAiScreen extends StatefulWidget {
  const NoraAiScreen({super.key});

  @override
  State<NoraAiScreen> createState() => _NoraAiScreenState();
}

class _NoraAiScreenState extends State<NoraAiScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
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
    await appProvider.sendNoraMessage(messageText);

    if (mounted) {
      setState(() => _isSending = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _showNewSessionDialog(AppProvider provider) {
    String title = "Session ${DateFormat('MM-dd').format(DateTime.now())}";
    String tone = "Assistant";
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime endDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: AppTheme.fhBgMedium,
            title: const Text("INITIALIZE NORA LINK", style: TextStyle(color: AppTheme.fhAccentPurple, fontFamily: AppTheme.fontDisplay)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: "Thread Title"),
                    onChanged: (val) => title = val,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: tone,
                    decoration: const InputDecoration(labelText: "Persona Tone"),
                    dropdownColor: AppTheme.fhBgDark,
                    items: const [
                      DropdownMenuItem(value: "Assistant", child: Text("Assistant")),
                      DropdownMenuItem(value: "Therapist", child: Text("Therapist")),
                      DropdownMenuItem(value: "Philosopher", child: Text("Philosopher")),
                      DropdownMenuItem(value: "Tactical Commander", child: Text("Tactician")),
                      DropdownMenuItem(value: "Friend", child: Text("Friend")),
                    ],
                    onChanged: (val) => setStateDialog(() => tone = val!),
                  ),
                  const SizedBox(height: 16),
                  const Text("DATA CONTEXT RANGE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final p = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if (p != null) setStateDialog(() => startDate = p);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(border: Border.all(color: AppTheme.fhBorderColor)),
                            child: Text(DateFormat('MM/dd/yy').format(startDate), style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text("-")),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final p = await showDatePicker(context: context, initialDate: endDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                            if (p != null) setStateDialog(() => endDate = p);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(border: Border.all(color: AppTheme.fhBorderColor)),
                            child: Text(DateFormat('MM/dd/yy').format(endDate), style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
              ValorantButton(
                label: "ESTABLISH",
                color: AppTheme.fhAccentPurple,
                onPressed: () {
                  provider.createNoraSession(title: title, tone: tone, startDate: startDate, endDate: endDate);
                  Navigator.pop(ctx);
                },
              )
            ],
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final memory = appProvider.chatbotMemory;
    final activeSession = appProvider.activeNoraSession;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("NORA", style: TextStyle(color: AppTheme.fhAccentPurple, letterSpacing: 4.0)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.menu, color: AppTheme.fhTextSecondary),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          )
        ],
      ),
      endDrawer: Drawer(
        backgroundColor: AppTheme.fhBgDeepDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: AppTheme.fhBgDark, border: Border(bottom: BorderSide(color: AppTheme.fhAccentPurple.withOpacity(0.5)))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(MdiIcons.brain, color: AppTheme.fhAccentPurple, size: 32),
                  const SizedBox(height: 8),
                  const Text("NORA LINKS", style: TextStyle(color: Colors.white, fontFamily: AppTheme.fontDisplay, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ValorantButton(
                label: "NEW LINK",
                icon: Icons.add,
                color: AppTheme.fhAccentPurple,
                onPressed: () {
                  Navigator.pop(context); // Close drawer
                  _showNewSessionDialog(appProvider);
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: memory.noraSessions.length,
                itemBuilder: (context, index) {
                  if (index >= memory.noraSessions.length) return const SizedBox.shrink();
                  final session = memory.noraSessions[index];
                  final isSelected = session.id == memory.activeNoraSessionId;
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppTheme.fhAccentPurple.withOpacity(0.1),
                    title: Text(session.title, style: TextStyle(color: isSelected ? AppTheme.fhAccentPurple : AppTheme.fhTextPrimary, fontWeight: FontWeight.bold)),
                    subtitle: Text("${session.tone} • ${DateFormat('MM/dd').format(session.startDate)}", style: const TextStyle(fontSize: 10)),
                    onTap: () {
                      appProvider.switchNoraSession(session.id);
                      Navigator.pop(context);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.fhAccentRed),
                      onPressed: () => appProvider.deleteNoraSession(session.id),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
      body: activeSession == null 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(MdiIcons.brain, size: 64, color: AppTheme.fhTextDisabled.withOpacity(0.2)),
                const SizedBox(height: 16),
                const Text("NO ACTIVE LINK", style: TextStyle(color: AppTheme.fhTextSecondary, fontFamily: AppTheme.fontDisplay, fontSize: 20)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentPurple, foregroundColor: Colors.white),
                  onPressed: () => _showNewSessionDialog(appProvider),
                  child: const Text("INITIALIZE LINK"),
                )
              ],
            ),
          )
        : Column(
          children: [
            // Session Header Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.fhBgDark,
              child: Row(
                children: [
                  Icon(MdiIcons.circleSmall, color: AppTheme.fhAccentPurple),
                  Text("TONE: ${activeSession.tone.toUpperCase()}", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text("${DateFormat('MM/dd/yy').format(activeSession.startDate)} - ${DateFormat('MM/dd/yy').format(activeSession.endDate)}", style: const TextStyle(color: AppTheme.fhTextDisabled, fontSize: 10)),
                ],
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: activeSession.messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isSending && index == activeSession.messages.length) {
                     return _buildMessageBubble(
                        ChatbotMessage(id: 't', text: '...', sender: MessageSender.bot, timestamp: DateTime.now()), 
                        AppTheme.fhAccentPurple, 
                        true
                     );
                  }
                  if (index >= activeSession.messages.length) return const SizedBox.shrink();
                  final msg = activeSession.messages[index];
                  return _buildMessageBubble(msg, AppTheme.fhAccentPurple, false);
                },
              ),
            ),

            // Input Area
            Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8, top: 8, left: 16, right: 16),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                border: Border(top: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Input query...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: AppTheme.fhBgMedium,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fhAccentPurple))
                      : Icon(MdiIcons.send, color: AppTheme.fhAccentPurple),
                    onPressed: _isSending ? null : _sendMessage,
                  )
                ],
              ),
            )
          ],
        ),
    );
  }

  Widget _buildMessageBubble(ChatbotMessage message, Color accent, bool isTyping) {
    final isUser = message.sender == MessageSender.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) Padding(padding: const EdgeInsets.only(right: 8.0, bottom: 4), child: Icon(MdiIcons.brain, size: 16, color: accent)),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? accent.withOpacity(0.1) : AppTheme.fhBgMedium,
                border: Border.all(color: isUser ? accent.withOpacity(0.5) : AppTheme.fhBorderColor.withOpacity(0.3)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                )
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? accent : Colors.white,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}