import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class BusHomeWidget extends StatelessWidget {
  final String origin;
  final String destination;
  final String nextTime;
  final String nextSubStop;
  final bool isOnBus;
  final int speedKmh;
  final int minutesRemaining;

  const BusHomeWidget({
    super.key,
    required this.origin,
    required this.destination,
    required this.nextTime,
    this.nextSubStop = '',
    this.isOnBus = false,
    this.speedKmh = 0,
    this.minutesRemaining = -1,
  });

  @override
  Widget build(BuildContext context) {
    final bgPanel = JweTheme.isLight ? JweTheme.panel : const Color(0xFF0D1426);
    final bgDeep = JweTheme.onAccent;
    final accentAmber = JweTheme.accentAmber;
    final accentCyan = JweTheme.accentCyan;
    final accentTeal = JweTheme.accentTeal;
    final textWhite = JweTheme.textWhite;
    final textMid = JweTheme.textMid;
    final textMuted = JweTheme.textMuted;

    final statusBadge = isOnBus ? "[ ON BUS // TRANSIT ACTIVE ]" : "[ BUS RADAR // STANDBY ]";
    final speedLabel = isOnBus && speedKmh > 0 ? "SPEED: $speedKmh KM/H" : "GPS: ACTIVE";

    final mainTimeText = isOnBus && minutesRemaining >= 0
        ? "ETA ~${minutesRemaining}M TO ${destination.toUpperCase()}"
        : nextTime;

    final subStopInfo = nextSubStop.isNotEmpty
        ? (isOnBus ? "NEXT STOP: ${nextSubStop.toUpperCase()}" : "VIA: ${nextSubStop.toUpperCase()}")
        : (minutesRemaining >= 0 ? "DEPARTS IN $minutesRemaining MIN" : "CHECK SCHEDULE");

    final borderColor = isOnBus ? accentTeal : accentAmber;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgPanel,
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      color: isOnBus ? accentTeal : accentAmber,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  speedLabel,
                  style: TextStyle(
                    color: textMuted,
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // Route Name
            Text(
              "${origin.toUpperCase()} → ${destination.toUpperCase()}",
              style: TextStyle(
                color: textMid,
                fontSize: 11,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Main Time
            Text(
              mainTimeText,
              style: TextStyle(
                color: textWhite,
                fontSize: 24,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Sub-Stop / Telemetry info
            Text(
              subStopInfo,
              style: TextStyle(
                color: accentCyan,
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: accentAmber, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "⇄ SWAP",
                      style: TextStyle(
                        color: accentAmber,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: accentAmber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "TIMETABLE",
                      style: TextStyle(
                        color: bgDeep,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
