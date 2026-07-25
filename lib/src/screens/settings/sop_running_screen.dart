import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/sop_session_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class SopRunningScreen extends StatefulWidget {
  const SopRunningScreen({super.key});

  @override
  State<SopRunningScreen> createState() => _SopRunningScreenState();
}

class _SopRunningScreenState extends State<SopRunningScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showFinishFeedbackDialog(BuildContext context, AppProvider provider, SopSessionState session) {
    final notesCtrl = TextEditingController();
    String status = 'success';
    int rating = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.fhBgMedium,
          title: Text(
            'SOP COMPLETED - LOG TRIAL',
            style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record notes and outcome for this procedure execution.',
                  style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 14),

                // Status chip selector
                Text('OUTCOME STATUS', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ChoiceChip(
                      label: 'SUCCESS',
                      color: AppTheme.fhAccentGreen,
                      selected: status == 'success',
                      onSelect: () => setDialogState(() => status = 'success'),
                    ),
                    const SizedBox(width: 8),
                    _ChoiceChip(
                      label: 'PARTIAL',
                      color: AppTheme.fhAccentOrange,
                      selected: status == 'partial',
                      onSelect: () => setDialogState(() => status = 'partial'),
                    ),
                    const SizedBox(width: 8),
                    _ChoiceChip(
                      label: 'FAILED',
                      color: AppTheme.fhAccentRed,
                      selected: status == 'failed',
                      onSelect: () => setDialogState(() => status = 'failed'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Rating
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

                // Feedback notes
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Trial Notes / Feedback',
                    labelStyle: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                    hintText: 'e.g., Completed all steps smoothly in 8 minutes...',
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
            ElevatedButton(
              onPressed: () {
                final elapsedSecs = session.elapsedSeconds;
                final endTime = DateTime.now();
                final startTime = endTime.subtract(Duration(seconds: elapsedSecs));

                // 1. Log task time if task was selected
                if (session.mainTaskId != null && session.mainTaskId!.isNotEmpty) {
                  final mainTask = provider.mainTasks.firstWhere((t) => t.id == session.mainTaskId, orElse: () => provider.mainTasks.first);
                  String targetSubId = session.subTaskId ?? '';
                  if (targetSubId.isEmpty && mainTask.subTasks.isNotEmpty) {
                    targetSubId = mainTask.subTasks.first.id;
                  }
                  if (targetSubId.isNotEmpty) {
                    provider.addSessionToSubtask(mainTask.id, targetSubId, startTime, endTime);
                  }
                }

                // 2. Finish SOP session
                provider.finishActiveSopSession(
                  notes: notesCtrl.text.trim(),
                  rating: rating,
                  status: status,
                );

                Navigator.pop(ctx);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal, foregroundColor: AppTheme.fhBgDark),
              child: const Text('SUBMIT & LOG'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancelSession(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: Text(
          'CANCEL SOP SESSION?',
          style: GoogleFonts.jetBrainsMono(color: AppTheme.fhAccentRed, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to exit without logging trial data?',
          style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('KEEP RUNNING', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.cancelActiveSopSession();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
            child: const Text('CANCEL SESSION'),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMins = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remMins.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final session = provider.activeSopSession;

    if (session == null) {
      return Scaffold(
        backgroundColor: JweTheme.bgCanvas,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(MdiIcons.clipboardCheckOutline, size: 48, color: JweTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                'NO RUNNING SOP SESSION',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal, foregroundColor: AppTheme.fhBgDark),
                child: const Text('GO BACK'),
              ),
            ],
          ),
        ),
      );
    }

    final elapsed = session.elapsedSeconds;
    final pct = session.completionPercentage;
    final totalSteps = session.sop.steps.length;
    final completedCount = session.completedStepIndices.length;

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
          'SOP RUNNING VIEW',
          style: GoogleFonts.jetBrainsMono(
            color: AppTheme.fhAccentTeal,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(session.isPaused ? Icons.play_arrow : Icons.pause, color: JweTheme.accentAmber),
            onPressed: () {
              if (session.isPaused) {
                provider.resumeActiveSopSession();
              } else {
                provider.pauseActiveSopSession();
              }
            },
            tooltip: session.isPaused ? 'Resume SOP' : 'Pause SOP',
          ),
          IconButton(
            icon: Icon(MdiIcons.stop, color: AppTheme.fhAccentRed),
            onPressed: () => _confirmCancelSession(context, provider),
            tooltip: 'Cancel SOP',
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
            // Header Card
            Container(
              padding: const EdgeInsets.all(16),
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
                      Expanded(
                        child: Text(
                          session.sop.title.isNotEmpty ? session.sop.title : 'Untitled SOP',
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (session.taskTitle != null && session.taskTitle!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.fhAccentTeal.withValues(alpha: 0.15),
                            border: Border.all(color: AppTheme.fhAccentTeal.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(MdiIcons.clockOutline, size: 12, color: AppTheme.fhAccentTeal),
                              const SizedBox(width: 4),
                              Text(
                                session.taskTitle!,
                                style: GoogleFonts.jetBrainsMono(color: AppTheme.fhAccentTeal, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (session.sop.situation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      session.sop.situation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Divider(color: JweTheme.lineSoft, height: 1),
                  const SizedBox(height: 14),

                  // Timer Counter Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ELAPSED TIME', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10, letterSpacing: 1.0)),
                          const SizedBox(height: 2),
                          Text(
                            _formatSeconds(elapsed),
                            style: GoogleFonts.jetBrainsMono(
                              color: session.isPaused ? JweTheme.accentAmber : JweTheme.accentCyan,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (session.targetDurationSeconds != null) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('TARGET TIMER', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10, letterSpacing: 1.0)),
                            const SizedBox(height: 2),
                            Text(
                              _formatSeconds(session.targetDurationSeconds! - elapsed < 0 ? 0 : session.targetDurationSeconds! - elapsed),
                              style: GoogleFonts.jetBrainsMono(
                                color: (session.targetDurationSeconds! - elapsed) <= 0 ? AppTheme.fhAccentRed : AppTheme.fhAccentGreen,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Progress Bar & Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CHECKLIST PROGRESS ($completedCount / $totalSteps STEPS)',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                Text(
                  '${pct.round()}%',
                  style: GoogleFonts.jetBrainsMono(color: AppTheme.fhAccentTeal, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalSteps > 0 ? (completedCount / totalSteps) : 1.0,
                minHeight: 8,
                backgroundColor: JweTheme.bgCanvas,
                color: AppTheme.fhAccentTeal,
              ),
            ),
            const SizedBox(height: 20),

            // Real-time Progress Graph vs Elapsed Time
            _buildRealTimeProgressChart(session),
            const SizedBox(height: 20),

            // Checklist of SOP steps
            Text('OPERATIONAL CHECKLIST', style: GoogleFonts.jetBrainsMono(color: JweTheme.accentAmber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalSteps,
              itemBuilder: (context, index) {
                final isChecked = session.completedStepIndices.contains(index);
                final stepText = session.sop.steps[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isChecked ? AppTheme.fhAccentTeal.withValues(alpha: 0.08) : AppTheme.fhBgMedium,
                    border: Border.all(color: isChecked ? AppTheme.fhAccentTeal.withValues(alpha: 0.4) : JweTheme.lineSoft),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CheckboxListTile(
                    value: isChecked,
                    onChanged: (_) {
                      provider.toggleStepInActiveSopSession(index);
                    },
                    activeColor: AppTheme.fhAccentTeal,
                    checkColor: AppTheme.fhBgDark,
                    title: Text(
                      stepText,
                      style: TextStyle(
                        color: isChecked ? JweTheme.textWhite : JweTheme.textWhite,
                        fontSize: 13,
                        decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                        decorationColor: AppTheme.fhAccentTeal,
                      ),
                    ),
                    secondary: CircleAvatar(
                      radius: 12,
                      backgroundColor: isChecked ? AppTheme.fhAccentTeal : JweTheme.accentCyan.withValues(alpha: 0.15),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.jetBrainsMono(
                          color: isChecked ? AppTheme.fhBgDark : JweTheme.accentCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Finish SOP Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showFinishFeedbackDialog(context, provider, session),
                icon: const Icon(Icons.check_circle, size: 20),
                label: Text(
                  'FINISH SOP & LOG TRIAL',
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fhAccentTeal,
                  foregroundColor: AppTheme.fhBgDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeProgressChart(SopSessionState session) {
    final points = session.progressPoints;
    final spots = points.map((p) => FlSpot(p.elapsedMinutes, p.completionPercentage)).toList();

    double maxX = points.isEmpty ? 5.0 : points.last.elapsedMinutes;
    if (maxX < 2.0) maxX = 2.0;

    return Container(
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
              Icon(MdiIcons.chartLine, size: 16, color: JweTheme.accentCyan),
              const SizedBox(width: 8),
              Text(
                'REAL-TIME PROGRESS CHART (% VS MINUTES)',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (_) => FlLine(color: JweTheme.lineSoft, strokeWidth: 0.5),
                  getDrawingVerticalLine: (_) => FlLine(color: JweTheme.lineSoft, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}%',
                        style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toStringAsFixed(1)}m',
                        style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: JweTheme.lineSoft),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.fhAccentTeal,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.fhAccentTeal.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onSelect;

  const _ChoiceChip({
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
