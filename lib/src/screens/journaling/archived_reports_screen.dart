import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/screens/journaling/weekly_review_screen.dart';
import 'package:missions/src/screens/journaling/monthly_review_screen.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class ArchivedReportsScreen extends StatefulWidget {
  const ArchivedReportsScreen({super.key});

  @override
  State<ArchivedReportsScreen> createState() => _ArchivedReportsScreenState();
}

class _ArchivedReportsScreenState extends State<ArchivedReportsScreen> {
  String? _regenerateStatus;

  Future<List<Map<String, dynamic>>> _fetchAllReports(AppProvider provider) async {
    final results = await Future.wait([
      provider.getArchivedWeeklyReports(),
      provider.getArchivedMonthlyReports(),
    ]);

    final combined = <Map<String, dynamic>>[
      ...results[0].map((doc) => {...doc, 'type': 'weekly'}),
      ...results[1].map((doc) => {...doc, 'type': 'monthly'}),
    ];

    combined.sort((a, b) => (b['id'] as String? ?? '').compareTo(a['id'] as String? ?? ''));
    return combined;
  }

  Future<void> _regenerateArchivedReport(
    BuildContext context,
    AppProvider provider,
    Map<String, dynamic> doc,
  ) async {
    final isMonthly = doc['type'] == 'monthly';
    final dateId = doc['id'] as String;
    final dateObj = DateTime.tryParse(dateId) ?? DateTime.now();
    final type = isMonthly ? BriefingType.monthly : BriefingType.weekly;

    setState(() {
      _regenerateStatus = 'Regenerating ${isMonthly ? "Monthly Briefing" : "7-Day Review"} for $dateId...';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: StatefulBuilder(
            builder: (ctx, setDialogState) {
              return TacticalBriefingIndicator(
                type: type,
                statusMessage: _regenerateStatus,
              );
            },
          ),
        );
      },
    );

    try {
      if (isMonthly) {
        final regenerated = await provider.reportActions.generateMonthlyReport(
          dateObj,
          (status) {
            if (mounted) setState(() => _regenerateStatus = status);
          },
        );
        await provider.saveMonthlyReport(dateId, regenerated);
      } else {
        final regenerated = await provider.reportActions.generateWeeklyReport(
          dateObj,
          (status) {
            if (mounted) setState(() => _regenerateStatus = status);
          },
        );
        await provider.saveWeeklyReport(dateId, regenerated);
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog
        setState(() {}); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isMonthly ? JweTheme.accentTeal : JweTheme.accentAmber,
            content: Text("${isMonthly ? "Monthly Briefing" : "7-Day Review"} ($dateId) Regenerated & Saved!"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: JweTheme.accentRed,
            content: Text("Regeneration failed: $e"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: Text("ARCHIVED REPORTS", style: TextStyle(color: AppTheme.fhAccentGold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllReports(provider),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppTheme.fhAccentGold));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: AppTheme.fhAccentRed)));
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MdiIcons.fileDocumentOutline, size: 64, color: AppTheme.fhTextDisabled.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    "NO ARCHIVED REPORTS",
                    style: TextStyle(color: AppTheme.fhTextSecondary, fontFamily: AppTheme.fontDisplay, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final doc = reports[index];
              final dateId = doc['id'] as String;
              final reportData = doc['report'] as Map<String, dynamic>? ?? {};
              final isMonthly = doc['type'] == 'monthly';
              final accent = isMonthly ? AppTheme.fhAccentTeal : AppTheme.fhAccentGold;

              DateTime? dateObj;
              try {
                dateObj = DateTime.parse(dateId);
              } catch (_) {}

              final displayDate = dateObj != null
                  ? DateFormat('MMMM dd, yyyy').format(dateObj)
                  : dateId;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark,
                  border: Border.all(color: accent.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        isMonthly ? MdiIcons.calendarMonthOutline : MdiIcons.medalOutline,
                        color: accent),
                  ),
                  title: Text(isMonthly ? "MONTHLY BRIEFING" : "WEEKLY DEBRIEF",
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
                  subtitle: Text(displayDate, style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(MdiIcons.refresh, size: 18, color: accent),
                        tooltip: 'Regenerate Report',
                        onPressed: () => _regenerateArchivedReport(context, provider, doc),
                      ),
                      Icon(MdiIcons.chevronRight, color: AppTheme.fhTextSecondary, size: 20),
                    ],
                  ),
                  onTap: () async {
                    final reportDateStr = reportData['report_date'] as String? ?? doc['id'] as String?;
                    final reportDate = reportDateStr != null ? DateTime.tryParse(reportDateStr) : null;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => isMonthly
                            ? MonthlyReviewScreen(
                                reportData: reportData,
                                provider: provider,
                                targetDate: reportDate,
                              )
                            : WeeklyReviewScreen(
                                reportData: reportData,
                                provider: provider,
                                targetDate: reportDate,
                              ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
