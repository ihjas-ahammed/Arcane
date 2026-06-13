import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/dialogs/nora_control_panel.dart';
import 'package:missions/src/widgets/ui/nora_message_bubble.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  bool _isLiveVoiceOpen = false;
  bool _audioOutputEnabled = true;
  bool _isMicMuted = false;

  final List<String> _suggestions = [
    "Check off my daily tasks",
    "Add subtask 'Meditate' to daily routine",
    "Yesterday's reflection & emotions",
    "List known entities & people info",
    "Teach Nora a new skill",
  ];

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

  Future<void> _sendMessage([String? text]) async {
    final queryText = text ?? _messageController.text.trim();
    if (queryText.isEmpty) return;
    
    if (text == null) {
      _messageController.clear();
    }

    setState(() => _isSending = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.sendNoraMessage(queryText);

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

  void _showControlsPanel(AppProvider provider) {
    if (provider.activeNoraSession == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoraControlPanel(
        session: provider.activeNoraSession!,
        onSave: (config) {
          provider.updateNoraSessionConfig(
            sessionId: provider.activeNoraSession!.id,
            messageLimit: config['messageLimit'],
            modelOverride: config['modelOverride'],
            contextDays: config['contextDays'],
            systemPromptOverride: config['systemPromptOverride']
          );
        }
      ),
    );
  }

  Widget _buildSuggestedPrompts() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: AppTheme.fhBgMedium,
              side: BorderSide(color: AppTheme.fhAccentPurple.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              label: Text(
                _suggestions[index],
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: AppTheme.fontDisplay),
              ),
              onPressed: () => _sendMessage(_suggestions[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveVoiceOverlay() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      top: _isLiveVoiceOpen ? 0 : MediaQuery.of(context).size.height,
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F0C1B),
                AppTheme.fhBgDeepDark,
                const Color(0xFF0A0812),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top controls
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "NORA LIVE LINK",
                        style: TextStyle(
                          color: AppTheme.fhAccentPurple,
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: AppTheme.fontDisplay,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => setState(() => _isLiveVoiceOpen = false),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Animated glowing wave orb
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _audioOutputEnabled
                              ? AppTheme.fhAccentPurple.withOpacity(0.8)
                              : Colors.red.withOpacity(0.8),
                          _audioOutputEnabled
                              ? AppTheme.fhAccentPurple.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _audioOutputEnabled
                              ? AppTheme.fhAccentPurple.withOpacity(0.4)
                              : Colors.red.withOpacity(0.4),
                          blurRadius: 50,
                          spreadRadius: _audioOutputEnabled ? 15 : 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _isMicMuted ? MdiIcons.microphoneOff : MdiIcons.creation,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.08, 1.08),
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .scale(
                    begin: const Offset(1.08, 1.08),
                    end: const Offset(0.92, 0.92),
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  ),
                ),
                const Spacer(),

                // Audio Output Toggle Panel
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgMedium,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _audioOutputEnabled 
                          ? AppTheme.fhAccentPurple.withOpacity(0.3) 
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _audioOutputEnabled ? MdiIcons.volumeHigh : MdiIcons.volumeOff,
                                color: _audioOutputEnabled ? AppTheme.fhAccentPurple : Colors.red,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Audio Output Speaker",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          Switch(
                            value: _audioOutputEnabled,
                            activeColor: AppTheme.fhAccentPurple,
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.black26,
                            onChanged: (val) {
                              setState(() {
                                _audioOutputEnabled = val;
                              });
                            },
                          ),
                        ],
                      ),
                      if (!_audioOutputEnabled) ...[
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Live voice only works with audio output enabled.",
                                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Status text
                Text(
                  !_audioOutputEnabled
                      ? "LIVE LINK SUSPENDED"
                      : (_isMicMuted ? "MUTED" : "LISTENING..."),
                  style: TextStyle(
                    color: _audioOutputEnabled 
                        ? (_isMicMuted ? Colors.grey : AppTheme.fhAccentPurple) 
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),

                // Bottom Call controllers
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mute Button
                      FloatingActionButton(
                        heroTag: "mute_voice",
                        backgroundColor: _isMicMuted ? Colors.white24 : AppTheme.fhBgMedium,
                        child: Icon(_isMicMuted ? MdiIcons.microphoneOff : MdiIcons.microphone, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isMicMuted = !_isMicMuted;
                          });
                        },
                      ),
                      const SizedBox(width: 32),
                      // End Connection
                      FloatingActionButton(
                        heroTag: "end_voice",
                        backgroundColor: Colors.red,
                        child: const Icon(MdiIcons.phoneHangup, color: Colors.white),
                        onPressed: () => setState(() => _isLiveVoiceOpen = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        title: const Text("NORA ASSISTANT", style: TextStyle(color: AppTheme.fhAccentPurple, letterSpacing: 2.0, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontDisplay)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (activeSession != null)
            IconButton(
              icon: Icon(MdiIcons.tuneVariant, color: AppTheme.fhAccentPurple),
              tooltip: "Session Parameters",
              onPressed: () => _showControlsPanel(appProvider),
            ),
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
                  Icon(MdiIcons.creation, color: AppTheme.fhAccentPurple, size: 32),
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
      body: Stack(
        children: [
          activeSession == null 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(MdiIcons.creation, size: 64, color: AppTheme.fhTextDisabled.withOpacity(0.2)),
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
                  
                  // Chat message list
                  Expanded(
                    child: activeSession.messages.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  // Greeting Assistant Visual
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.fhAccentPurple.withOpacity(0.1),
                                      border: Border.all(color: AppTheme.fhAccentPurple.withOpacity(0.3)),
                                    ),
                                    child: Icon(MdiIcons.creation, size: 48, color: AppTheme.fhAccentPurple),
                                  ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                                  const SizedBox(height: 24),
                                  Text(
                                    "Hello, Operative. I'm NORA.",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontFamily: AppTheme.fontDisplay,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ).animate().fadeIn(delay: 200.ms),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "I can assist you with your tasks, database records, reflections, and more. Try one of the suggested actions below or type a query.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13, height: 1.5),
                                  ).animate().fadeIn(delay: 400.ms),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: activeSession.messages.length + (_isSending ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isSending && index == activeSession.messages.length) {
                                 return NoraMessageBubble(
                                    message: ChatbotMessage(id: 't', text: '...', sender: MessageSender.bot, timestamp: DateTime.now()), 
                                    accentColor: AppTheme.fhAccentPurple, 
                                    isTyping: true
                                 );
                              }
                              if (index >= activeSession.messages.length) return const SizedBox.shrink();
                              final msg = activeSession.messages[index];
                              return NoraMessageBubble(
                                message: msg, 
                                accentColor: AppTheme.fhAccentPurple, 
                                isTyping: false
                              );
                            },
                          ),
                  ),

                  // Suggestions list
                  if (!_isSending) _buildSuggestedPrompts(),
                  
                  // Input Area
                  Container(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8, top: 8, left: 16, right: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.fhBgDark,
                      border: Border(top: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3))),
                    ),
                    child: Row(
                      children: [
                        // Live Voice triggers
                        IconButton(
                          icon: Icon(MdiIcons.microphone, color: AppTheme.fhAccentPurple),
                          tooltip: "Live Comms Link",
                          onPressed: () {
                            setState(() {
                              _isLiveVoiceOpen = true;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: "Ask NORA anything...",
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
                          onPressed: _isSending ? null : () => _sendMessage(),
                        )
                      ],
                    ),
                  )
                ],
              ),
          // Live voice overlay layer
          _buildLiveVoiceOverlay(),
        ],
      ),
    );
  }
}