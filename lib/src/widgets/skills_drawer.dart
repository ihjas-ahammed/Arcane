// lib/src/widgets/skills_drawer.dart
import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/screens/reflection_editor_screen.dart';
import 'package:arcane/src/widgets/ui/virtue_circle.dart';
import 'package:arcane/src/widgets/ui/reflection_log_card.dart';
import 'package:arcane/src/widgets/dialogs/skill_detail_dialog.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;

class SkillsDrawer extends StatelessWidget {
  const SkillsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    // Removed unused skills variable

    // Filter to show ALL recent insights of the current day
    final todayStr = helper.getTodayDateString();
    final todayLogs = appProvider.reflectionLogs.where((l) {
      final logDate =
          "${l.timestamp.year}-${l.timestamp.month.toString().padLeft(2, '0')}-${l.timestamp.day.toString().padLeft(2, '0')}";
      return logDate == todayStr;
    }).toList();

    return Drawer(
      width: 340,
      backgroundColor: AppTheme.fhBgDeepDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              color: AppTheme.fhBgDark,
              border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor)),
            ),
            child: Column(
              children: [
                Icon(MdiIcons.shieldAccount,
                    size: 48, color: AppTheme.fhAccentGold),
                const SizedBox(height: 12),
                Text("PERSONA & VIRTUES",
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppTheme.fhTextPrimary, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text("Track your internal growth",
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              // Responsive grid count based on drawer width
              int crossAxisCount = 3;

              return ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  // Skills Grid
                  GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.85,
                    children: [
                      'Wisdom',
                      'Courage',
                      'Humanity',
                      'Justice',
                      'Temperance',
                      'Transcendence'
                    ].map((name) {
                      final xp7d = appProvider.get7DaySkillMomentum(name);

                      final int momentumLevel = (xp7d / 50).floor() + 1;
                      final double momentumProgress = (xp7d % 50) / 50.0;
                      final Map<String, String> virtuesDescription = {
                        'Wisdom':
                            'Cognitive strengths related to acquiring and using knowledge (creativity, curiosity, perspective).',
                        'Courage':
                            'Emotional strengths involving the exercise of will to achieve goals despite opposition (bravery, honesty, perseverance).',
                        'Humanity':
                            'Interpersonal strengths related to caring for and befriending others (kindness, love, social intelligence).',
                        'Justice':
                            'Civic strengths that support healthy community life (fairness, leadership, teamwork).',
                        'Temperance':
                            'Strengths that protect against excess and assist in self-regulation (forgiveness, modesty, prudence).',
                        'Transcendence':
                            'Strengths that connect individuals to the larger universe and provide meaning (gratitude, hope, humor, appreciation of beauty).',
                      };

                      // Create a temporary skill object for display purposes
                      final skill = Skill(
                          id: name.substring(0, 3).toLowerCase(),
                          name: name,
                          description: virtuesDescription[name]??"",
                          currentXp:
                              (xp7d % 50), // Current progress in this level
                          maxXp: 50, // Each momentum level is 50 XP wide
                          level: momentumLevel);

                      return VirtueCircle(
                        skill: skill,
                        momentumLevel: momentumLevel,
                        momentumProgress: momentumProgress,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => SkillDetailDialog(
                              skill: skill,
                              color: _getSkillColor(skill.name),
                              icon: _getSkillIcon(skill.name),
                              xpGainedToday: appProvider
                                  .getXpGainedForSkillToday(skill.name),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  Divider(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),

                  ElevatedButton.icon(
                    icon: Icon(MdiIcons.notebookEditOutline),
                    label: const Text("LOG REFLECTION"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhBgMedium,
                      foregroundColor: AppTheme.fhAccentTeal,
                      side: const BorderSide(color: AppTheme.fhAccentTeal),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      final todayStr = helper.getTodayDateString();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ReflectionEditorScreen(dateStr: todayStr),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  if (todayLogs.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("TODAY'S INSIGHTS",
                            style: theme.textTheme.labelMedium),
                        Text("${todayLogs.length} Total",
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.fhTextDisabled)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Show ALL logs for today, newest first
                    ...todayLogs.reversed
                        .map((log) => ReflectionLogCard(log: log)),
                  ] else ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("No insights logged today.",
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic)),
                      ),
                    )
                  ]
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _getSkillColor(String name) {
    switch (name.toLowerCase()) {
      case 'wisdom':
        return Colors.blueAccent;
      case 'courage':
        return AppTheme.fhAccentRed;
      case 'humanity':
        return const Color(0xFFE91E63); // Pink
      case 'justice':
        return AppTheme.fhAccentGold;
      case 'temperance':
        return AppTheme.fhAccentTeal;
      case 'transcendence':
        return AppTheme.fhAccentPurple;
      default:
        return AppTheme.fhTextSecondary;
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
        return MdiIcons.circle;
    }
  }
}
