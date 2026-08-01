import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/widgets/header_widget.dart';

/// Goals & Metrics Operator Drawer
/// Pixel-perfect tactical HUD replica matching specs:
/// Features dynamic active protocol color, chamfered corner panels,
/// robust custom scope tab bar with crisp visible titles (DAILY, WEEKLY, MONTHLY),
/// overall progress banner, and custom progress bars with slanted end slits (///).
class GoalsBottomDrawer extends StatefulWidget {
  const GoalsBottomDrawer({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: JweTheme.isLight ? 0.4 : 0.65),
      builder: (ctx) => const GoalsBottomDrawer(),
    );
  }

  @override
  State<GoalsBottomDrawer> createState() => _GoalsBottomDrawerState();
}

class _GoalsBottomDrawerState extends State<GoalsBottomDrawer> {
  GoalScope _activeScope = GoalScope.daily;

  /// Calculates spent time in minutes for linked tasks based on session time
  double _calculateLinkedTimeMinutes(AppProvider provider, GoalModel goal) {
    if (goal.linkedTaskIds.isEmpty) return goal.currentValue;

    double totalMinutes = 0.0;
    final activeMainTasks = provider.mainTasks.where((t) => t.isActive && !t.isDeleted);

    for (var mainTask in activeMainTasks) {
      final bool mainLinked = goal.linkedTaskIds.contains(mainTask.id);

      for (var subTask in mainTask.subTasks) {
        if (subTask.isDeleted) continue;
        final subCompoundId = '${mainTask.id}|${subTask.id}';
        final bool subLinked = mainLinked ||
            goal.linkedTaskIds.contains(subTask.id) ||
            goal.linkedTaskIds.contains(subCompoundId);

        if (subLinked) {
          totalMinutes += subTask.currentTimeSpent > 0
              ? (subTask.currentTimeSpent / 60.0)
              : 0.0;
        }
      }
    }
    return totalMinutes;
  }

  void _openCreateGoalDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateGoalSheet(initialScope: _activeScope),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isLight = JweTheme.isLight;

    // Inherits CURRENT PROTOCOL COLOR
    final Color themeColor = appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;

    final goals = appProvider.goals
        .where((g) => g.scope == _activeScope)
        .toList();

    final completedCount = goals.where((g) {
      final timeMins = _calculateLinkedTimeMinutes(appProvider, g);
      return g.getIsEffectiveCompleted(dynamicTimeMinutes: timeMins);
    }).length;

    final totalXp = goals.fold<int>(0, (sum, g) {
      final timeMins = _calculateLinkedTimeMinutes(appProvider, g);
      final isDone = g.getIsEffectiveCompleted(dynamicTimeMinutes: timeMins);
      return sum + (isDone ? g.xpReward : 0);
    });

