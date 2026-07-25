import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/sop_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/dialogs/sop_task_selection_modal.dart';

class SopEditScreen extends StatefulWidget {
  final SopModel? sop;

  const SopEditScreen({super.key, this.sop});

  @override
  State<SopEditScreen> createState() => _SopEditScreenState();
}

class _SopEditScreenState extends State<SopEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _situationController;
  late TextEditingController _outcomesController;
  late List<String> _steps;
  late List<SopExecutionLog> _executionLogs;
  
  final TextEditingController _newStepController = TextEditingController();
  bool _isAutoGenerating = false;
  String _aiStatusMessage = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.sop?.title ?? '');
    _situationController = TextEditingController(text: widget.sop?.situation ?? '');
    _outcomesController = TextEditingController(text: widget.sop?.expectedOutcomes ?? '');
    _steps = List<String>.from(widget.sop?.steps ?? []);
    _executionLogs = List<SopExecutionLog>.from(widget.sop?.executionLogs ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _situationController.dispose();
    _outcomesController.dispose();
    _newStepController.dispose();
    super.dispose();
  }

  void _saveSop(AppProvider provider) {
    final title = _titleController.text.trim().isEmpty ? 'Untitled SOP' : _titleController.text.trim();
    final situation = _situationController.text.trim();
    final outcomes = _outcomesController.text.trim();

    final now = DateTime.now();
    if (widget.sop == null) {
      final newSop = SopModel(
        id: 'sop_${now.millisecondsSinceEpoch}',
        title: title,
        situation: situation,
        steps: _steps,
        expectedOutcomes: outcomes,
        executionLogs: _executionLogs,
        createdAt: now,
        updatedAt: now,
      );
      provider.addSop(newSop);
    } else {
      final updatedSop = widget.sop!.copyWith(
        title: title,
        situation: situation,
        steps: _steps,
        expectedOutcomes: outcomes,
        executionLogs: _executionLogs,
        updatedAt: now,
      );
      provider.updateSop(updatedSop);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('SOP saved successfully.'),
        backgroundColor: AppTheme.fhAccentGreen,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _handleAutoGenerateSteps(AppProvider provider) async {
    final situation = _situationController.text.trim();
    if (situation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please write the situation first before auto-generating steps.'),
          backgroundColor: AppTheme.fhAccentOrange,
        ),
      );
      return;
    }

    setState(() {
      _isAutoGenerating = true;
      _aiStatusMessage = 'Analyzing recent reflections (last 30 days) with AI model...';
    });

    try {
      final proModels = provider.settings.heavyModels.isNotEmpty
          ? provider.settings.heavyModels
          : const ['gemini-2.0-pro-exp-02-05', 'gemini-1.5-pro'];
      final liteModels = provider.settings.liteModels.isNotEmpty
          ? provider.settings.liteModels
          : const ['gemini-2.0-flash', 'gemini-2.0-flash-lite', 'gemini-1.5-flash'];
      final candidates = <String>[
        ...proModels,
        ...liteModels.where((m) => !proModels.contains(m)),
      ];

      final generatedSteps = await provider.aiService.generateSopSteps(
        situation: situation,
        reflectionLogs: provider.reflectionLogs,
        modelCandidates: candidates,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKeys: provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => provider.setApiKeyIndex(idx),
        onLog: (log) {
          debugPrint('[SOP_AI] $log');
          if (mounted) {
            setState(() {
              _aiStatusMessage = log.replaceAll(RegExp(r'<[^>]*>'), '');
            });
          }
        },
      );

      if (mounted) {
        if (generatedSteps.isNotEmpty) {
          setState(() {
            _steps.addAll(generatedSteps);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-generated ${generatedSteps.length} operational steps!'),
              backgroundColor: AppTheme.fhAccentGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No steps returned by AI. Please try again.'),
              backgroundColor: AppTheme.fhAccentOrange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-generation failed: $e'),
            backgroundColor: AppTheme.fhAccentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAutoGenerating = false;
          _aiStatusMessage = '';
        });
      }
    }
  }

  void _addManualStep() {
    final text = _newStepController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _steps.add(text);
        _newStepController.clear();
      });
    }
  }

  void _showLogAttemptDialog(BuildContext context) {
    final notesCtrl = TextEditingController();
    String status = 'success';
    int rating = 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.fhBgMedium,
          title: Text(
            'LOG SOP ATTEMPT',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record what happened when you followed this procedure.',
                  style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),

                // Outcome status selector
                Text('OUTCOME STATUS', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StatusChoiceChip(
                      label: 'SUCCESS',
                      color: AppTheme.fhAccentGreen,
                      selected: status == 'success',
                      onSelect: () => setDialogState(() => status = 'success'),
                    ),
                    const SizedBox(width: 8),
                    _StatusChoiceChip(
                      label: 'PARTIAL',
                      color: AppTheme.fhAccentOrange,
                      selected: status == 'partial',
                      onSelect: () => setDialogState(() => status = 'partial'),
                    ),
                    const SizedBox(width: 8),
                    _StatusChoiceChip(
                      label: 'FAILED',
                      color: AppTheme.fhAccentRed,
                      selected: status == 'failed',
                      onSelect: () => setDialogState(() => status = 'failed'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Rating (1-5)
                Text('EFFECTIVENESS RATING (1-5)', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (idx) {
                    final starVal = idx + 1;
                    return IconButton(
                      icon: Icon(
                        starVal <= rating ? Icons.star : Icons.star_border,
                        color: starVal <= rating ? AppTheme.fhAccentOrange : JweTheme.textMuted,
                        size: 24,
                      ),
                      onPressed: () => setDialogState(() => rating = starVal),
                    );
                  }),
                ),
                const SizedBox(height: 14),

                // Notes input
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Trial Notes / What Happened',
                    labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                    hintText: 'e.g., Worked well, step 3 took longer than expected...',
                    hintStyle: TextStyle(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 12),
                    filled: true,
                    fillColor: JweTheme.bgCanvas,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.accentCyan)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final log = SopExecutionLog(
                  id: 'log_${DateTime.now().millisecondsSinceEpoch}',
                  timestamp: DateTime.now(),
                  notes: notesCtrl.text.trim(),
                  successStatus: status,
                  rating: rating,
                );
                setState(() {
                  _executionLogs.insert(0, log);
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal, foregroundColor: AppTheme.fhBgDark),
              child: const Text('LOG TRIAL'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEditing = widget.sop != null;

    return Scaffold(
      backgroundColor: JweTheme.bgCanvas,
      appBar: AppBar(
        backgroundColor: JweTheme.bgCanvas,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: JweTheme.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'EDIT SOP' : 'CREATE NEW SOP',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.accentAmber,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          if (isEditing)
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => SopTaskSelectionModal(sop: widget.sop!),
                );
              },
              icon: Icon(Icons.play_arrow, size: 18, color: AppTheme.fhAccentGreen),
              label: Text(
                'START',
                style: GoogleFonts.jetBrainsMono(
                  color: AppTheme.fhAccentGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: () => _saveSop(provider),
              icon: Icon(Icons.check, size: 18, color: AppTheme.fhAccentTeal),
              label: Text(
                'SAVE',
                style: GoogleFonts.jetBrainsMono(
                  color: AppTheme.fhAccentTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: JweTheme.lineSoft, height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SOP TITLE
            _buildSectionHeader('SOP TITLE', MdiIcons.formatTitle),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: TextStyle(color: JweTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'e.g. Protocol: Emergency Task Overload',
                hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.fhBgMedium,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.accentCyan)),
              ),
            ),
            const SizedBox(height: 20),

            // 2. SITUATION INPUT (MULTILINE)
            _buildSectionHeader('SITUATION (TRIGGER & CONTEXT)', MdiIcons.alertCircleOutline),
            const SizedBox(height: 4),
            Text(
              'Describe the context or triggering condition when this procedure must be executed.',
              style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _situationController,
              maxLines: 4,
              style: TextStyle(color: JweTheme.textWhite, fontSize: 13, height: 1.4),
              decoration: InputDecoration(
                hintText: 'e.g. When experiencing task paralysis, high stress, or sudden multi-project deadlines...',
                hintStyle: TextStyle(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 13),
                filled: true,
                fillColor: AppTheme.fhBgMedium,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.accentCyan)),
              ),
            ),
            const SizedBox(height: 24),

            // 3. STEPS LIST VIEW & AUTO GENERATE BUTTON
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('OPERATIONAL STEPS', MdiIcons.formatListNumbered),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isAutoGenerating ? null : () => _handleAutoGenerateSteps(provider),
                  icon: _isAutoGenerating
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fhBgDark),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    _isAutoGenerating ? 'GENERATING...' : 'AUTO GENERATE STEPS',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.fhAccentTeal,
                    foregroundColor: AppTheme.fhBgDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            if (_isAutoGenerating) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.fhAccentTeal.withValues(alpha: 0.1),
                  border: Border.all(color: AppTheme.fhAccentTeal.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fhAccentTeal),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _aiStatusMessage,
                        style: TextStyle(color: AppTheme.fhAccentTeal, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Steps Reorderable/Editable List
            if (_steps.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.fhBgMedium,
                  border: Border.all(color: JweTheme.lineSoft),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    'No steps added yet. Use "AUTO GENERATE STEPS" or add steps manually below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                onReorder: (oldIdx, newIdx) {
                  setState(() {
                    if (newIdx > oldIdx) newIdx -= 1;
                    final item = _steps.removeAt(oldIdx);
                    _steps.insert(newIdx, item);
                  });
                },
                itemBuilder: (context, index) {
                  return Container(
                    key: ValueKey('step_${index}_${_steps[index]}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.fhBgMedium,
                      border: Border.all(color: JweTheme.lineSoft),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: JweTheme.accentCyan.withValues(alpha: 0.15),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        _steps[index],
                        style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: Icon(MdiIcons.close, size: 16, color: JweTheme.textMuted),
                        onPressed: () {
                          setState(() {
                            _steps.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 10),

            // Manual Step Input Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newStepController,
                    onSubmitted: (_) => _addManualStep(),
                    style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add a new manual step...',
                      hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: AppTheme.fhBgMedium,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.accentCyan)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addManualStep,
                  icon: Icon(Icons.add_circle, color: AppTheme.fhAccentTeal, size: 28),
                  tooltip: 'Add step',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4. EXPECTED OUTCOMES INPUT
            _buildSectionHeader('EXPECTED OUTCOMES', MdiIcons.target),
            const SizedBox(height: 4),
            Text(
              'Specify what success looks like when this procedure is executed.',
              style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _outcomesController,
              maxLines: 3,
              style: TextStyle(color: JweTheme.textWhite, fontSize: 13, height: 1.4),
              decoration: InputDecoration(
                hintText: 'e.g., Focus restored within 10 mins, top priority task started without delay...',
                hintStyle: TextStyle(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 13),
                filled: true,
                fillColor: AppTheme.fhBgMedium,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.lineSoft)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: JweTheme.accentCyan)),
              ),
            ),
            const SizedBox(height: 24),

            // 5. EXECUTION LOGS LIST VIEW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('EXECUTION & TRIAL LOGS', MdiIcons.history),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showLogAttemptDialog(context),
                  icon: Icon(MdiIcons.plus, size: 16),
                  label: Text(
                    'LOG ATTEMPT',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentAmber,
                    side: BorderSide(color: JweTheme.accentAmber),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_executionLogs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.fhBgMedium,
                  border: Border.all(color: JweTheme.lineSoft),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    'No trial attempts logged yet. Tap "LOG ATTEMPT" after following this SOP.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _executionLogs.length,
                itemBuilder: (context, index) {
                  final log = _executionLogs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.fhBgMedium,
                      border: Border.all(color: JweTheme.lineSoft),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStatusBadge(log.successStatus),
                            const SizedBox(width: 8),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < log.rating ? Icons.star : Icons.star_border,
                                  size: 14,
                                  color: i < log.rating ? AppTheme.fhAccentOrange : JweTheme.textMuted,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('dd MMM yyyy HH:mm').format(log.timestamp),
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                            ),
                            IconButton(
                              icon: Icon(MdiIcons.deleteOutline, size: 16, color: JweTheme.textMuted),
                              onPressed: () {
                                setState(() {
                                  _executionLogs.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                        if (log.notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            log.notes,
                            style: TextStyle(color: JweTheme.textWhite, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: JweTheme.accentAmber),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.accentAmber,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'success':
        color = AppTheme.fhAccentGreen;
        label = 'SUCCESS';
        break;
      case 'partial':
        color = AppTheme.fhAccentOrange;
        label = 'PARTIAL';
        break;
      case 'failed':
      default:
        color = AppTheme.fhAccentRed;
        label = 'FAILED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StatusChoiceChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onSelect;

  const _StatusChoiceChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.25) : Colors.transparent,
          border: Border.all(color: selected ? color : JweTheme.lineSoft),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: selected ? color : JweTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
