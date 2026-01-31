import 'package:flutter/material.dart';
import 'package:arcane/src/models/value_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/dialogs/value_task_generation_dialog.dart';
import 'package:arcane/src/widgets/ui/value_question_card.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ValueDetailScreen extends StatefulWidget {
  final String valueId;

  const ValueDetailScreen({super.key, required this.valueId});

  @override
  State<ValueDetailScreen> createState() => _ValueDetailScreenState();
}

class _ValueDetailScreenState extends State<ValueDetailScreen> {
  bool _isAnalyzing = false;
  bool _isGenerating = false;

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.fhAccentTeal;
    if (score >= 50) return AppTheme.fhAccentGold;
    return AppTheme.fhAccentRed;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final value = provider.lifeValues.firstWhere((v) => v.id == widget.valueId);
    final Color scoreColor = _getScoreColor(value.score);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      // Ensure resize for keyboard interaction with text fields
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: AppTheme.fhBorderColor, width: 1.0)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: AppTheme.fhTextPrimary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("${value.title.toUpperCase()}",
                        style: const TextStyle(
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: AppTheme.fhTextPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: scoreColor),
                      color: scoreColor.withOpacity(0.1),
                    ),
                    child: Text("${value.score}%",
                        style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppTheme.fontDisplay)),
                  )
                ],
              ),
            ),

            // --- CONTENT ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.fhBgDark,
                        border: const Border(
                            left: BorderSide(
                                color: AppTheme.fhAccentTeal, width: 4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(value.icon,
                                  color: AppTheme.fhAccentTeal, size: 28),
                              const SizedBox(width: 12),
                              Text("PROTOCOL DESCRIPTION",
                                  style: TextStyle(
                                      color: AppTheme.fhTextSecondary
                                          .withOpacity(0.7),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            value.description,
                            style: const TextStyle(
                                color: AppTheme.fhTextPrimary,
                                height: 1.5,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    ),

                    // Insight Note
                    if (value.lastInsight != null &&
                        value.lastInsight!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.fhAccentPurple.withOpacity(0.1),
                          border: Border.all(
                              color: AppTheme.fhAccentPurple.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("AI INSIGHT",
                                style: TextStyle(
                                    color: AppTheme.fhAccentPurple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.0)),
                            const SizedBox(height: 8),
                            Text(
                              value.lastInsight!,
                              style: const TextStyle(
                                  color: AppTheme.fhTextPrimary,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Questions Header
                    Row(
                      children: [
                        Container(width: 8, height: 8, color: AppTheme.fhAccentRed),
                        const SizedBox(width: 8),
                        Text("Analysis Questions",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    color: AppTheme.fhTextPrimary,
                                    fontFamily: AppTheme.fontDisplay,
                                    letterSpacing: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Questions List (Using Modular Widget)
                    ...value.questions.map((q) => ValueQuestionCard(
                          question: q,
                          valueId: value.id,
                        )),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // --- FOOTER ACTIONS ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.fhBgDeepDark,
                border: Border(top: BorderSide(color: AppTheme.fhBorderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ValorantButton(
                      label: _isAnalyzing ? "WAIT" : "ANALYZE",
                      isPrimary: false,
                      icon: MdiIcons.chartLine,
                      onPressed: _isAnalyzing
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _isAnalyzing = true);
                              try {
                                await provider.analyzeValueAlignment(value.id);
                                if (!mounted) return;
                                messenger.showSnackBar(const SnackBar(
                                    content: Text("Alignment Score Updated!"),
                                    backgroundColor: AppTheme.fhAccentGreen));
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                    SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.fhAccentRed));
                              } finally {
                                if (mounted)
                                  setState(() => _isAnalyzing = false);
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ValorantButton(
                      label: _isGenerating ? "WAIT" : "GET TASK",
                      isPrimary: true,
                      icon: MdiIcons.robotHappy,
                      onPressed: _isGenerating
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _isGenerating = true);
                              final currentContext = context;
                              try {
                                final tasks = await provider
                                    .generateTasksFromValue(value.id);
                                
                                if (!mounted) return;
                                
                                if (tasks.isEmpty) {
                                   messenger.showSnackBar(const SnackBar(content: Text("No actionable tasks generated. Try adding more detail to answers.")));
                                } else {
                                  showDialog(
                                    context: currentContext,
                                    builder: (ctx) => ValueTaskGenerationDialog(
                                        generatedTasks: tasks),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                    SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.fhAccentRed));
                              } finally {
                                if (mounted)
                                  setState(() => _isGenerating = false);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
