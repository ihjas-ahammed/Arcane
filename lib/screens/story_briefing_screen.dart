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

class _StoryBriefingScreenState extends State<StoryBriefingScreen>
    with TickerProviderStateMixin {
  // Story state
  String _loadingLabel = 'Initializing story...';
  bool _isLoading = true;
  bool _isContinuing = false;
  String? _errorMessage;

  String _scene = '';
  List<Map<String, dynamic>> _paragraphs = [];
  String _systemContext = '';

  // Input state
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isNarrate = false;

  String _selectedCharacter = 'Ayan';

  final Map<String, String> _characterDescriptions = {
    'Ayan': 'Analytical • Uses analogies',
    'Mira': 'Intuitive • Emotionally aware',
    'Hiba': 'Dramatic • Snack enthusiast',
    'Zara': 'Practical • Philosophical',
  };

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _selectedCharacter = provider.settings.storyCharacter;
    _loadStory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _paragraphs = [];
      _scene = '';
      _systemContext = '';
      _loadingLabel = 'Gathering the friends...';
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final result = await provider.generateStoryProgressively(
        widget.todayLogs,
        onProgress: (label, paragraphs) {
          if (mounted) {
            setState(() {
              _loadingLabel = label;
              _paragraphs = List.from(paragraphs);
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _scene = result.scene;
          _paragraphs = result.paragraphs;
          _systemContext = result.systemContext;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('OFFLINE_MOCK_DATA')
              ? 'No API key configured. Please check your settings.'
              : 'Failed to generate story: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendUserInput() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isContinuing) return;
    _inputController.clear();

    setState(() => _isContinuing = true);

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final newParagraphs = await provider.continueStory(
        systemContext: _systemContext,
        previousParagraphs: _paragraphs,
        userInput: text,
        isNarration: _isNarrate,
      );

      if (mounted) {
        setState(() {
          _paragraphs.addAll(newParagraphs);
          _isContinuing = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isContinuing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to continue story: $e',
                style: const TextStyle(color: AppTheme.fhTextPrimary)),
            backgroundColor: AppTheme.fhAccentRed,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getCharacterColor(String? character) {
    switch (character?.trim()) {
      case 'Ayan':
        return AppTheme.fhAccentGold;
      case 'Mira':
        return AppTheme.fhAccentPurple;
      case 'Hiba':
        return const Color(0xFFFF9E2C);
      case 'Zara':
        return AppTheme.fhAccentTeal;
      default:
        return AppTheme.fhTextSecondary;
    }
  }

  IconData _getCharacterIcon(String? character) {
    switch (character?.trim()) {
      case 'Ayan':
        return MdiIcons.atom;
      case 'Mira':
        return MdiIcons.heartCircleOutline;
      case 'Hiba':
        return MdiIcons.starFourPointsCircleOutline;
      case 'Zara':
        return MdiIcons.chartTimelineVariant;
      default:
        return MdiIcons.accountCircleOutline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: Stack(
        children: [
          // Cinematic background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0F1E),
                    AppTheme.fhBgDeepDark,
                    AppTheme.fhBgDeepDark,
                  ],
                ),
              ),
            ),
          ),
          // Top purple ambient glow
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.fhAccentPurple.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(provider),
                _buildCharacterSelector(provider),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _buildStoryContent(),
                ),
                if (!_isLoading && _errorMessage == null) _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDeepDark.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.fhBorderColor.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppTheme.fhTextSecondary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Icon(MdiIcons.dramaMasks,
              size: 20, color: AppTheme.fhAccentPurple),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STORY MODE',
                style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.fhTextPrimary,
                  letterSpacing: 2.0,
                ),
              ),
              Text(
                'DAILY ANALYSIS',
                style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 9,
                  color: AppTheme.fhAccentPurple.withOpacity(0.8),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(MdiIcons.refresh,
                size: 20, color: AppTheme.fhTextSecondary),
            tooltip: 'Regenerate',
            onPressed: _isLoading ? null : _loadStory,
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterSelector(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.fhBgDark.withOpacity(0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.accountStar,
                  size: 11, color: AppTheme.fhTextDisabled),
              const SizedBox(width: 6),
              const Text(
                'YOUR CHARACTER',
                style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 9,
                  color: AppTheme.fhTextDisabled,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: _characterDescriptions.keys.map((charName) {
              final isSelected = _selectedCharacter == charName;
              final color = _getCharacterColor(charName);
              return Expanded(
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          if (charName != _selectedCharacter) {
                            setState(() => _selectedCharacter = charName);
                            provider.setSettings(
                                provider.settings..storyCharacter = charName);
                            _loadStory();
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? color.withOpacity(0.6)
                            : AppTheme.fhBorderColor,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCharacterIcon(charName),
                          size: 18,
                          color: isSelected
                              ? color
                              : AppTheme.fhTextDisabled,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          charName,
                          style: TextStyle(
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? color
                                : AppTheme.fhTextDisabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing mask icon
            Animate(
              onPlay: (c) => c.repeat(),
              effects: [
                const ShimmerEffect(duration: Duration(milliseconds: 1800)),
                ScaleEffect(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                    duration: 1200.ms,
                    curve: Curves.easeInOut),
              ],
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.fhBgDark,
                  border: Border.all(
                      color: AppTheme.fhAccentPurple.withOpacity(0.4),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.fhAccentPurple.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: const Icon(MdiIcons.dramaMasks,
                    size: 38, color: AppTheme.fhAccentPurple),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _loadingLabel.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.fhTextPrimary,
                letterSpacing: 2.0,
              ),
            ).animate(key: ValueKey(_loadingLabel)).fadeIn(duration: 300.ms),
            const SizedBox(height: 20),

            // Show partial paragraphs as they come in
            if (_paragraphs.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.fhBorderColor.withOpacity(0.5)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _paragraphs.take(4).map((p) {
                      final type = p['type'] as String? ?? 'action';
                      final character = p['character'] as String?;
                      final text = p['text'] as String? ?? '';
                      if (type == 'dialogue' && character != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(top: 7, right: 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getCharacterColor(character),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$character: ${text.length > 60 ? '${text.substring(0, 60)}...' : text}',
                                  style: TextStyle(
                                    color: AppTheme.fhTextSecondary
                                        .withOpacity(0.7),
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }).toList(),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.fhBgDark,
                color: AppTheme.fhAccentPurple,
                minHeight: 2,
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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.fhAccentRed.withOpacity(0.1),
                border: Border.all(
                    color: AppTheme.fhAccentRed.withOpacity(0.4), width: 1.5),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 34, color: AppTheme.fhAccentRed),
            ),
            const SizedBox(height: 20),
            const Text(
              'CONNECTION INTERRUPTED',
              style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.fhTextPrimary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.fhTextSecondary, height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              icon: Icon(MdiIcons.reload, size: 18),
              label: const Text('RETRY'),
              onPressed: _loadStory,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.fhAccentPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 0, bottom: 8),
      itemCount: _paragraphs.length + 2 + (_isContinuing ? 1 : 0),
      itemBuilder: (context, index) {
        // Scene card at top
        if (index == 0) {
          return _buildSceneCard();
        }

        // Loading indicator at end
        if (_isContinuing && index == _paragraphs.length + 1) {
          return _buildTypingIndicator();
        }

        if (index > _paragraphs.length) return const SizedBox.shrink();

        final p = _paragraphs[index - 1];
        final type = p['type'] as String? ?? 'action';
        final character = p['character'] as String?;
        final text = p['text'] as String? ?? '';
        final isUser = character == _selectedCharacter;

        return Animate(
          effects: [
            FadeEffect(delay: (index * 40).ms, duration: 350.ms),
            SlideEffect(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
                delay: (index * 40).ms,
                duration: 350.ms),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: type == 'dialogue'
                ? _buildDialogueBubble(character, text, isUser)
                : _buildActionLine(text),
          ),
        );
      },
    );
  }

  Widget _buildSceneCard() {
    return Animate(
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 600)),
        SlideEffect(
            begin: Offset(0, -0.03),
            end: Offset.zero,
            duration: Duration(milliseconds: 600)),
      ],
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.fhBgDark,
              AppTheme.fhBgDark.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.fhAccentGold.withOpacity(0.2),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.fhAccentGold.withOpacity(0.05),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.fhAccentGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'THE SCENE',
                  style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.fhTextDisabled,
                    letterSpacing: 2.0,
                  ),
                ),
                const Spacer(),
                Icon(MdiIcons.movieOpenOutline,
                    size: 14, color: AppTheme.fhTextDisabled),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _scene,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppTheme.fhTextSecondary,
                fontSize: 13.5,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogueBubble(
      String? character, String text, bool isUser) {
    final color = _getCharacterColor(character);
    final charIcon = _getCharacterIcon(character);
    final displayText =
        text.trim().replaceAll(RegExp(r'^[""""]|[""""]$'), '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.12),
                    border:
                        Border.all(color: color.withOpacity(0.4), width: 1.0),
                  ),
                  child: Icon(charIcon, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
                  child: Text(
                    character ?? 'Unknown',
                    style: TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isUser
                        ? color.withOpacity(0.1)
                        : AppTheme.fhBgMedium,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isUser ? 14 : 2),
                      bottomRight: Radius.circular(isUser ? 2 : 14),
                    ),
                    border: Border.all(
                      color: isUser
                          ? color.withOpacity(0.35)
                          : AppTheme.fhBorderColor,
                      width: 1.0,
                    ),
                    boxShadow: isUser
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.08),
                              blurRadius: 8,
                              spreadRadius: 0,
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    displayText,
                    style: const TextStyle(
                      color: AppTheme.fhTextPrimary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
                border:
                    Border.all(color: color.withOpacity(0.4), width: 1.0),
              ),
              child: Icon(charIcon, size: 18, color: color),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Column(
        children: [
          Container(
            height: 1,
            color: AppTheme.fhBorderColor.withOpacity(0.4),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.fhTextSecondary.withOpacity(0.65),
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          Container(
            height: 1,
            color: AppTheme.fhBorderColor.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.fhAccentPurple.withOpacity(0.1),
              border: Border.all(
                  color: AppTheme.fhAccentPurple.withOpacity(0.3)),
            ),
            child: Icon(MdiIcons.dotsHorizontal,
                size: 18, color: AppTheme.fhAccentPurple),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.fhBgMedium,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
                bottomLeft: Radius.circular(2),
              ),
              border: Border.all(color: AppTheme.fhBorderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Animate(
                  onPlay: (c) => c.repeat(),
                  effects: const [
                    ScaleEffect(
                        begin: Offset(0.5, 0.5),
                        end: Offset(1.0, 1.0),
                        duration: Duration(milliseconds: 600)),
                  ],
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.fhAccentPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Animate(
                  onPlay: (c) => c.repeat(),
                  effects: [
                    ScaleEffect(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        delay: 200.ms,
                        duration: 600.ms),
                  ],
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.fhAccentPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Animate(
                  onPlay: (c) => c.repeat(),
                  effects: [
                    ScaleEffect(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        delay: 400.ms,
                        duration: 600.ms),
                  ],
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.fhAccentPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final userColor = _getCharacterColor(_selectedCharacter);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
        left: 12,
        right: 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withOpacity(0.95),
        border: Border(
          top: BorderSide(
              color: AppTheme.fhBorderColor.withOpacity(0.5), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Narrate / Dialogue toggle row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgMedium,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.fhBorderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: !_isNarrate
                            ? userColor.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _isNarrate = false),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(MdiIcons.messageTextOutline,
                                size: 12,
                                color: !_isNarrate
                                    ? userColor
                                    : AppTheme.fhTextDisabled),
                            const SizedBox(width: 4),
                            Text(
                              'SPEAK',
                              style: TextStyle(
                                fontFamily: AppTheme.fontDisplay,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: !_isNarrate
                                    ? userColor
                                    : AppTheme.fhTextDisabled,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isNarrate
                            ? AppTheme.fhAccentGold.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _isNarrate = true),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(MdiIcons.bookOpenOutline,
                                size: 12,
                                color: _isNarrate
                                    ? AppTheme.fhAccentGold
                                    : AppTheme.fhTextDisabled),
                            const SizedBox(width: 4),
                            Text(
                              'NARRATE',
                              style: TextStyle(
                                fontFamily: AppTheme.fontDisplay,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _isNarrate
                                    ? AppTheme.fhAccentGold
                                    : AppTheme.fhTextDisabled,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgMedium,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isNarrate
                          ? AppTheme.fhAccentGold.withOpacity(0.3)
                          : userColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          decoration: InputDecoration(
                            hintText: _isNarrate
                                ? 'Describe what happens...'
                                : 'Say something as $_selectedCharacter...',
                            hintStyle: TextStyle(
                              color: AppTheme.fhTextDisabled.withOpacity(0.6),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onSubmitted: (_) => _sendUserInput(),
                          style: const TextStyle(
                              color: AppTheme.fhTextPrimary, fontSize: 13),
                          maxLines: null,
                        ),
                      ),
                      _isContinuing
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _isNarrate
                                      ? AppTheme.fhAccentGold
                                      : userColor,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                MdiIcons.sendOutline,
                                size: 18,
                                color: _isNarrate
                                    ? AppTheme.fhAccentGold
                                    : userColor,
                              ),
                              onPressed: _sendUserInput,
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
