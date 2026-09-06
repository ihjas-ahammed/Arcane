import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusScheduleGrid extends StatelessWidget {
  final List<String> scheduleList;
  final String? nextBusTime;
  final String? selectedTime;
  final bool isEditMode;
  final Function(String) onRemove;
  final Function(String) onEdit;
  final Function(String)? onSelectTime;
  final int Function(String) timeToMinutes;

  const BusScheduleGrid({
    super.key,
    required this.scheduleList,
    required this.nextBusTime,
    this.selectedTime,
    required this.isEditMode,
    required this.onRemove,
    required this.onEdit,
    this.onSelectTime,
    required this.timeToMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: scheduleList.length,
      itemBuilder: (context, index) {
        final time = scheduleList[index];
        final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
        final itemMinutes = timeToMinutes(time);
        final isPassed = itemMinutes < nowMinutes;
        final isNext = !isEditMode && nextBusTime == time;
        final isSelected = !isEditMode && selectedTime == time;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              if (isEditMode) {
                onEdit(time);
              } else {
                onSelectTime?.call(time);
              }
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isNext
                    ? JweTheme.accentAmber
                    : (isSelected
                        ? JweTheme.accentCyan.withValues(alpha: 0.18)
                        : (isPassed ? Colors.transparent : JweTheme.panel)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isNext
                      ? JweTheme.accentAmber
                      : (isSelected
                          ? JweTheme.accentCyan
                          : (isPassed
                              ? JweTheme.textMuted.withValues(alpha: 0.25)
                              : JweTheme.border)),
                  width: (isNext || isSelected) ? 1.5 : 1.0,
                ),
                boxShadow: isNext
                    ? [
                        BoxShadow(
                          color: JweTheme.accentAmber.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ]
                    : (isSelected
                        ? [
                            BoxShadow(
                              color: JweTheme.accentCyan.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ]
                        : null),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      time,
                      style: GoogleFonts.jetBrainsMono(
                        color: isNext
                            ? JweTheme.onAccent
                            : (isSelected
                                ? JweTheme.accentCyan
                                : (isPassed
                                    ? JweTheme.textMuted.withValues(alpha: 0.5)
                                    : JweTheme.textWhite)),
                        fontWeight: (isNext || isSelected) ? FontWeight.bold : FontWeight.w500,
                        fontSize: 11.5,
                        decoration: isPassed && !isEditMode && !isSelected
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: JweTheme.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (isEditMode)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: IconButton(
                      icon: Icon(Icons.close, color: JweTheme.accentRed, size: 14),
                      onPressed: () => onRemove(time),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}