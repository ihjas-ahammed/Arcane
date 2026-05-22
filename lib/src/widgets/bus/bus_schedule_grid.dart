import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusScheduleGrid extends StatelessWidget {
  final List<String> scheduleList;
  final String? nextBusTime;
  final bool isEditMode;
  final Function(String) onRemove;
  final Function(String) onEdit;
  final int Function(String) timeToMinutes;

  const BusScheduleGrid({
    super.key,
    required this.scheduleList,
    required this.nextBusTime,
    required this.isEditMode,
    required this.onRemove,
    required this.onEdit,
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

        return GestureDetector(
          onTap: () {
            if (isEditMode) {
              onEdit(time);
            }
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isNext
                  ? JweTheme.accentAmber
                  : (isPassed
                      ? Colors.transparent
                      : JweTheme.panel),
              border: Border.all(
                  color: isNext
                      ? JweTheme.accentAmber
                      : (isPassed
                          ? JweTheme.textMuted.withOpacity(0.2)
                          : JweTheme.border)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    time,
                    style: TextStyle(
                      color: isNext
                          ? Colors.black
                          : (isPassed
                              ? JweTheme.textMuted.withOpacity(0.5)
                              : JweTheme.textWhite),
                      fontFamily: 'RobotoMono',
                      fontWeight: isNext
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                      decoration: isPassed && !isEditMode
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (isEditMode)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: JweTheme.accentRed, size: 14),
                      onPressed: () => onRemove(time),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}