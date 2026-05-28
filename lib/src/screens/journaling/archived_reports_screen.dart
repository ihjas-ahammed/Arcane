import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/screens/journaling/weekly_review_screen.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ArchivedReportsScreen extends StatelessWidget {
  const ArchivedReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        title: const Text("ARCHIVED REPORTS", style: TextStyle(color: AppTheme.fhAccentGold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: provider.getArchivedWeeklyReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.fhAccentGold));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: AppTheme.fhAccentRed)));
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MdiIcons.fileDocumentOutline, size: 64, color: AppTheme.fhTextDisabled.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    "NO ARCHIVED REPORTS", 
                    style: TextStyle(color: AppTheme.fhTextSecondary, fontFamily: AppTheme.fontDisplay, fontSize: 18)
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
                  border: Border.all(color: AppTheme.fhAccentGold.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentGold.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(MdiIcons.medalOutline, color: AppTheme.fhAccentGold),
                  ),
                  title: const Text("WEEKLY DEBRIEF", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
                  subtitle: Text(displayDate, style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
                  trailing: Icon(MdiIcons.chevronRight, color: AppTheme.fhTextSecondary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => WeeklyReviewScreen(
                          reportData: reportData,
                        ),
                      ),
                    );
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