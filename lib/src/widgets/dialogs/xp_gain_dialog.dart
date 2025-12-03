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
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
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
    // Filter only virtues with XP gain
    final entries = widget.xpGained.entries.where((e) => e.value > 0).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16), // Less padding for small screens
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 340), // Limit width
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.fhAccentGold, width: 1.5),
            boxShadow: [
              BoxShadow(color: AppTheme.fhAccentGold.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.starFourPoints, size: 40, color: AppTheme.fhAccentGold),
              const SizedBox(height: 12),
              Text(
                "INSIGHT GAINED",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.fhAccentGold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text("+$totalXp XP", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // Flexible list that scrolls if too many items
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(entry.key, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13)),
                            ),
                            Expanded(
                              flex: 4,
                              child: Container(
                                height: 6,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  color: AppTheme.fhBgLight, 
                                  borderRadius: BorderRadius.circular(3)
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: 1.0, // Just full fill for visualization
                                  alignment: Alignment.centerLeft,
                                  child: Container(color: _getVirtueColor(entry.key)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text("+${entry.value}", style: TextStyle(color: _getVirtueColor(entry.key), fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.fhAccentGold,
                    foregroundColor: AppTheme.fhBgDeepDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("CONTINUE"),
                ),
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