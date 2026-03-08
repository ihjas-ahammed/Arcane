import 'package:flutter/material.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TaskHeaderCard extends StatelessWidget {
  final MainTask task;
  final int yesterdayTime;
  final List<bool> weeklyCompletion;

  const TaskHeaderCard({
    super.key,
    required this.task,
    required this.yesterdayTime,
    required this.weeklyCompletion,
  });

  @override
  Widget build(BuildContext context) {
    // Spider-Man 2 Gadget Menu aesthetic
    // Dark background, tech grid overlay, sharp angles
    
    final int hours = (task.dailyTimeSpent / 3600).floor();
    final int minutes = ((task.dailyTimeSpent / 60) % 60).floor();
    final String timeDisplay = '${hours}H ${minutes}M';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // Dark metallic background
        color: const Color(0xFF0A0F14),
        border: Border(
          top: BorderSide(color: task.taskColor.withOpacity(0.5), width: 1),
          bottom: BorderSide(color: task.taskColor.withOpacity(0.2), width: 1),
          left: BorderSide(color: task.taskColor, width: 4),
          right: BorderSide(color: task.taskColor.withOpacity(0.2), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: task.taskColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Background Tech Pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.network(
                "https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80",
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Label and Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.taskColor.withOpacity(0.15),
                        border: Border.all(color: task.taskColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        "ACTIVE PROTOCOL",
                        style: TextStyle(
                          color: task.taskColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          fontFamily: AppTheme.fontDisplay,
                        ),
                      ),
                    ),
                    Icon(MdiIcons.targetAccount, color: task.taskColor, size: 20)
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .fade(duration: 1000.ms, begin: 0.5, end: 1.0),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Mission Name
                Text(
                  task.name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 0.9,
                    letterSpacing: 1.5,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Description with a tech line
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 2,
                      height: 40,
                      color: AppTheme.fhTextSecondary.withOpacity(0.3),
                      margin: const EdgeInsets.only(right: 12, top: 2),
                    ),
                    Expanded(
                      child: Text(
                        task.description,
                        style: const TextStyle(
                          color: AppTheme.fhTextSecondary,
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: "RobotoCondensed"
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Bottom Stats Row (Spider-Man Gadget style stats)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      // Time Stat
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SESSION TIME", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            timeDisplay,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppTheme.fontDisplay,
                              letterSpacing: 1.0
                            ),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Theme/Class
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("CLASS", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            task.theme.toUpperCase(),
                            style: TextStyle(
                              color: task.taskColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppTheme.fontDisplay,
                              letterSpacing: 1.0
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Decorative Corner accent
          Positioned(
            top: 0,
            right: 0,
            child: CustomPaint(
              painter: _CornerPainter(color: task.taskColor),
              size: const Size(20, 20),
            ),
          )
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0);
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}