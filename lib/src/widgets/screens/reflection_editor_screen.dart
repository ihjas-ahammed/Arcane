import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:arcane/src/utils/helpers.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ReflectionEditorScreen extends StatefulWidget {
  final ReflectionLog? initialLog;
  final String dateStr;

  const ReflectionEditorScreen({
    super.key,
    this.initialLog,
    required this.dateStr,
  });

  @override
  State<ReflectionEditorScreen> createState() => _ReflectionEditorScreenState();
}

class _ReflectionEditorScreenState extends State<ReflectionEditorScreen> {
  late TextEditingController _triggerController;
  late TextEditingController _emotionController;
  late TextEditingController _reasonController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _triggerController =
        TextEditingController(text: widget.initialLog?.trigger ?? '');
    _emotionController =
        TextEditingController(text: widget.initialLog?.emotion ?? '');
    _reasonController =
        TextEditingController(text: widget.initialLog?.reason ?? '');
  }

  @override
  void dispose() {
    _triggerController.dispose();
    _emotionController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveReflection() async {
    if (_triggerController.text.trim().isEmpty) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);

    // Parse the dateStr to get the correct day (using current time if today, or start of day if past)
    // Actually, we should try to preserve time if it's today, or pick a reasonable time if past (e.g. now's time on that day)
    final targetDate = DateTime.parse(widget.dateStr);
    final now = DateTime.now();
    DateTime timestamp;

    // Check if targetDate is the same calendar day as today
    if (targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day) {
      timestamp = now;
    } else {
      // Set to noon or current time on that past day to ensure it falls within that day
      timestamp = DateTime(targetDate.year, targetDate.month, targetDate.day,
          now.hour, now.minute);
    }

    if (widget.initialLog != null) {
      // We are editing an existing log
      appProvider.updateReflectionLog(
        widget.initialLog!.id,
        trigger: _triggerController.text.trim(),
        emotion: _emotionController.text.trim(),
        reason: _reasonController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } else {
      // Create new log
      setState(() => _isLoading = true);
      try {
        final xpGained = await appProvider.processReflection(
          trigger: _triggerController.text.trim(),
          emotion: _emotionController.text.trim(),
          reason: _reasonController.text.trim(),
          timestamp: timestamp,
        );

        if (mounted) {
          Navigator.pop(context); // Close editor

          // Show XP Gain Dialog
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.fhBgDark,
                      title: Row(children: [
                        Icon(MdiIcons.starFourPoints,
                            color: AppTheme.fhAccentGold),
                        const SizedBox(width: 8),
                        const Text("Insight Gained!"),
                      ]),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("You have gained experience in:",
                              style:
                                  TextStyle(color: AppTheme.fhTextSecondary)),
                          const SizedBox(height: 12),
                          ...xpGained.entries.map((e) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Text(e.key.capitalize(),
                                        style: const TextStyle(
                                            color: AppTheme.fhTextPrimary,
                                            fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Text("+${e.value} XP",
                                        style: const TextStyle(
                                            color: AppTheme.fhAccentGreen,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Awesome"))
                      ]));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error saving: $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateDailySummary() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final aiService = Provider.of<AIService>(context, listen: false);

      // Filter logs for the specific day passed in
      final targetDate = DateTime.parse(widget.dateStr);
      final dailyLogs = appProvider.reflectionLogs.where((l) {
        return l.timestamp.year == targetDate.year &&
            l.timestamp.month == targetDate.month &&
            l.timestamp.day == targetDate.day;
      }).toList();

      final summary = await aiService.generateDailySummary(
        reflections: dailyLogs
            .map((l) => {
                  'trigger': l.trigger,
                  'emotion': l.emotion,
                  'reason': l.reason,
                })
            .toList(),
        modelCandidates: appProvider.settings.liteModels,
        currentApiKeyIndex: appProvider.apiKeyIndex,
        onNewApiKeyIndex: appProvider.setProviderApiKeyIndex,
        onLog: (s) => (s), // Avoid print in production
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.fhBgDark,
          title: const Text("Daily Summary",
              style: TextStyle(color: AppTheme.fhTextPrimary)),
          content: SingleChildScrollView(
              child: Text(summary,
                  style: const TextStyle(color: AppTheme.fhTextSecondary))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to generate summary: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reflection Editor"),
        backgroundColor: AppTheme.fhBgDark,
        leading: IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(MdiIcons.robotHappyOutline,
                    color: AppTheme.fhAccentGold),
            tooltip: "Generate Daily Summary",
            onPressed: _isLoading ? null : _generateDailySummary),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.fhAccentGreen),
            onPressed: _saveReflection,
          )
        ],
      ),
      backgroundColor: AppTheme.fhBgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildExpandableField(
              controller: _triggerController,
              label: "Trigger / Situation",
              hint: "What happened?",
              icon: MdiIcons.target,
            ),
            const SizedBox(height: 16),
            _buildExpandableField(
              controller: _emotionController,
              label: "Emotion / Feeling",
              hint: "How did it make you feel?",
              icon: MdiIcons.emoticonOutline,
            ),
            const SizedBox(height: 16),
            _buildExpandableField(
              controller: _reasonController,
              label: "Reason / Deep Dive",
              hint: "Why did you feel this way?",
              icon: MdiIcons.thoughtBubbleOutline,
              minLines: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int minLines = 3,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.fhBgMedium.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.fhAccentTeal, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.fhTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            style: const TextStyle(color: AppTheme.fhTextPrimary),
            maxLines: null, // Expandable
            minLines: minLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: AppTheme.fhTextSecondary.withValues(alpha: 0.5)),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

// StringExtension moved to helpers.dart
