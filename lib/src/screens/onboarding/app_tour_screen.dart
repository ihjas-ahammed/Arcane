import 'package:flutter/material.dart';
import 'package:arcane/src/theme/jwe_theme.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/onboarding/tour_slide.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/widgets/cards/submission_card.dart';
import 'package:arcane/src/widgets/ui/wellbeing_card.dart';
import 'package:arcane/src/widgets/ui/nora_message_bubble.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _apiController = TextEditingController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  void _finishTour(AppProvider provider) {
    if (_apiController.text.trim().isNotEmpty) {
      provider.addCustomApiKey(_apiController.text.trim());
    }
    
    // Mark as complete and redirect
    provider.setSettings(provider.settings..hasCompletedTour = true);
    
    // Check if we are inside the nav stack from Settings or straight from App
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    // Dummy data for widgets
    final dummyTask = MainTask(
      id: 'dummy', name: 'OPERATION AEGIS', description: 'Core system defense.', theme: 'tech', colorHex: '00E5FF'
    );
    final dummySub = SubTask(
      id: 'dummy_sub', name: 'CALIBRATE SENSORS', completed: false, currentTimeSpent: 0
    );
    final dummySkill = Skill(
      id: 'res', name: 'Resilience', description: 'Capacity to recover quickly from difficulties.', level: 5, currentXp: 1500, maxXp: 2000
    );
    final dummyMessage = ChatbotMessage(
      id: 'd1', text: "Operative, I've analyzed your recent logs. Your resilience is trending upward. Ready for today's directives?", sender: MessageSender.bot, timestamp: DateTime.now()
    );

    final slides = [
      TourSlide(
        title: "SYSTEM OVERVIEW",
        subtitle: "START WITH WHY?!",
        content: "Productivity apps feel like a chore because they treat life as a sterile checklist.\n\nTask Dominion bridges the gap between gaming and reality. By treating life as a series of tactical operations complete with post-action debriefs and biometrics, self-improvement becomes engaging and structured.\n\nYou are not just surviving. You are managing a complex system: You.",
        visual: Icon(Icons.architecture, size: 80, color: JweTheme.accentCyan.withOpacity(0.5)),
        accentColor: JweTheme.accentCyan,
      ),
      TourSlide(
        title: "MISSIONS & PROTOCOLS",
        subtitle: "ACTIONABLE OBJECTIVES",
        content: "Your chores and goals are broken down into Missions. Log your time, track completion, and maintain system velocity.",
        visual: IgnorePointer(
          child: SubmissionCard(parentTask: dummyTask, subTask: dummySub),
        ),
        accentColor: JweTheme.accentCyan,
      ),
      TourSlide(
        title: "PSYCHOLOGICAL BIOMETRICS",
        subtitle: "SYSTEM DIAGNOSTICS",
        content: "Your mental state is your system integrity. Log events and emotions to gain XP across 12 psychological traits. If you stop logging, levels naturally decay, enforcing consistent reflection.",
        visual: IgnorePointer(
          child: WellbeingCard(skill: dummySkill, onTap: () {}),
        ),
        accentColor: JweTheme.accentAmber,
      ),
      TourSlide(
        title: "NORA NEURAL AI",
        subtitle: "UPLINK CONFIGURATION",
        content: "NORA acts as your tactical commander, therapist, or friend. She requires a Gemini API Key to process your logs and provide intelligence.\n\nObtain one for free at:\naistudio.google.com/app/apikey",
        visual: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IgnorePointer(
              child: NoraMessageBubble(message: dummyMessage, accentColor: const Color(0xFF8A2BE2), isTyping: false),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiController,
              style: const TextStyle(color: JweTheme.textWhite, fontFamily: 'RobotoMono', fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: JweTheme.bgBase,
                hintText: "Paste Gemini API Key here (Optional)",
                hintStyle: TextStyle(color: JweTheme.textMuted.withOpacity(0.5)),
                border: const OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF8A2BE2))),
              ),
            )
          ],
        ),
        accentColor: const Color(0xFF8A2BE2),
      ),
    ];

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    children: slides,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: slides.length,
                        effect: const ExpandingDotsEffect(
                          dotHeight: 6,
                          dotWidth: 6,
                          expansionFactor: 4,
                          activeDotColor: JweTheme.accentCyan,
                          dotColor: JweTheme.border,
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentPage == slides.length - 1 ? JweTheme.accentCyan : JweTheme.panel,
                          foregroundColor: _currentPage == slides.length - 1 ? Colors.black : JweTheme.textWhite,
                          shape: const BeveledRectangleBorder(
                            side: BorderSide(color: JweTheme.accentCyan)
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: () {
                          if (_currentPage < slides.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300), 
                              curve: Curves.easeInOut
                            );
                          } else {
                            _finishTour(provider);
                          }
                        },
                        child: Text(
                          _currentPage == slides.length - 1 ? "COMPLETE BOOT SEQUENCE" : "NEXT",
                          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}