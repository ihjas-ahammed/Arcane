import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

class BusScheduleScreen extends StatefulWidget {
  const BusScheduleScreen({super.key});

  @override
  State<BusScheduleScreen> createState() => _BusScheduleScreenState();
}

class _BusScheduleScreenState extends State<BusScheduleScreen> {
  String _origin = "S.S College";
  String _destination = "EDAVANNAPPARA";
  late Timer _timer;
  String _currentTimeStr = "";

  final List<String> _locations = ["S.S College", "EDAVANNAPPARA", "AREEKODE"];

  // Data Structure (Same as before)
  final Map<String, Map<String, List<String>>> _schedules = {
    "S.S College": {
      "EDAVANNAPPARA": [
        "06:30 AM",
        "06:35 AM",
        "06:40 AM",
        "06:55 AM",
        "07:20 AM",
        "07:40 AM",
        "07:55 AM",
        "08:10 AM",
        "08:15 AM",
        "08:30 AM",
        "08:40 AM",
        "08:50 AM",
        "09:05 AM",
        "09:25 AM",
        "09:40 AM",
        "10:05 AM",
        "10:13 AM",
        "10:18 AM",
        "10:40 AM",
        "10:50 AM",
        "11:05 AM",
        "11:20 AM",
        "11:38 AM",
        "11:55 AM",
        "12:03 PM",
        "12:18 PM",
        "12:30 PM",
        "12:40 PM",
        "01:08 PM",
        "01:32 PM",
        "01:42 PM",
        "01:50 PM",
        "01:55 PM",
        "02:05 PM",
        "02:15 PM",
        "02:25 PM",
        "02:48 PM",
        "03:00 PM",
        "03:10 PM",
        "03:25 PM",
        "03:40 PM",
        "04:05 PM",
        "04:20 PM",
        "04:37 PM",
        "04:50 PM",
        "04:55 PM",
        "05:10 PM",
        "05:22 PM",
        "05:35 PM",
        "05:45 PM",
        "05:53 PM",
        "05:55 PM",
        "06:03 PM",
        "06:13 PM",
        "06:23 PM",
        "06:35 PM"
      ],
      "AREEKODE": [
        "07:06 AM",
        "07:28 AM",
        "07:43 AM",
        "07:53 AM",
        "08:03 AM",
        "08:20 AM",
        "08:35 AM",
        "08:50 AM",
        "09:13 AM",
        "09:23 AM",
        "09:35 AM",
        "09:43 AM",
        "10:02 AM",
        "10:20 AM",
        "10:31 AM",
        "10:35 AM",
        "10:53 AM",
        "11:03 AM",
        "11:20 AM",
        "11:30 AM",
        "11:38 AM",
        "11:58 AM",
        "12:18 PM",
        "12:28 PM",
        "12:33 PM",
        "12:43 PM",
        "12:50 PM",
        "01:03 PM",
        "01:11 PM",
        "01:18 PM",
        "01:31 PM",
        "01:48 PM",
        "02:03 PM",
        "02:16 PM",
        "02:33 PM",
        "02:48 PM",
        "03:10 PM",
        "03:38 PM",
        "03:48 PM",
        "03:58 PM",
        "04:08 PM",
        "04:16 PM",
        "04:33 PM",
        "04:50 PM",
        "04:58 PM",
        "05:10 PM",
        "05:18 PM",
        "05:38 PM",
        "05:43 PM",
        "06:01 PM",
        "06:10 PM",
        "06:18 PM",
        "06:23 PM",
        "06:38 PM",
        "06:48 PM",
        "07:08 PM"
      ]
    },
    "EDAVANNAPPARA": {
      "S.S College": [
        "08:00 AM",
        "08:15 AM",
        "08:35 AM",
        "08:55 AM",
        "09:15 AM",
        "09:30 AM",
        "09:45 AM",
        "10:10 AM",
        "10:20 AM",
        "10:35 AM",
        "10:50 AM",
        "11:10 AM",
        "11:25 AM",
        "11:40 AM",
        "12:00 PM",
        "12:15 PM",
        "12:30 PM",
        "12:45 PM",
        "01:00 PM",
        "01:15 PM",
        "01:30 PM",
        "01:45 PM",
        "02:00 PM",
        "02:15 PM",
        "02:30 PM",
        "02:45 PM",
        "03:00 PM",
        "03:15 PM",
        "03:30 PM",
        "03:45 PM",
        "04:00 PM",
        "04:15 PM",
        "04:30 PM",
        "04:45 PM",
        "05:00 PM",
        "05:15 PM",
        "05:30 PM",
        "05:45 PM",
        "06:00 PM",
        "06:15 PM",
        "06:30 PM"
      ],
      "AREEKODE": [] // Calculated
    },
    "AREEKODE": {
      "S.S College": [], // Calculated
      "EDAVANNAPPARA": [] // Calculated
    }
  };

