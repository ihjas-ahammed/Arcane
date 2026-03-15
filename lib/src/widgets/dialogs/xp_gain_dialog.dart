import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/wellbeing_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'dart:math';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class XpGainDialog extends StatefulWidget {
  final Map<String, int> xpGained;
  final String? insightText;

  const XpGainDialog({super.key, required this.xpGained, this.insightText});

  @override
  State<XpGainDialog> createState() => _XpGainDialogState();
}

class _XpGainDialogState extends State<XpGainDialog>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _counterController;
  late Animation<int> _xpCounterAnimation;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    final totalXp = widget.xpGained.values.fold(0, (a, b) => a + b);

    _counterController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _xpCounterAnimation = IntTween(begin: 0, end: totalXp).animate(
      CurvedAnimation(parent: _counterController, curve: Curves.easeOutExpo),
    );

    _mainController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _counterController.forward();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.xpGained.entries.where((e) => e.value > 0).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero, 
      child: Stack(
        children: [
          // 1. Full Screen Backdrop Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0),
              ),
            ),
          ),

          // 2. Dismiss tap handler
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),

          // 3. Main Dialog Card
          Center(
            child: GestureDetector(
              onTap: () {}, 
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    constraints: const BoxConstraints(maxWidth: 360, maxHeight: 500),
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(0),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.fhAccentTeal,
                          AppTheme.fhBgDeepDark,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.fhAccentTeal.withValues(alpha: 0.15),
                          blurRadius: 50,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1720),
                        borderRadius: BorderRadius.circular(0),
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.2,
                          colors: [
                            const Color(0xFF1A2634),
                            const Color(0xFF0F1720),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // --- HEADER ---
                          Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 20),
                            child: Column(
                              children: [
                                Text(
                                  "INSIGHT ACQUIRED",
                                  style: TextStyle(
                                    color: AppTheme.fhAccentTeal,
                                    fontFamily: AppTheme.fontDisplay,
                                    fontSize: 25,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                    shadows: [
                                      Shadow(
                                        color: AppTheme.fhAccentTeal.withValues(alpha: 0.3),
                                        blurRadius: 10
                                      )
                                    ]
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // --- SCROLLABLE CONTENT ---
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Column(
                                children: [
                                  // Skills List
                                  if (entries.isNotEmpty) ...[
                                    Container(
                                      height: 1, 
                                      width: double.infinity,
                                      color: Colors.white.withValues(alpha: 0.1),
                                      margin: const EdgeInsets.only(bottom: 16),
                                    ),
                                    GridView.count(
                                      crossAxisCount: 4,
                                      shrinkWrap: true,
                                      childAspectRatio: 1.6,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      physics: const NeverScrollableScrollPhysics(),
                                      children: List.generate(entries.length, (index) {
                                      final entry = entries[index];
                                      return _buildCompactSkillRow(entry.key, entry.value)
                                            .animate(delay: (100 * index).ms)
                                            .fadeIn()
                                            .slideX(begin: -0.1, end: 0);
                                      }),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Insight / Log Analysis Text
                                  if (widget.insightText != null && widget.insightText!.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        border: Border(
                                          left: BorderSide(color: AppTheme.fhAccentTeal, width: 3)
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(8),
                                          bottomRight: Radius.circular(8)
                                        )
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(MdiIcons.consoleLine, size: 14, color: AppTheme.fhAccentTeal),
                                              const SizedBox(width: 8),
                                              const Text(
                                                "LOG ANALYSIS", 
                                                style: TextStyle(
                                                  color: AppTheme.fhAccentTeal, 
                                                  fontSize: 10, 
                                                  fontWeight: FontWeight.bold, 
                                                  letterSpacing: 1.5
                                                )
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            widget.insightText!,
                                            style: const TextStyle(
                                              color: AppTheme.fhTextSecondary,
                                              fontSize: 13,
                                              height: 1.5,
                                              fontFamily: "RobotoCondensed"
                                            ),
                                          ),
                                        ],
                                      ),
                                    ).animate(delay: 400.ms).fadeIn(),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // --- FOOTER BUTTON ---
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.fhAccentTeal,
                                  foregroundColor: const Color(0xFF0F1720),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: const BeveledRectangleBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(4))),
                                ),
                                child: const Text(
                                  "CONTINUE",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontFamily: AppTheme.fontDisplay,
                                      fontSize: 18,
                                      letterSpacing: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildCompactSkillRow(String skillName, int xp) {
  Color color = WellbeingTheme.getColor(skillName);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppTheme.fhBgMedium.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          WellbeingTheme.getIcon(skillName),
          color: color,
          size: 16,
        ),
        const SizedBox(height: 2),
        Text(
          "+$xp",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
 }
}