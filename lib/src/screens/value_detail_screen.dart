import 'package:flutter/material.dart';
import 'package:arcane/src/models/value_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/dialogs/value_task_generation_dialog.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final value = provider.lifeValues.firstWhere((v) => v.id == widget.valueId);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        backgroundColor: AppTheme.fhBgDeepDark,
        elevation: 0,
        title: Text(value.title.toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.fhBgDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _getScoreColor(value.score).withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                "${value.score}%",
                style: TextStyle(
                  color: _getScoreColor(value.score),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(value.icon, size: 40, color: AppTheme.fhAccentTeal),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      value.description,
                      style: const TextStyle(
                          color: AppTheme.fhTextSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text("Reflective Questions",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.fhTextPrimary,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...value.questions
                .map((q) => _buildQuestionCard(context, provider, value.id, q)),
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton.extended(
              heroTag: 'btn1',
              onPressed: _isAnalyzing
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isAnalyzing = true);
                      try {
                        await provider.analyzeValueAlignment(value.id);
                        if (!mounted) return;
                        messenger.showSnackBar(const SnackBar(
                            content: Text("Alignment Score Updated!")));
                      } catch (e) {
                        if (!mounted) return;
                        messenger
                            .showSnackBar(SnackBar(content: Text("Error: $e")));
                      } finally {
                        if (mounted) setState(() => _isAnalyzing = false);
                      }
                    },
              backgroundColor: AppTheme.fhBgMedium,
              label: _isAnalyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Analyze"),
              icon: Icon(MdiIcons.chartLine),
            ),
            const SizedBox(width: 16),
            FloatingActionButton.extended(
              heroTag: 'btn2',
              onPressed: _isGenerating
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _isGenerating = true);
                      final currentContext = context;
                      try {
                        final tasks =
                            await provider.generateTasksFromValue(value.id);
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        showDialog(
                          context: currentContext,
                          builder: (ctx) =>
                              ValueTaskGenerationDialog(generatedTasks: tasks),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        messenger
                            .showSnackBar(SnackBar(content: Text("Error: $e")));
                      } finally {
                        if (mounted) setState(() => _isGenerating = false);
                      }
                    },
              backgroundColor: AppTheme.fhAccentPurple,
              label: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Generate Actions"),
              icon: Icon(MdiIcons.robotHappy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, AppProvider provider,
      String valueId, ValueQuestion q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.fhBgMedium.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.question,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.fhTextPrimary)),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: q.answer,
            maxLines: null,
            style: const TextStyle(color: AppTheme.fhTextSecondary),
            decoration: const InputDecoration(
              hintText: "Type your answer here...",
              border: InputBorder.none,
              filled: true,
              fillColor: AppTheme.fhBgDeepDark,
              contentPadding: EdgeInsets.all(12),
            ),
            onChanged: (val) {
              // Debounce could be added here for performance
              provider.updateValueAnswer(valueId, q.id, val);
            },
          )
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.fhAccentGreen;
    if (score >= 50) return AppTheme.fhAccentGold;
    return AppTheme.fhAccentRed;
  }
}