  @override
  void initState() {
    super.initState();
    _calculateDerivedRoutes();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTimeStr = DateFormat("hh:mm a").format(DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --- Logic Translation ---
  void _calculateDerivedRoutes() {
    _schedules["EDAVANNAPPARA"]!["AREEKODE"] =
        _schedules["EDAVANNAPPARA"]!["S.S College"]!
            .map((t) => _addMinutesToTime(t, 0))
            .toList();

    _schedules["AREEKODE"]!["S.S College"] =
        _schedules["S.S College"]!["EDAVANNAPPARA"]!
            .map((t) => _addMinutesToTime(t, -2))
            .toList();

    _schedules["AREEKODE"]!["EDAVANNAPPARA"] =
        _schedules["S.S College"]!["EDAVANNAPPARA"]!
            .map((t) => _addMinutesToTime(t, -2))
            .toList();
  }

  String _addMinutesToTime(String timeStr, int minutesToAdd) {
    try {
      DateTime parsed = DateFormat("hh:mm a").parse(timeStr);
      DateTime newTime = parsed.add(Duration(minutes: minutesToAdd));
      return DateFormat("hh:mm a").format(newTime);
    } catch (e) {
      return timeStr;
    }
  }

  int _timeToMinutes(String timeStr) {
    try {
      DateTime now = DateTime.now();
      DateTime parsed = DateFormat("hh:mm a").parse(timeStr);
      DateTime combined =
          DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
      return combined.hour * 60 + combined.minute;
    } catch (e) {
      return 0;
    }
  }

  Map<String, dynamic>? _findNextBus() {
    final routes = _schedules[_origin]?[_destination];
    if (routes == null || routes.isEmpty) return null;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    String? nextBusTime;
    int smallestDiff = 99999;
    bool isTomorrow = false;

    for (String time in routes) {
      int busMin = _timeToMinutes(time);
      int diff = busMin - currentMinutes;

      if (diff >= 0 && diff < smallestDiff) {
        smallestDiff = diff;
        nextBusTime = time;
      }
    }

    if (nextBusTime == null && routes.isNotEmpty) {
      nextBusTime = routes.first;
      isTomorrow = true;
      int busMin = _timeToMinutes(nextBusTime);
      smallestDiff = (busMin + 24 * 60) - currentMinutes;
    }

    if (nextBusTime != null) {
      return {
        "time": nextBusTime,
        "minutes": smallestDiff,
        "tomorrow": isTomorrow
      };
    }
    return null;
  }

  String _getRouteInfo() {
    // ... Logic same as before ...
    return "ROUTE: DIRECT";
  }

  void _swapLocations() {
    setState(() {
      final temp = _origin;
      _origin = _destination;
      _destination = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextBus = _findNextBus();
    final scheduleList = _schedules[_origin]?[_destination] ?? [];

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header (Valorant Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: AppTheme.fhBorderColor.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppTheme.fhTextPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "BUS TIME",
                      style: const TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppTheme.fhTextPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal),
                    ),
                    child: Text(_currentTimeStr,
                        style: const TextStyle(
                            color: AppTheme.fhAccentTeal,
                            fontFamily: 'RobotoMono',
                            fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Route Selection Block
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.fhBgDark.withOpacity(0.5),
                        border: Border.all(color: AppTheme.fhBorderColor),
                      ),
                      child: Column(
                        children: [
                          _buildLocationRow("DEPARTURE", _origin,
                              (val) => setState(() => _origin = val)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: IconButton(
                              icon: Icon(MdiIcons.swapVertical,
                                  color: AppTheme.fhAccentTeal),
                              onPressed: _swapLocations,
                            ),
                          ),
                          _buildLocationRow("DESTINATION", _destination,
                              (val) => setState(() => _destination = val)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Next Bus Big Display
                    if (nextBus != null)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.fhAccentRed.withOpacity(0.1),
                          border: Border(
                              left: BorderSide(
                                  color: AppTheme.fhAccentRed, width: 4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "NEXT DEPLOYMENT",
                              style: TextStyle(
                                  color: AppTheme.fhAccentRed,
                                  fontFamily: AppTheme.fontDisplay,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nextBus['time'],
                              style: const TextStyle(
                                color: AppTheme.fhTextPrimary,
                                fontFamily: AppTheme.fontDisplay,
                                fontSize: 56,
                                height: 0.9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(MdiIcons.timerOutline,
                                    color: AppTheme.fhTextSecondary, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "T-MINUS ${nextBus['minutes']} MINUTES",
                                  style: const TextStyle(
                                      color: AppTheme.fhTextSecondary,
                                      fontFamily: 'RobotoMono',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (nextBus['tomorrow'] == true)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Text("(TOMORROW)",
                                        style: TextStyle(
                                            color: AppTheme.fhAccentOrange,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  )
                              ],
                            )
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Full Schedule List
                    Text(
                      "FULL MANIFEST",
                      style: TextStyle(
                          color: AppTheme.fhTextSecondary,
                          fontFamily: AppTheme.fontDisplay,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    if (scheduleList.isEmpty)
                      const Text("NO INTEL AVAILABLE.",
                          style: TextStyle(color: AppTheme.fhTextDisabled))
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: scheduleList.length,
                        itemBuilder: (context, index) {
                          final time = scheduleList[index];
                          final nowMinutes =
                              DateTime.now().hour * 60 + DateTime.now().minute;
                          final itemMinutes = _timeToMinutes(time);
                          final isPassed = itemMinutes < nowMinutes;
                          final isNext =
                              nextBus != null && nextBus['time'] == time;

                          return Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isNext
                                  ? AppTheme.fhAccentTeal
                                  : (isPassed
                                      ? Colors.transparent
                                      : AppTheme.fhBgDark),
                              border: Border.all(
                                  color: isNext
                                      ? AppTheme.fhAccentTeal
                                      : (isPassed
                                          ? AppTheme.fhTextDisabled
                                              .withOpacity(0.2)
                                          : AppTheme.fhBorderColor)),
                            ),
                            child: Text(
                              time,
                              style: TextStyle(
                                color: isNext
                                    ? AppTheme.fhBgDeepDark
                                    : (isPassed
                                        ? AppTheme.fhTextDisabled
                                        : AppTheme.fhTextPrimary),
                                fontFamily: 'RobotoMono',
                                fontWeight: isNext
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                                decoration: isPassed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(
      String label, String value, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.fhTextSecondary,
                fontSize: 10,
                letterSpacing: 1.0,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _locations.length,
            separatorBuilder: (c, i) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final loc = _locations[index];
              final isSelected = loc == value;
              return GestureDetector(
                onTap: () => onSelect(loc),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.fhAccentTeal.withOpacity(0.1)
                        : Colors.transparent,
                    border: Border.all(
                        color: isSelected
                            ? AppTheme.fhAccentTeal
                            : AppTheme.fhBorderColor),
                  ),
                  child: Text(
                    loc.toUpperCase(),
                    style: TextStyle(
                        color: isSelected
                            ? AppTheme.fhAccentTeal
                            : AppTheme.fhTextSecondary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12),
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}
