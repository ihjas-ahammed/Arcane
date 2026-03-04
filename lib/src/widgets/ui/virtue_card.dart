import 'package:flutter/material.dart';
import 'package:arcane/src/models/skill_models.dart';
import 'package:arcane/src/theme/app_theme.dart';

class VirtueCard extends StatelessWidget {
  final Skill skill;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const VirtueCard({
    super.key,
    required this.skill,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = skill.currentXp / skill.maxXp;
    final int level = skill.level;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.fhBgDark.withOpacity(0.9),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

                    SizedBox(height: 10,),
            // Header (Compact, No Gradient)
            Expanded(
              flex: 4, // Adjusted ratio
              child: Container(
                // Removed gradient decoration
                child: Stack(
                  children: [
                    // Top Left Icon
                    // Hexagon Avatar (Scaled down)
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipPath(
                            clipper: _HexagonClipper(),
                            child: Container(
                              width: 50, // Smaller
                              height: 58,
                              color: AppTheme.fhBgDeepDark,
                              child: Center(
                                child: Icon(icon, size: 24, color: color),
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: const Size(52, 60),
                            painter: _HexagonBorderPainter(color: color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              flex: 5, // Adjusted ratio
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      skill.name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 9, // Smaller font
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppTheme.fhTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "LEVEL $level",
                      style: TextStyle(
                        color: color,
                        fontSize: 9, // Smaller font
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Progress Bar Section
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 6, // Thinner bar
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.fhBgDeepDark,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "XP: ${skill.currentXp}/${skill.maxXp}",
                      style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 8), // Smaller font
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w * 0.5, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _HexagonBorderPainter extends CustomPainter {
  final Color color;
  
  _HexagonBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; // Thinner border

    final w = size.width;
    final h = size.height;
    
    final path = Path();
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w * 0.5, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}