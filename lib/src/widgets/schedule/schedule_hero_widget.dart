import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ScheduleHeroWidget extends StatelessWidget {
  final MainTask? mainTask;
  final SubTask? subTask;
  final SubSubTask? checkpoint;
  final bool isRunning;
  final double totalTodaySeconds;
  
  final VoidCallback onPlayPause;
  final VoidCallback onOpenPlan;
  final VoidCallback onPostpone;
  final VoidCallback onFinishCheckpoint;

  const ScheduleHeroWidget({
    super.key,
    this.mainTask,
    this.subTask,
    this.checkpoint,
    required this.isRunning,
    required this.totalTodaySeconds,
    required this.onPlayPause,
    required this.onOpenPlan,
    required this.onPostpone,
    required this.onFinishCheckpoint,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = subTask == null;
    final bool isCheckpoint = checkpoint != null;
    
    final Color mainColor = isEmpty 
        ? AppTheme.fhTextDisabled 
        : (isCheckpoint ? PersonInfoTheme.spideyCyan : (mainTask?.taskColor ?? PersonInfoTheme.spideyRed));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: PersonInfoTheme.bgPanel,
        border: Border(left: BorderSide(color: mainColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isCheckpoint ? MdiIcons.rhombusOutline : MdiIcons.targetAccount, color: mainColor, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      isEmpty ? "QUEUE EMPTY" : (isCheckpoint ? "CHECKPOINT TARGET" : "PRIMARY TARGET"),
                      style: GoogleFonts.rajdhani(
                        color: mainColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: onOpenPlan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhTextSecondary.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(MdiIcons.formatListBulleted, size: 12, color: AppTheme.fhTextSecondary),
                        const SizedBox(width: 4),
                        const Text("DAY PLAN", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEmpty ? "NO PLAN SET" : (isCheckpoint ? checkpoint!.name.toUpperCase() : subTask!.name.toUpperCase()),
                        style: GoogleFonts.chakraPetch(
                          color: AppTheme.fhTextPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (!isEmpty)
                        Text(
                          isCheckpoint ? "${mainTask?.name} > ${subTask!.name}".toUpperCase() : mainTask!.name.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.fhTextSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppTheme.fontDisplay,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                      if (!isCheckpoint && !isEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(MdiIcons.clockOutline, size: 12, color: AppTheme.fhTextSecondary),
                            const SizedBox(width: 4),
                            Text(
                              "TIME SPENT: ${helper.formatTime(totalTodaySeconds)}",
                              style: const TextStyle(
                                fontFamily: "RobotoMono",
                                color: AppTheme.fhTextSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold
                              ),
                            )
                          ],
                        )
                      ]
                    ],
                  ),
                ),
                
                if (!isEmpty) ...[
                  const SizedBox(width: 16),
                  
                  // Action Buttons Column
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isCheckpoint) ...[
                        _buildCompactButton(
                          label: "FINISH",
                          icon: MdiIcons.checkAll,
                          color: PersonInfoTheme.spideyCyan,
                          isFilled: true,
                          onTap: onFinishCheckpoint
                        ),
                        const SizedBox(height: 8),
                        _buildCompactButton(
                          label: "POSTPONE",
                          icon: MdiIcons.skipNext,
                          color: PersonInfoTheme.spideyRed,
                          isFilled: false,
                          onTap: onPostpone
                        ),
                      ] else ...[
                        _buildCompactButton(
                          label: isRunning ? "HALT" : "ENGAGE",
                          icon: isRunning ? MdiIcons.pause : MdiIcons.play,
                          color: isRunning ? AppTheme.fhAccentRed : mainColor,
                          isFilled: true,
                          onTap: onPlayPause
                        ),
                        const SizedBox(height: 8),
                        _buildCompactButton(
                          label: "POSTPONE",
                          icon: MdiIcons.skipNext,
                          color: AppTheme.fhTextSecondary,
                          isFilled: false,
                          onTap: onPostpone
                        ),
                      ]
                    ],
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactButton({required String label, required IconData icon, required Color color, required bool isFilled, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isFilled ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isFilled ? Colors.black : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                color: isFilled ? Colors.black : color,
                fontWeight: FontWeight.bold,
                fontSize: 12
              ),
            )
          ],
        ),
      ),
    );
  }
}