import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/theme/app_theme.dart';

class TimetableSession {
  final String subject;
  final String type;
  final Color color;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  TimetableSession({
    required this.subject,
    required this.type,
    required this.color,
    required this.startTime,
    required this.endTime,
  });

  bool get isCurrent {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  bool get isUpcoming {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    return nowMinutes < startMinutes;
  }
}

class TimetableService {
  // Define standard periods
  static const List<Map<String, int>> _periods = [
    {'h': 9, 'm': 30, 'len': 60},  // 1: 09:30 - 10:30
    {'h': 10, 'm': 30, 'len': 60}, // 2: 10:30 - 11:30
    {'h': 11, 'm': 30, 'len': 60}, // 3: 11:30 - 12:30
    {'h': 13, 'm': 30, 'len': 60}, // 4: 13:30 - 14:30
    {'h': 14, 'm': 30, 'len': 60}, // 5: 14:30 - 15:30
  ];

  // Raw Data mapped to periods
  static final Map<int, List<Map<String, dynamic>>> _scheduleRaw = {
    1: [ // Monday
      {'sub': 'English', 'type': 'SEC', 'color': Colors.white},
      {'sub': 'Language', 'type': 'VAC', 'color': Colors.white},
      {'sub': 'ED-I', 'type': 'Najiya', 'color': AppTheme.fhAccentPurple},
      {'sub': 'ED-I', 'type': 'Najiya (lab)', 'color': AppTheme.fhAccentPurple},
      {'sub': 'ED-I', 'type': 'Safeeque (lab)', 'color': AppTheme.fhAccentPurple},
    ],
    2: [ // Tuesday
      {'sub': 'Mech-II', 'type': 'Safeeque', 'color': Colors.blueAccent},
      {'sub': 'English', 'type': 'SEC', 'color': Colors.white},
      {'sub': 'Mod Phy', 'type': 'Najiya', 'color': AppTheme.fhAccentGreen},
      {'sub': 'Mech-II', 'type': 'Najiya (lab)', 'color': Colors.blueAccent},
      {'sub': 'Mech-II', 'type': 'Safeeque (lab)', 'color': Colors.blueAccent},
    ],
    3: [ // Wednesday
      {'sub': 'Mech-II', 'type': 'Najiya', 'color': Colors.blueAccent},
      {'sub': 'Mech-II', 'type': 'Safeeque', 'color': Colors.blueAccent},
      {'sub': 'Mod Phy', 'type': 'Safeeque', 'color': AppTheme.fhAccentGreen},
      {'sub': 'English', 'type': 'VAC', 'color': Colors.white},
      {'sub': 'Language', 'type': 'VAC', 'color': Colors.white},
    ],
    4: [ // Thursday
      {'sub': 'ED-I', 'type': 'Najiya', 'color': AppTheme.fhAccentPurple},
      {'sub': 'English', 'type': 'SEC', 'color': Colors.white},
      {'sub': 'English', 'type': 'VAC', 'color': Colors.white},
      {'sub': 'Mod Phy', 'type': 'Safeeque', 'color': AppTheme.fhAccentGreen},
      {'sub': 'Language', 'type': 'VAC', 'color': Colors.white},
    ],
    5: [ // Friday
      {'sub': 'Mod Phy', 'type': 'Najiya (lab)', 'color': AppTheme.fhAccentGreen},
      {'sub': 'Mod Phy', 'type': 'Safeeque (lab)', 'color': AppTheme.fhAccentGreen},
      {'sub': 'English', 'type': 'SEC', 'color': Colors.white},
      {'sub': 'ED-I', 'type': 'Safeeque', 'color': AppTheme.fhAccentPurple},
      {'sub': 'English', 'type': 'VAC', 'color': Colors.white},
    ],
  };

  List<TimetableSession> getSessionsForDay(int weekday) {
    // weekday: 1 = Monday, 7 = Sunday
    final rawList = _scheduleRaw[weekday];
    if (rawList == null) return [];

    List<TimetableSession> sessions = [];
    for (int i = 0; i < rawList.length && i < _periods.length; i++) {
      final period = _periods[i];
      final item = rawList[i];
      
      final startH = period['h']!;
      final startM = period['m']!;
      final len = period['len']!;
      
      final start = TimeOfDay(hour: startH, minute: startM);
      // Calculate end time manually to handle minute overflow
      int endTotalM = startH * 60 + startM + len;
      final end = TimeOfDay(hour: (endTotalM / 60).floor(), minute: endTotalM % 60);

      sessions.add(TimetableSession(
        subject: item['sub'],
        type: item['type'],
        color: item['color'],
        startTime: start,
        endTime: end,
      ));
    }
    return sessions;
  }

  Map<String, TimetableSession?> getCurrentAndNextSession() {
    final now = DateTime.now();
    final sessions = getSessionsForDay(now.weekday);
    
    TimetableSession? current;
    TimetableSession? next;

    for (var s in sessions) {
      if (s.isCurrent) {
        current = s;
      }
      if (s.isUpcoming) {
        next = s;
        break; // First upcoming is the next one
      }
    }

    return {'current': current, 'next': next};
  }
}