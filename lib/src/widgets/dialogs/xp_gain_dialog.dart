import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class XpGainDialog extends StatefulWidget {
  final Map<String, int> xpGained;

  const XpGainDialog({super.key, required this.xpGained});

  @override
  State<XpGainDialog> createState() => _XpGainDialogState();
}

class _XpGainDialogState extends State<XpGainDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalXp = widget.xpGained.values.fold(0, (a, b) => a + b);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.fhAccentGold, width: 2),
            boxShadow: [
              BoxShadow(color: AppTheme.fhAccentGold.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.starFourPoints, size: 48, color: AppTheme.fhAccentGold),
              const SizedBox(height: 16),
              Text(
                "REFLECTION COMPLETE",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.fhAccentGold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text("+$totalXp XP GAINED", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ...widget.xpGained.entries.where((e) => e.value > 0).map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                       
                       width: 140,
                       child: Text(entry.key, style: const TextStyle(color: AppTheme.fhTextSecondary)),
                      ),
                      SizedBox(
                        width: 80,
                        child: Expanded(
                        flex: 2,
                        child: Stack(
                          children: [
                            Container(height: 8, decoration: BoxDecoration(color: AppTheme.fhBgLight, borderRadius: BorderRadius.circular(4))),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1.0), // Just simple fill animation for effect
                              duration: const Duration(seconds: 1),
                              builder: (ctx, val, child) {
                                return FractionallySizedBox(
                                  widthFactor: val,
                                  child: Container(height: 8, decoration: BoxDecoration(color: _getVirtueColor(entry.key), borderRadius: BorderRadius.circular(4))),
                                );
                              },
                            )
                          ],
                        ),
                      ),
                      )
                      ,
                      SizedBox(width:10),
                      Text("+${entry.value}", style: TextStyle(color: _getVirtueColor(entry.key), fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fhAccentGold,
                  foregroundColor: AppTheme.fhBgDeepDark,
                ),
                child: const Text("CONTINUE"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Color _getVirtueColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom': return Colors.blueAccent;
      case 'courage': return Colors.redAccent;
      case 'humanity': return Colors.pinkAccent;
      case 'justice': return Colors.amber;
      case 'temperance': return Colors.tealAccent;
      case 'transcendence': return Colors.purpleAccent;
      default: return Colors.grey;
    }
  }
}