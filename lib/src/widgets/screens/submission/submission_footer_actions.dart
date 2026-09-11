import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class SubmissionFooterActions extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const SubmissionFooterActions({
    super.key,
    required this.onComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 1,
          color: JweTheme.lineAmber,
          margin: const EdgeInsets.only(bottom: 20),
        ),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onComplete,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: JweTheme.accentTeal.withValues(alpha: 0.12),
                    border: Border.all(color: JweTheme.accentTeal),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        MdiIcons.checkCircleOutline,
                        color: JweTheme.accentTeal,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "COMPLETE",
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.accentTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: JweTheme.accentRed),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        MdiIcons.deleteOutline,
                        color: JweTheme.accentRed,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "DELETE",
                        style: GoogleFonts.rajdhani(
                          color: JweTheme.accentRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
