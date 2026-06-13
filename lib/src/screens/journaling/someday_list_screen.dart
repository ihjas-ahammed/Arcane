import 'package:flutter/material.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/widgets/ui/jwe_panel.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class SomedayListScreen extends StatefulWidget {
  const SomedayListScreen({super.key});

  @override
  State<SomedayListScreen> createState() => _SomedayListScreenState();
}

class _SomedayListScreenState extends State<SomedayListScreen> {
  final TextEditingController _inputController = TextEditingController();

  void _submit(AppProvider provider) {
    final title = _inputController.text.trim();
    if (title.isNotEmpty) {
      provider.addSomedayItem(title);
      _inputController.clear();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final items = provider.settings.somedayList;
    
    // Check for review nudge
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final itemsToReview = items.where((i) => i.createdAt.isBefore(sevenDaysAgo)).length;

    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      appBar: AppBar(
        title: Text("SOMEDAY / MAYBE", style: GoogleFonts.rajdhani(color: JweTheme.accentAmber, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: JweTheme.bgBase,
        iconTheme: IconThemeData(color: JweTheme.accentAmber),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (itemsToReview > 0)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: JweTheme.accentRed.withValues(alpha: 0.1),
                      border: Border.all(color: JweTheme.accentRed, width: 2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: JweTheme.accentRed, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "WEEKLY REVIEW: $itemsToReview ITEMS PENDING CONSCIOUS DECISION.",
                            style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: JwePanel(
                    accentColor: JweTheme.accentCyan,
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: JweTheme.textWhite, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "ZERO-FRICTION CAPTURE...",
                        hintStyle: TextStyle(color: JweTheme.textMuted.withValues(alpha: 0.5), fontSize: 12, letterSpacing: 1.0),
                        filled: true,
                        fillColor: JweTheme.bgBase,
                        border: const OutlineInputBorder(borderSide: BorderSide.none),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan, width: 1)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.subdirectory_arrow_left, color: JweTheme.accentCyan),
                          onPressed: () => _submit(provider),
                        )
                      ),
                      onSubmitted: (_) => _submit(provider),
                      autofocus: true,
                    ),
                  ),
                ),

                Expanded(
                  child: items.isEmpty
                    ? Center(
                        child: Text(
                          "THE HOLDING PATTERN IS EMPTY.",
                          style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isOld = item.createdAt.isBefore(sevenDaysAgo);
                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: JweTheme.accentRed,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) => provider.removeSomedayItem(item.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: JweTheme.panel,
                                border: Border(
                                  left: BorderSide(color: isOld ? JweTheme.accentRed : JweTheme.textMuted, width: 3),
                                  bottom: const BorderSide(color: JweTheme.border),
                                )
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(color: JweTheme.textWhite, fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('MMM dd, yyyy').format(item.createdAt),
                                          style: TextStyle(color: JweTheme.textMuted.withValues(alpha: 0.7), fontSize: 10, fontFamily: 'RobotoMono'),
                                        )
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check, color: JweTheme.accentCyan, size: 20),
                                    tooltip: "Keep in list (Dismiss Review)",
                                    onPressed: () {
                                      // Essentially just updates the timestamp to reset the review nudge
                                      final newItem = SomedayItem(id: item.id, title: item.title, createdAt: DateTime.now());
                                      final newList = List<SomedayItem>.from(items);
                                      newList[index] = newItem;
                                      final newSettings = AppSettings.fromJson(provider.settings.toJson());
                                      newSettings.somedayList = newList;
                                      provider.setSettings(newSettings);
                                    },
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}