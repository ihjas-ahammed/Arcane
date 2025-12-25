import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:ui';
import 'dart:math';

class XpGainDialog extends StatefulWidget {
  final Map<String, int> xpGained;

  const XpGainDialog({super.key, required this.xpGained});

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
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    final totalXp = widget.xpGained.values.fold(0, (a, b) => a + b);

    _counterController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _xpCounterAnimation = IntTween(begin: 0, end: totalXp).animate(
      CurvedAnimation(parent: _counterController, curve: Curves.easeOutExpo),
    );

    // Start sequence
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
    // Filter only virtues with XP gain
    final entries = widget.xpGained.entries.where((e) => e.value > 0).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blur Background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),

          // Main Card
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 320),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDeepDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.fhAccentGold.withValues(alpha: 0.5),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.fhAccentGold.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5),
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Icon
                    _buildShimmerIcon(),
                    const SizedBox(height: 16),

                    Text(
                      "INSIGHT ACQUIRED",
                      style: TextStyle(
                        color: AppTheme.fhAccentGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                              color:
                                  AppTheme.fhAccentGold.withValues(alpha: 0.5),
                              blurRadius: 10)
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Total XP Counter
                    AnimatedBuilder(
                      animation: _counterController,
                      builder: (context, child) {
                        return Text(
                          "+${_xpCounterAnimation.value} XP",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            fontFamily:
                                'Inter', // Assuming Inter is available, or default
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),

                    // Skills List
                    ...List.generate(entries.length, (index) {
                      final entry = entries[index];
                      // Staggered fade in for items
                      final start = 0.5 + (index * 0.1);
                      final end = start + 0.2;
                      final itemAnim = CurvedAnimation(
                        parent: _mainController,
                        curve: Interval(min(start, 0.9), min(end, 1.0),
                            curve: Curves.easeOut),
                      );

                      return FadeTransition(
                        opacity: itemAnim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0, 0), end: Offset.zero)
                              .animate(itemAnim),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: _buildSkillRow(entry.key, entry.value),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 8),

                    // Button
                    ScaleTransition(
                      scale: CurvedAnimation(
                          parent: _mainController,
                          curve: const Interval(0.8, 1.0,
                              curve: Curves.elasticOut)),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.fhAccentGold,
                            foregroundColor: Colors.black,
                            elevation: 8,
                            shadowColor:
                                AppTheme.fhAccentGold.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            "CONTINUE JOURNEY",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerIcon() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.fhAccentGold.withValues(alpha: 0.2 * (1 - value)),
                    Colors.transparent
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Icon(MdiIcons.starFourPoints,
                size: 48, color: AppTheme.fhAccentGold),
          ],
        );
      },
    );
  }

  Widget _buildSkillRow(String skillName, int xp) {
    Color color = _getVirtueColor(skillName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(_getSkillIcon(skillName), color: color, size: 20),
          const SizedBox(width: 12),
          Text(skillName,
              style: const TextStyle(
                  color: AppTheme.fhTextSecondary,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text("+$xp",
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Color _getVirtueColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom':
        return Colors.blueAccent;
      case 'courage':
        return AppTheme.fhAccentRed;
      case 'humanity':
        return const Color(0xFFE91E63);
      case 'justice':
        return AppTheme.fhAccentGold;
      case 'temperance':
        return AppTheme.fhAccentTeal;
      case 'transcendence':
        return AppTheme.fhAccentPurple;
      default:
        return Colors.grey;
    }
  }

  IconData _getSkillIcon(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom':
        return MdiIcons.brain;
      case 'courage':
        return MdiIcons.sword;
      case 'humanity':
        return MdiIcons.handHeart;
      case 'justice':
        return MdiIcons.scaleBalance;
      case 'temperance':
        return MdiIcons.yinYang;
      case 'transcendence':
        return MdiIcons.starFourPoints;
      default:
        return MdiIcons.circleSmall;
    }
  }
}
