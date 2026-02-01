import 'package:flutter/material.dart';
import 'package:arcane/src/models/value_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/utils/theme_image_helper.dart'; // Import Helper

class ValorantValueCard extends StatelessWidget {
  final LifeValue value;
  final VoidCallback onTap;

  const ValorantValueCard({super.key, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _getScoreColor(value.score);
    final bool isAligned = value.score >= 80;

    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: const _BeveledClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark,
            border: Border(
              bottom: BorderSide(color: accentColor, width: 3), // Color bar at bottom
            ),
          ),
          child: Stack(
            children: [
              // Background Image / Pattern 
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15, // Slightly higher for visibility
                  child: Image(
                    image: ThemeImageHelper.getProvider(value.id), // Dynamic
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.3),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (c,e,s) => Container(color: Colors.black),
                  ),
                ),
              ),
              
              // Decorative Border Outline
              Positioned.fill(
                child: CustomPaint(
                  painter: _BorderPainter(color: AppTheme.fhBorderColor.withOpacity(0.3)),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Top Right
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(value.icon, color: accentColor, size: 24),
                    ),
                    
                    const Spacer(),
                    
                    // Title
                    Text(
                      value.title.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.fhTextPrimary,
                        letterSpacing: 1.0,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Score / Status
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAligned ? "ALIGNED" : "PENDING",
                          style: TextStyle(
                            color: AppTheme.fhTextSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${value.score}%",
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: AppTheme.fontDisplay
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.fhAccentTeal;
    if (score >= 50) return AppTheme.fhAccentGold;
    return AppTheme.fhAccentRed;
  }
}

class _BeveledClipper extends CustomClipper<Path> {
  const _BeveledClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    const cut = 16.0;
    
    path.moveTo(0, 0); // Top Left
    path.lineTo(size.width, 0); // Top Right
    path.lineTo(size.width, size.height - cut); // Right side down to cut
    path.lineTo(size.width - cut, size.height); // Cut Bottom Right
    path.lineTo(0, size.height); // Bottom Left
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BorderPainter extends CustomPainter {
  final Color color;
  _BorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const cut = 16.0;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - cut);
    path.lineTo(size.width - cut, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}