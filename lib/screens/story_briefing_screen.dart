import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StoryBriefingScreen extends StatefulWidget {
  final List<ReflectionLog> todayLogs;

  const StoryBriefingScreen({super.key, required this.todayLogs});

  @override
  State<StoryBriefingScreen> createState() => _StoryBriefingScreenState();
}

class _StoryBriefingScreenState extends State<StoryBriefingScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _storyData;
  String _selectedCharacter = 'Ayan';
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _characterDescriptions = {
    'Ayan': 'Analytical, logical, uses simple metaphors.',
    'Mira': 'Soft, intuitive, emotional & supportive.',
    'Hiba': 'Dramatic, relatable, groans at dry tasks.',
    'Zara': 'Structured, practical, slightly philosophical.',
  };

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _selectedCharacter = provider.settings.storyCharacter;
    _loadStory();
  }

  Future<void> _loadStory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _storyData = null;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final result = await provider.generateStoryBriefing(widget.todayLogs);
      setState(() {
        _storyData = result;
        _isLoading = false;
      });
      // Scroll to top when loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains("OFFLINE_MOCK_DATA") 
            ? "Gemini API key is not configured or is offline. Please check your settings." 
            : "Failed to generate story mode: $e";
        _isLoading = false;
      });
    }
  }

  Color _getCharacterColor(String? character) {
    switch (character?.trim()) {
      case 'Ayan':
        return AppTheme.fhAccentGold; // Sky blue primary
      case 'Mira':
        return AppTheme.fhAccentPurple; // Lavender
      case 'Hiba':
        return const Color(0xFFFF9E2C); // Soft Orange
      case 'Zara':
        return AppTheme.fhAccentTeal; // Cyan secondary
      default:
        return AppTheme.fhTextSecondary;
    }
  }

  String _getCharacterInitials(String? character) {
    if (character == null || character.isEmpty) return '?';
    return character[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("STORY MODE ANALYSIS"),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.refresh),
            tooltip: 'Regenerate',
            onPressed: _isLoading ? null : _loadStory,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background soft radial gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [
                    AppTheme.fhBgDark.withOpacity(0.5),
                    AppTheme.fhBgDeepDark,
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
              // Character quick selector bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppTheme.fhBgDark.withOpacity(0.8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "YOUR CHARACTER REPRESENTATION",
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 11,
                        color: AppTheme.fhTextSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _characterDescriptions.keys.map((charName) {
                        final isSelected = _selectedCharacter == charName;
                        final color = _getCharacterColor(charName);
                        return GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () async {
                                  if (charName != _selectedCharacter) {
                                    setState(() {
                                      _selectedCharacter = charName;
                                    });
                                    // Save as default in settings
                                    provider.setSettings(provider.settings..storyCharacter = charName);
                                    // Regenerate
                                    _loadStory();
                                  }
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? color : AppTheme.fhBorderColor,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: color.withOpacity(0.2),
                                  child: Text(
                                    _getCharacterInitials(charName),
                                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  charName,
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.fhTextPrimary : AppTheme.fhTextSecondary,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(height: 1, color: AppTheme.fhBorderColor),

              // Main body
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _buildStoryContent(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ambient pulsing icon
            Animate(
              onPlay: (controller) => controller.repeat(),
              effects: const [
                ShimmerEffect(duration: Duration(milliseconds: 1500)),
                ScaleEffect(begin: Offset(0.95, 0.95), end: Offset(1.05, 1.05), duration: Duration(milliseconds: 1000), curve: Curves.easeInOut)
              ],
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.fhBgDark,
                child: Icon(MdiIcons.dramaMasks, size: 36, color: AppTheme.fhAccentPurple),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "GATHERING THE FRIENDS...",
              style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.fhTextPrimary,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.fhBgDark,
                color: AppTheme.fhAccentPurple,
                minHeight: 2,
              ),
            ),
            const SizedBox(height: 24),
            // Atmospheric loading quotes
            Animate(
              effects: const [FadeEffect(duration: Duration(seconds: 1))],
              child: Text(
                "\"Late evening. Rain tapping on the window. Mug of tea cooling. Ready to analyze the day.\"",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppTheme.fhTextSecondary.withOpacity(0.8),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.alertCircleOutline, size: 48, color: AppTheme.fhAccentRed),
            const SizedBox(height: 16),
            const Text(
              "SYSTEM INTERRUPTION",
              style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? "An unknown error occurred.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.fhTextSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(MdiIcons.reload),
              label: const Text("RETRY CONNECTION"),
              onPressed: _loadStory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.fhAccentPurple,
                foregroundColor: AppTheme.fhTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent() {
    if (_storyData == null) return const SizedBox.shrink();

    final scene = _storyData!['scene'] as String? ?? 'Late evening in the study room.';
    final paragraphsRaw = _storyData!['paragraphs'] as List? ?? [];
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: paragraphsRaw.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Render Scene setting block at top
          return Animate(
            effects: const [
              FadeEffect(duration: Duration(milliseconds: 500)),
              SlideEffect(begin: Offset(0, -0.05), end: Offset.zero, duration: Duration(milliseconds: 500))
            ],
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.fhBorderColor, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.bookOpenOutline, size: 14, color: AppTheme.fhAccentGold),
                      const SizedBox(width: 8),
                      const Text(
                        "THE SCENE",
                        style: TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.fhTextSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    scene,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppTheme.fhTextSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final p = paragraphsRaw[index - 1] as Map<String, dynamic>;
        final type = p['type'] as String? ?? 'action';
        final character = p['character'] as String?;
        final text = p['text'] as String? ?? '';
        final isUser = character == _selectedCharacter;

        // Apply staggered entrance animations
        return Animate(
          effects: [
            FadeEffect(delay: (index * 100).ms, duration: 400.ms),
            SlideEffect(begin: const Offset(0, 0.05), end: Offset.zero, delay: (index * 100).ms, duration: 400.ms)
          ],
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: type == 'dialogue'
                ? _buildDialogueBlock(character, text, isUser)
                : _buildActionBlock(text),
          ),
        );
      },
    );
  }

  Widget _buildDialogueBlock(String? character, String text, bool isUser) {
    final color = _getCharacterColor(character);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isUser) ...[
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              _getCharacterInitials(character),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                character ?? 'Unknown',
                style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser 
                      ? color.withOpacity(0.08)
                      : AppTheme.fhBgMedium.withOpacity(0.5),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isUser ? 12 : 0),
                    bottomRight: Radius.circular(isUser ? 0 : 12),
                  ),
                  border: Border.all(
                    color: isUser ? color.withOpacity(0.4) : AppTheme.fhBorderColor,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  text.trim().replaceAll(RegExp(r'^["“”]|["“”]$'), ''), // Strip surrounding quotes
                  style: const TextStyle(
                    color: AppTheme.fhTextPrimary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              _getCharacterInitials(character),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionBlock(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.fhBorderColor,
              width: 2.0,
            ),
          ),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.fhTextSecondary.withOpacity(0.8),
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
