import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class DataRestoreProgressDialog extends StatefulWidget {
  final String title;
  final ValueNotifier<int> currentStepNotifier;
  final ValueNotifier<String> stepMessageNotifier;
  final ValueNotifier<double> progressNotifier;
  final List<String> stepLabels;

  const DataRestoreProgressDialog({
    super.key,
    required this.title,
    required this.currentStepNotifier,
    required this.stepMessageNotifier,
    required this.progressNotifier,
    required this.stepLabels,
  });

  /// Executes an async recovery/merge [action] in the foreground while showing live step progress.
  static Future<T?> run<T>({
    required BuildContext context,
    required String title,
    required Future<T> Function(Future<void> Function(int stepIndex, String message) reportProgress) action,
    List<String>? stepLabels,
  }) async {
    final labels = stepLabels ?? const [
      "Reading & normalizing snapshot payload",
      "Restoring & merging tasks, subtasks & checkpoints",
      "Merging daily history & completed day logs",
      "Weaving reflection journals & memories",
      "Restoring projects, goals & financial records",
      "Finalizing local storage & refreshing system state",
    ];

    final currentStepNotifier = ValueNotifier<int>(0);
    final stepMessageNotifier = ValueNotifier<String>(labels[0]);
    final progressNotifier = ValueNotifier<double>(0.05);

    bool dialogOpen = true;

    // Show modal dialog in foreground
    showDialog<T?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: DataRestoreProgressDialog(
          title: title,
          currentStepNotifier: currentStepNotifier,
          stepMessageNotifier: stepMessageNotifier,
          progressNotifier: progressNotifier,
          stepLabels: labels,
        ),
      ),
    ).then((val) {
      dialogOpen = false;
      return val;
    });

    Future<void> reportProgress(int stepIndex, String message) async {
      currentStepNotifier.value = stepIndex;
      stepMessageNotifier.value = message;
      progressNotifier.value = ((stepIndex + 1) / labels.length).clamp(0.05, 1.0);
      // Brief pause to allow the foreground UI to render the progress update
      await Future.delayed(const Duration(milliseconds: 60));
    }

    try {
      final result = await action(reportProgress);
      // Give user a final visual cue of 100% completion
      progressNotifier.value = 1.0;
      currentStepNotifier.value = labels.length;
      stepMessageNotifier.value = "Restore & Merge Completed Successfully";
      await Future.delayed(const Duration(milliseconds: 180));

      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(result);
      }
      return result;
    } catch (e) {
      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(null);
      }
      rethrow;
    } finally {
      currentStepNotifier.dispose();
      stepMessageNotifier.dispose();
      progressNotifier.dispose();
    }
  }

  @override
  State<DataRestoreProgressDialog> createState() => _DataRestoreProgressDialogState();
}

class _DataRestoreProgressDialogState extends State<DataRestoreProgressDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentCyan = JweTheme.accentCyan;
    final bgPanel = JweTheme.panel;
    final textWhite = JweTheme.textWhite;
    final textMuted = JweTheme.textMuted;
    final borderCol = JweTheme.border;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipPath(
        clipper: const Chamfer4CornerClipper(chamfer: 10),
        child: CustomPaint(
          foregroundPainter: TacticalCardBorderPainter(
            themeColor: accentCyan,
            chamfer: 10,
            bracketSize: 12,
            leftBarWidth: 3.5,
            borderColor: borderCol,
          ),
          child: Container(
            color: bgPanel,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tactical Header
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) => Icon(
                        MdiIcons.databaseSyncOutline,
                        color: Color.lerp(accentCyan, JweTheme.accentAmber, _pulseController.value),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title.toUpperCase(),
                            style: TextStyle(
                              color: textWhite,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            "FOREGROUND RECONCILIATION IN PROGRESS",
                            style: TextStyle(
                              color: accentCyan,
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Progress Bar & Percentage
                ValueListenableBuilder<double>(
                  valueListenable: widget.progressNotifier,
                  builder: (context, progress, _) {
                    final pct = (progress * 100).toInt();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ValueListenableBuilder<String>(
                              valueListenable: widget.stepMessageNotifier,
                              builder: (context, msg, _) => Expanded(
                                child: Text(
                                  msg,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textWhite,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$pct%",
                              style: TextStyle(
                                color: accentCyan,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: borderCol.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(accentCyan),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Step Progression List
                ValueListenableBuilder<int>(
                  valueListenable: widget.currentStepNotifier,
                  builder: (context, activeStep, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < widget.stepLabels.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                if (i < activeStep)
                                  Icon(MdiIcons.checkCircle, color: accentCyan, size: 16)
                                else if (i == activeStep)
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(JweTheme.accentAmber),
                                    ),
                                  )
                                else
                                  Icon(MdiIcons.circleOutline, color: textMuted.withValues(alpha: 0.4), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.stepLabels[i],
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: i < activeStep
                                          ? textWhite
                                          : (i == activeStep ? JweTheme.accentAmber : textMuted.withValues(alpha: 0.5)),
                                      fontWeight: i == activeStep ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  "DO NOT CLOSE ARCANE WHILE MERGE IS ACTIVE",
                  style: TextStyle(
                    color: textMuted,
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
