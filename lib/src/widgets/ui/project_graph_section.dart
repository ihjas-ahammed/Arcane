import 'package:flutter/material.dart';
import 'package:arcane/src/models/project_models.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/cards/project_progress_chart.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ProjectGraphSection extends StatefulWidget {
  final Project project;
  final String mainTaskId;

  const ProjectGraphSection({
    super.key,
    required this.project,
    required this.mainTaskId,
  });

  @override
  State<ProjectGraphSection> createState() => _ProjectGraphSectionState();
}

class _ProjectGraphSectionState extends State<ProjectGraphSection> {
  bool _isAnalyzing = false;

  Future<void> _handleFixData(BuildContext context) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    setState(() => _isAnalyzing = true);

    try {
      final history = provider.getProjectProgressHistory(widget.project);
      
      final anomalies = await provider.aiService.analyzeProjectAnomalies(
        historyEvents: history,
        modelCandidates: provider.settings.liteModels,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKeys: provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint(msg),
      );

      if (!context.mounted) return;

      if (anomalies.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No data anomalies detected."),
          backgroundColor: AppTheme.fhAccentGreen,
        ));
      } else {
        // Show Dialog
        await showDialog(
          context: context,
          builder: (ctx) => _AnomalyDialog(
            anomalies: anomalies,
            onConfirm: (idsToDelete) {
              provider.projectActions.fixProjectAnomalies(widget.project, idsToDelete);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Data points removed."),
              ));
            },
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Analysis failed: $e"),
          backgroundColor: AppTheme.fhAccentRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final history = provider.getProjectProgressHistory(widget.project);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "PROGRESS TIMELINE",
              style: TextStyle(
                color: AppTheme.fhTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            if (history.isNotEmpty)
              InkWell(
                onTap: _isAnalyzing ? null : () => _handleFixData(context),
                child: Row(
                  children: [
                    if (_isAnalyzing)
                      const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fhAccentTeal),
                      )
                    else
                      Icon(MdiIcons.autoFix, size: 14, color: AppTheme.fhAccentTeal),
                    const SizedBox(width: 4),
                    Text(
                      _isAnalyzing ? "SCANNING..." : "FIX DATA",
                      style: const TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
          ),
          child: ProjectProgressChart(project: widget.project, history: history),
        ),
      ],
    );
  }
}

class _AnomalyDialog extends StatefulWidget {
  final List<Map<String, dynamic>> anomalies;
  final Function(List<String>) onConfirm;

  const _AnomalyDialog({required this.anomalies, required this.onConfirm});

  @override
  State<_AnomalyDialog> createState() => _AnomalyDialogState();
}

class _AnomalyDialogState extends State<_AnomalyDialog> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // Select all by default
    for (var a in widget.anomalies) {
      if (a['sessionId'] != null) _selectedIds.add(a['sessionId']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.fhBgMedium,
      title: const Text("Detected Anomalies", style: TextStyle(color: AppTheme.fhTextPrimary)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "The AI identified ${widget.anomalies.length} entries that seem incorrect. Select logs to remove.",
              style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.anomalies.length,
                itemBuilder: (context, index) {
                  final item = widget.anomalies[index];
                  final id = item['sessionId'];
                  return CheckboxListTile(
                    value: _selectedIds.contains(id),
                    title: Text(item['reason'] ?? "Unknown Issue", style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 14)),
                    subtitle: Text("ID: ${id.toString().substring(0, 8)}...", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10)),
                    activeColor: AppTheme.fhAccentRed,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(id);
                        } else {
                          _selectedIds.remove(id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
          onPressed: () {
            widget.onConfirm(_selectedIds.toList());
            Navigator.pop(context);
          },
          child: const Text("Delete Selected"),
        ),
      ],
    );
  }
}