import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';

class BusNextCard extends StatelessWidget {
  final Map<String, dynamic>? nextBusData;
  final String routeInfo;

  const BusNextCard({
    super.key,
    required this.nextBusData,
    required this.routeInfo,
  });

  String _formatTimeRemaining(int minutes) {
    if (minutes < 60) {
      return "$minutes min";
    } else {
      final h = (minutes / 60).floor();
      final m = minutes % 60;
      return "${h}h ${m}m";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArcAccents.indigo.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Next Bus", style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          
          if (nextBusData != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  nextBusData!['time'],
                  style: TextStyle(color: JweTheme.textWhite, fontSize: 32, fontWeight: FontWeight.bold)
                ),
                if (nextBusData!['tomorrow'] == true)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4)
                    ),
                    child: const Text("Tomorrow", style: TextStyle(color: Colors.orange, fontSize: 10)),
                  )
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ArcSurfaces.dim(0.2),
                borderRadius: BorderRadius.circular(8)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(MdiIcons.clockOutline, color: JweTheme.textWhite, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        "${_formatTimeRemaining(nextBusData!['minutes'])} remaining",
                        style: TextStyle(color: JweTheme.textWhite)
                      )
                    ],
                  ),
                  Row(
                    children: [
                      Icon(MdiIcons.sourceBranch, color: JweTheme.textWhite, size: 20),
                      const SizedBox(width: 4),
                      Text(routeInfo, style: TextStyle(color: JweTheme.textWhite))
                    ],
                  )
                ],
              ),
            )
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text("No bus schedule available", style: TextStyle(color: JweTheme.textWhite)),
              ),
            )
        ],
      ),
    );
  }
}