    final progressRatio = goals.isEmpty ? 0.0 : completedCount / goals.length;
    final sheetBg = isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: isLight ? 0.12 : 0.25),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Top Handle Bar
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 14),

              // Header Row: Left Icon Box, Non-Overflowing Titles, Right XP Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Double-Chevron Icon Container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: Center(
                        child: ArcaneAppIcon(
                          size: 24,
                          color: themeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Subtitle Column (Robust Non-Overflowing Layout)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.orbitron(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'GOALS & METRICS ',
                                    style: TextStyle(color: isLight ? Colors.black87 : Colors.white),
                                  ),
                                  TextSpan(
                                    text: 'OPERATOR',
                                    style: TextStyle(color: themeColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track targets, counters &\nlinked session time',
                            maxLines: 2,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              height: 1.15,
                              color: isLight ? const Color(0xFF475569) : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Right XP Badge Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          ArcaneAppIcon(size: 14, color: themeColor),
                          const SizedBox(width: 5),
                          Text(
                            '+$totalXp XP',
                            style: GoogleFonts.orbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3 Custom Scope Tabs: DAILY, WEEKLY, MONTHLY (Fully visible crisp text)
              _buildScopeTabRow(themeColor, isLight),

              const SizedBox(height: 12),

              // Overview Progress Banner
              _buildProgressBanner(themeColor, isLight, progressRatio, completedCount, goals.length),

              const SizedBox(height: 12),

              // Goals List Body
              Expanded(
                child: goals.isEmpty
                    ? _buildEmptyState(isLight, themeColor)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: goals.length,
                        itemBuilder: (ctx, i) {
                          final goal = goals[i];
                          final timeMins = _calculateLinkedTimeMinutes(appProvider, goal);
                          return _buildTacticalGoalCard(
                              context, appProvider, goal, timeMins, themeColor, isLight);
                        },
                      ),
              ),

              // Bottom Primary Action Button
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                ),
                child: ElevatedButton(
                  onPressed: () => _openCreateGoalDialog(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: themeColor,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: themeColor.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 20, color: Colors.black),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: Text(
                            'INITIALIZE NEW ${_activeScope.name.toUpperCase()} GOAL',
                            style: GoogleFonts.orbitron(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      ArcaneAppIcon(size: 18, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Custom Scope Segmented Tab Row (100% visible text, glowing active indicator line)
  Widget _buildScopeTabRow(Color themeColor, bool isLight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFE8E4DA) : const Color(0xFF14151E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.12)
                : JweTheme.lineSoft.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: GoalScope.values.asMap().entries.map((entry) {
            final idx = entry.key;
            final scope = entry.value;
            final isSelected = scope == _activeScope;
            final label = scope.name.toUpperCase();

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  border: idx < GoalScope.values.length - 1 && !isSelected
                      ? Border(
                          right: BorderSide(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        )
                      : null,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeScope = scope;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? themeColor.withValues(alpha: isLight ? 0.22 : 0.20)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(color: themeColor, width: 1.2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: isSelected
                              ? (isLight ? Colors.black87 : Colors.white)
                              : (isLight ? const Color(0xFF475569) : const Color(0xFF8E9BAE)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Overview Progress Banner Container
  Widget _buildProgressBanner(
    Color themeColor,
    bool isLight,
    double progressRatio,
    int completedCount,
    int totalCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF12131C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLight
                ? Colors.black.withValues(alpha: 0.1)
                : JweTheme.lineSoft.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_activeScope.name.toUpperCase()} PROGRESS',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.orbitron(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isLight ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$completedCount / $totalCount COMPLETED (${(progressRatio * 100).toInt()}%)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 8,
              width: double.infinity,
              child: CustomPaint(
                painter: _TacticalProgressBarPainter(
                  progress: progressRatio,
                  activeColor: themeColor,
                  isLight: isLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLight, Color themeColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.target,
            size: 44,
            color: themeColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'NO ${_activeScope.name.toUpperCase()} GOALS ACTIVE',
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isLight ? Colors.black54 : Colors.white60,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the button below to initialize your first goal metric',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: isLight ? Colors.black45 : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalGoalCard(
    BuildContext context,
    AppProvider appProvider,
    GoalModel goal,
    double timeMins,
    Color themeColor,
    bool isLight,
  ) {
    final isDone = goal.getIsEffectiveCompleted(dynamicTimeMinutes: timeMins);
    final ratio = goal.getProgressRatio(dynamicTimeMinutes: timeMins);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: CustomPaint(
        painter: _TacticalCardPainter(
          activeColor: themeColor,
          isLight: isLight,
          isDone: isDone,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header Row: Metric Badge, Title & XP, Delete Icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricBadge(goal.metricType, themeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone
                                ? (isLight ? Colors.black45 : Colors.white54)
                                : (isLight ? Colors.black87 : Colors.white),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '+${goal.xpReward} XP',
                              style: GoogleFonts.orbitron(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                            if (goal.linkedTaskIds.isNotEmpty) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(MdiIcons.linkVariant, size: 11, color: isLight ? Colors.black54 : Colors.white54),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${goal.linkedTaskIds.length} Linked Task(s)',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      color: isLight ? Colors.black54 : Colors.white54,
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
                  IconButton(
                    icon: Icon(
                      MdiIcons.deleteOutline,
                      size: 18,
                      color: isLight ? Colors.black45 : Colors.white54,
                    ),
                    onPressed: () {
                      appProvider.deleteGoal(goal.id);
                      showGlobalToast('Goal deleted');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Card Metric Specific Body
              if (goal.metricType == GoalMetricType.check) ...[
                InkWell(
                  onTap: () {
                    appProvider.toggleGoalCheck(goal.id);
                    if (!goal.isCompleted) {
                      showGlobalToast('⚡ Goal Completed! +${goal.xpReward} XP');
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppTheme.fhAccentGreen.withValues(alpha: 0.15)
                          : themeColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDone ? AppTheme.fhAccentGreen : themeColor,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDone ? MdiIcons.checkboxMarkedCircle : MdiIcons.checkboxBlankCircleOutline,
                          color: isDone ? AppTheme.fhAccentGreen : themeColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDone ? 'COMPLETED' : 'MARK COMPLETE',
                          style: GoogleFonts.orbitron(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isDone ? AppTheme.fhAccentGreen : themeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (goal.metricType == GoalMetricType.counter) ...[
                Row(
                  children: [
                    InkWell(
                      onTap: () => appProvider.updateGoalCounter(goal.id, -1),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1C1E2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.remove, size: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${goal.currentValue.toInt()} / ${goal.targetValue.toInt()}',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDone ? AppTheme.fhAccentGreen : themeColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        appProvider.updateGoalCounter(goal.id, 1);
                        if (goal.currentValue + 1 >= goal.targetValue) {
                          showGlobalToast('⚡ Counter Target Reached! +${goal.xpReward} XP');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isLight ? Colors.black.withValues(alpha: 0.05) : const Color(0xFF1C1E2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.add, size: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 7,
                        child: CustomPaint(
                          size: const Size(double.infinity, 7),
                          painter: _TacticalProgressBarPainter(
                            progress: ratio,
                            activeColor: isDone ? AppTheme.fhAccentGreen : themeColor,
                            isLight: isLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (goal.metricType == GoalMetricType.timeCounter) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'LOGGED: ',
                              style: GoogleFonts.orbitron(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isLight ? Colors.black87 : Colors.white,
                              ),
                            ),
                            Text(
                              '${timeMins.toInt()}m / ${goal.targetValue.toInt()}m Target',
                              style: GoogleFonts.orbitron(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDone ? AppTheme.fhAccentGreen : themeColor,
                              ),
                            ),
                          ],
                        ),
                        if (goal.startDateTime != null)
                          Text(
                            'From: ${DateFormat('MM/dd HH:mm').format(goal.startDateTime!)}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              color: isLight ? Colors.black54 : Colors.white54,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 7,
                      child: CustomPaint(
                        size: const Size(double.infinity, 7),
                        painter: _TacticalProgressBarPainter(
                          progress: ratio,
                          activeColor: isDone ? AppTheme.fhAccentGreen : themeColor,
                          isLight: isLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBadge(GoalMetricType type, Color themeColor) {
    IconData icon;
    String label;

    switch (type) {
      case GoalMetricType.check:
        icon = MdiIcons.target;
        label = 'CHECK';
        break;
      case GoalMetricType.counter:
        icon = MdiIcons.counter;
        label = 'COUNTER';
        break;
      case GoalMetricType.timeCounter:
        icon = MdiIcons.clockOutline;
        label = 'TIME';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: themeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: themeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Slanted Progress Bar Painter with Slit Cutouts (///)
class _TacticalProgressBarPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final bool isLight;

  _TacticalProgressBarPainter({
    required this.progress,
    required this.activeColor,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    final clamped = progress.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = isLight ? Colors.black.withValues(alpha: 0.08) : const Color(0xFF1B1D28)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isLight
          ? Colors.black.withValues(alpha: 0.15)
          : JweTheme.lineSoft.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final RRect trackRect = RRect.fromLTRBR(0, 0, W, H, const Radius.circular(2));
    canvas.drawRRect(trackRect, trackPaint);
    canvas.drawRRect(trackRect, borderPaint);

    if (clamped <= 0) return;

    final fillW = W * clamped;

    final fillPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final RRect fillRect = RRect.fromLTRBR(0, 0, fillW, H, const Radius.circular(2));
    canvas.drawRRect(fillRect, fillPaint);

    // Slanted end cap lines /// (if progress fill > 16px)
    if (fillW > 16) {
      final slitPaint = Paint()
        ..color = isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      for (int i = 0; i < 3; i++) {
        final x = fillW - 4 - (i * 3.5);
        canvas.drawLine(Offset(x, 0.5), Offset(x - 2.5, H - 0.5), slitPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.isLight != isLight;
  }
}

/// Custom Painter for Tactical Goal Card Chassis with Chamfered Corners & Left Color Bar
class _TacticalCardPainter extends CustomPainter {
  final Color activeColor;
  final bool isLight;
  final bool isDone;

  _TacticalCardPainter({
    required this.activeColor,
    required this.isLight,
    required this.isDone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    final chamfer = 12.0;

    final cardColor = isDone ? AppTheme.fhAccentGreen : activeColor;

    final bgPaint = Paint()
      ..color = isLight ? const Color(0xFFEDE9DF) : const Color(0xFF11121A)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = cardColor.withValues(alpha: isDone ? 0.8 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..moveTo(chamfer, 0)
      ..lineTo(W - 4, 0)
      ..lineTo(W, 4)
      ..lineTo(W, H - 4)
      ..lineTo(W - 4, H)
      ..lineTo(4, H)
      ..lineTo(0, H - 4)
      ..lineTo(0, chamfer)
      ..close();

    canvas.drawPath(path, bgPaint);
    canvas.drawPath(path, borderPaint);

    // Glowing Left Accent Bar & Chamfer Cutout
    final accentPaint = Paint()
      ..color = cardColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final leftBar = Path()
      ..moveTo(chamfer, 0)
      ..lineTo(0, chamfer)
      ..lineTo(0, H / 2);

    canvas.drawPath(leftBar, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _TacticalCardPainter oldDelegate) {
    return oldDelegate.activeColor != activeColor ||
        oldDelegate.isLight != isLight ||
        oldDelegate.isDone != isDone;
  }
}

/// Create Goal Form Bottom Sheet (with Interactive Planner Task Tree)
class _CreateGoalSheet extends StatefulWidget {
  final GoalScope initialScope;

  const _CreateGoalSheet({required this.initialScope});

  @override
  State<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<_CreateGoalSheet> {
  final _titleController = TextEditingController();
  final _filterController = TextEditingController();
  late GoalScope _selectedScope;
  GoalMetricType _selectedMetric = GoalMetricType.check;
  double _targetValue = 1.0;
  DateTime? _startDateTime;
  final Set<String> _selectedTaskIds = {};
  String _taskSearchQuery = '';
  final Map<String, bool> _expandedTasks = {};

  @override
  void initState() {
    super.initState();
    _selectedScope = widget.initialScope;
    _startDateTime = DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _saveGoal(AppProvider provider) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showGlobalToast('Please enter a goal title');
      return;
    }

    final goal = GoalModel(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      scope: _selectedScope,
      metricType: _selectedMetric,
      targetValue: _targetValue <= 0 ? 1.0 : _targetValue,
      startDateTime: _startDateTime,
      linkedTaskIds: _selectedTaskIds.toList(),
      xpReward: 50,
    );

    provider.addGoal(goal);
    Navigator.of(context).pop();
    showGlobalToast('New Goal Created!');
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isLight = JweTheme.isLight;
    final themeColor = appProvider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;
    final sheetBg = isLight ? const Color(0xFFF6F3EC) : const Color(0xFF0D0E14);

    final activeTasks = appProvider.mainTasks
        .where((t) => t.isActive && !t.isDeleted)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: themeColor, width: 1.5),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'INITIALIZE NEW GOAL',
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title Field
              TextField(
                controller: _titleController,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
                decoration: InputDecoration(
                  labelText: 'GOAL TITLE',
                  hintText: 'e.g., Complete 3 Coding Checkpoints',
                  labelStyle: GoogleFonts.orbitron(fontSize: 10.5, color: themeColor),
                  filled: true,
                  fillColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 16),

              // Scope Selector
              Text(
                'TARGET SCOPE',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: GoalScope.values.map((scope) {
                  final selected = scope == _selectedScope;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        label: Text(
                          scope.name.toUpperCase(),
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.black
                                : (isLight ? const Color(0xFF475569) : Colors.white60),
                          ),
                        ),
                        selected: selected,
                        selectedColor: themeColor,
                        onSelected: (_) => setState(() => _selectedScope = scope),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Metric Type Selector
              Text(
                'METRIC TYPE',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: GoalMetricType.values.map((metric) {
                  final selected = metric == _selectedMetric;
                  String label = 'CHECK';
                  if (metric == GoalMetricType.counter) label = 'COUNTER';
                  if (metric == GoalMetricType.timeCounter) label = 'TIME COUNTER';

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        label: Text(
                          label,
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.black
                                : (isLight ? const Color(0xFF475569) : Colors.white60),
                          ),
                        ),
                        selected: selected,
                        selectedColor: themeColor,
                        onSelected: (_) => setState(() => _selectedMetric = metric),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Metric Specific Settings
              if (_selectedMetric == GoalMetricType.counter) ...[
                Text(
                  'TARGET COUNT',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF475569) : Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _targetValue.clamp(1.0, 100.0),
                        min: 1.0,
                        max: 100.0,
                        divisions: 99,
                        activeColor: themeColor,
                        label: '${_targetValue.toInt()}',
                        onChanged: (val) => setState(() => _targetValue = val),
                      ),
                    ),
                    Text(
                      '${_targetValue.toInt()} Count',
                      style: GoogleFonts.orbitron(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ] else if (_selectedMetric == GoalMetricType.timeCounter) ...[
                Text(
                  'TARGET TIME DURATION (MINUTES)',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLight ? const Color(0xFF475569) : Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _targetValue.clamp(5.0, 480.0),
                        min: 5.0,
                        max: 480.0,
                        divisions: 95,
                        activeColor: themeColor,
                        label: '${_targetValue.toInt()}m',
                        onChanged: (val) => setState(() => _targetValue = val),
                      ),
                    ),
                    Text(
                      '${_targetValue.toInt()} Mins',
                      style: GoogleFonts.orbitron(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Start DateTime Picker
                Row(
                  children: [
                    Icon(MdiIcons.calendarClock, size: 16, color: themeColor),
                    const SizedBox(width: 6),
                    Text(
                      'Start: ${DateFormat('yyyy-MM-dd HH:mm').format(_startDateTime ?? DateTime.now())}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: isLight ? Colors.black87 : Colors.white,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _startDateTime ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (pickedDate != null && context.mounted) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_startDateTime ?? DateTime.now()),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _startDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: const Text('CHANGE'),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // PLANNER-STYLE TASK SELECTOR
              Text(
                'LINK TASKS (OPTIONAL)',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLight ? const Color(0xFF475569) : Colors.white60,
                ),
              ),
              const SizedBox(height: 6),

              // Selected Task Chips Bar
              if (_selectedTaskIds.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selectedTaskIds.map<Widget>((id) {
                    final label = _getTaskNameById(activeTasks, id);
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: themeColor.withValues(alpha: 0.18),
                      side: BorderSide(color: themeColor),
                      label: Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLight ? Colors.black87 : Colors.white,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        setState(() => _selectedTaskIds.remove(id));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Filter input bar
              TextField(
                controller: _filterController,
                onChanged: (v) => setState(() => _taskSearchQuery = v.trim().toLowerCase()),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Filter tasks...',
                  hintStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: isLight ? Colors.black45 : Colors.white38,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  isDense: true,
                  filled: true,
                  fillColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: themeColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Task Tree Selector Container
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.12)
                        : JweTheme.lineSoft.withValues(alpha: 0.5),
                  ),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: _buildTaskTreeNodes(activeTasks, themeColor, isLight),
                ),
              ),

              const SizedBox(height: 20),

              // Create Action Button
              ElevatedButton(
                onPressed: () => _saveGoal(appProvider),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'CREATE GOAL',
                  style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTaskNameById(List<MainTask> tasks, String id) {
    for (var main in tasks) {
      if (main.id == id) return main.name;
      for (var sub in main.subTasks) {
        final subCompound = '${main.id}|${sub.id}';
        if (sub.id == id || subCompound == id) return '${main.name} → ${sub.name}';
      }
    }
    return id;
  }

  List<Widget> _buildTaskTreeNodes(List<MainTask> tasks, Color themeColor, bool isLight) {
    final List<Widget> nodes = [];
    final q = _taskSearchQuery;

    for (var main in tasks) {
      final activeSubs = main.subTasks.where((s) => !s.isDeleted).toList();
      final bool mainMatch = q.isEmpty || main.name.toLowerCase().contains(q);

      final matchingSubs = activeSubs.where((sub) {
        if (mainMatch) return true;
        return sub.name.toLowerCase().contains(q);
      }).toList();

      if (!mainMatch && matchingSubs.isEmpty) continue;

      final isExpanded = _expandedTasks[main.id] ?? (q.isNotEmpty);
      final isMainSelected = _selectedTaskIds.contains(main.id);

      nodes.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: main.taskColor.withValues(alpha: isLight ? 0.08 : 0.14),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 18,
                      color: main.taskColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _expandedTasks[main.id] = !isExpanded;
                      });
                    },
                  ),
                  Checkbox(
                    value: isMainSelected,
                    activeColor: main.taskColor,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTaskIds.add(main.id);
                        } else {
                          _selectedTaskIds.remove(main.id);
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      main.name,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isLight ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: main.taskColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${matchingSubs.length} subtask(s)',
                      style: GoogleFonts.orbitron(fontSize: 9, color: main.taskColor),
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  children: matchingSubs.map((sub) {
                    final subCompound = '${main.id}|${sub.id}';
                    final isSubSelected = _selectedTaskIds.contains(sub.id) ||
                        _selectedTaskIds.contains(subCompound);

                    return CheckboxListTile(
                      dense: true,
                      title: Text(
                        sub.name,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: isLight ? Colors.black87 : Colors.white70,
                        ),
                      ),
                      activeColor: main.taskColor,
                      value: isSubSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedTaskIds.add(subCompound);
                          } else {
                            _selectedTaskIds.remove(subCompound);
                            _selectedTaskIds.remove(sub.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      );
    }

    if (nodes.isEmpty) {
      nodes.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No active tasks found',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: JweTheme.textMuted),
            ),
          ),
        ),
      );
    }

    return nodes;
  }
}
