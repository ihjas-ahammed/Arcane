import 'dart:async';
import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/services/timetable_service.dart';
import 'package:arcane/src/widgets/ui/timetable_session_card.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final TimetableService _service = TimetableService();
  late Timer _timer;
  int _selectedDay = DateTime.now().weekday;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nowContext = _service.getCurrentAndNextSession();
    final currentSession = nowContext['current'];
    final nextSession = nowContext['next'];
    
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final sessionsForSelectedDay = _service.getSessionsForDay(_selectedDay);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.fhTextPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "ACADEMIC SCHEDULE",
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: AppTheme.fhTextPrimary
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.fhAccentTeal),
                    ),
                    child: Text(
                      DateFormat('HH:mm').format(DateTime.now()),
                      style: const TextStyle(
                        color: AppTheme.fhAccentTeal,
                        fontFamily: 'RobotoMono',
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  )
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Status
                    if (currentSession != null || nextSession != null) ...[
                      const Text("LIVE STATUS", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TimetableSessionCard(
                              label: "CURRENTLY ENGAGED",
                              session: currentSession,
                              isHighlight: currentSession != null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TimetableSessionCard(
                              label: "UP NEXT",
                              session: nextSession,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Day Selector
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 5, // Just Mon-Fri for now
                        separatorBuilder: (c, i) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final dayIndex = index + 1;
                          final isSelected = dayIndex == _selectedDay;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedDay = dayIndex),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.fhAccentTeal : Colors.transparent,
                                border: Border.all(color: isSelected ? AppTheme.fhAccentTeal : AppTheme.fhBorderColor),
                              ),
                              child: Text(
                                days[index],
                                style: TextStyle(
                                  color: isSelected ? AppTheme.fhBgDeepDark : AppTheme.fhTextSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppTheme.fontDisplay,
                                  fontSize: 14
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // List
                    if (sessionsForSelectedDay.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text("NO CLASSES SCHEDULED", style: TextStyle(color: AppTheme.fhTextDisabled, letterSpacing: 1.5)),
                        ),
                      )
                    else
                      ...sessionsForSelectedDay.map((session) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.fhBgDark,
                              border: Border(left: BorderSide(color: session.color, width: 4)),
                            ),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.startTime.format(context),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono', fontSize: 14),
                                    ),
                                    Text(
                                      session.endTime.format(context),
                                      style: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.5), fontFamily: 'RobotoMono', fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.subject.toUpperCase(),
                                        style: const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(MdiIcons.accountTie, size: 14, color: AppTheme.fhTextSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            session.type,
                                            style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      }),
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