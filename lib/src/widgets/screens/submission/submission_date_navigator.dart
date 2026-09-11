import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/screens/submission/date_nav_btn.dart';

class SubmissionDateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onResetToday;

  const SubmissionDateNavigator({
    super.key,
    required this.selectedDate,
    required this.onPrevious,
    this.onNext,
    this.onResetToday,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    final canGoForward = onNext != null;

    return Container(
      decoration: BoxDecoration(
        color: JweTheme.panel,
        border: Border.all(color: JweTheme.border),
      ),
      child: Row(
        children: [
          DateNavBtn(
            icon: MdiIcons.chevronLeft,
            onTap: onPrevious,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onResetToday,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEE, MMM dd yyyy')
                          .format(selectedDate)
                          .toUpperCase(),
                      style: GoogleFonts.chakraPetch(
                        color: JweTheme.textWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (!isToday) ...[
                      const SizedBox(height: 2),
                      Text(
                        "TAP TO RETURN TODAY",
                        style: TextStyle(
                          color: JweTheme.accentAmber.withValues(alpha: 0.7),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          DateNavBtn(
            icon: MdiIcons.chevronRight,
            enabled: canGoForward,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}
