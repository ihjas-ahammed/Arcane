import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/widgets/dialogs/add_gratitude_dialog.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class GratitudeListScreen extends StatefulWidget {
  const GratitudeListScreen({super.key});

  @override
  State<GratitudeListScreen> createState() => _GratitudeListScreenState();
}

class _GratitudeListScreenState extends State<GratitudeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddOrEditDialog(BuildContext context, AppProvider provider, [GratitudeItem? item]) {
    showDialog(
      context: context,
      builder: (_) => AddGratitudeDialog(initialItem: item)
    ).then((updatedItem) {
      if (updatedItem != null && updatedItem is GratitudeItem) {
        provider.updateGratitudeItem(updatedItem);
      }
    });
  }

  void _removeItem(AppProvider provider, String id) {
    final currentList = List<GratitudeItem>.from(provider.chatbotMemory.gratitudeList);
    currentList.removeWhere((item) => item.id == id);
    provider.updateGratitudeList(currentList);
  }

  Future<void> _scanLogsForAssets(BuildContext context, AppProvider provider) async {
    try {
      await provider.journalingActions.extractAndSaveAssets();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Asset Scan Complete.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  IconData _getIconForType(String type) {
    switch(type.toLowerCase()) {
      case 'skill': return MdiIcons.lightningBolt;
      case 'person': return MdiIcons.accountHeart;
      case 'object': return MdiIcons.cubeOutline;
      case 'resource': return MdiIcons.bookOpenVariant;
      default: return MdiIcons.starFourPoints;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    
    // Filter and Sort
    var items = provider.chatbotMemory.gratitudeList.toList();
    if (_searchQuery.isNotEmpty) {
      items = items.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      backgroundColor: PersonInfoTheme.bgDark,
      appBar: AppBar(
        title: Text("GRATITUDE & ASSETS", style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: PersonInfoTheme.textWhite),
        actions: [
          provider.loadingTaskName == "Extracting Assets..." 
            ? const Center(child: Padding(padding: EdgeInsets.only(right: 16.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.fhAccentPurple))))
            : IconButton(
                icon: Icon(MdiIcons.databaseSearchOutline, color: AppTheme.fhAccentPurple),
                tooltip: "Scan Logs for Assets",
                onPressed: () => _scanLogsForAssets(context, provider),
              ),
          IconButton(
            icon: Icon(MdiIcons.plusBox, color: PersonInfoTheme.spideyCyan),
            onPressed: () => _showAddOrEditDialog(context, provider),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: PersonInfoTheme.bgDark,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: PersonInfoTheme.textWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "SEARCH ASSETS...",
                  hintStyle: TextStyle(color: PersonInfoTheme.textGrey.withOpacity(0.5), fontSize: 12, letterSpacing: 1.0),
                  prefixIcon: const Icon(Icons.search, color: PersonInfoTheme.spideyCyan, size: 20),
                  filled: true,
                  fillColor: PersonInfoTheme.bgPanel,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: PersonInfoTheme.spideyCyan, width: 1)),
                ),
              ),
            ),
            
            Expanded(
              child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.handHeart, size: 64, color: PersonInfoTheme.textGrey.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(_searchQuery.isEmpty ? "NO ENTRIES YET" : "NO MATCHES FOUND", style: GoogleFonts.rajdhani(color: PersonInfoTheme.textGrey, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: PersonInfoTheme.spideyRed,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _removeItem(provider, item.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: PersonInfoTheme.bgPanel,
                            border: Border(left: BorderSide(color: PersonInfoTheme.spideyCyan, width: 4)),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]
                          ),
                          child: ExpansionTile(
                            iconColor: PersonInfoTheme.spideyCyan,
                            collapsedIconColor: PersonInfoTheme.textGrey,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: PersonInfoTheme.spideyCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4)
                              ),
                              child: Icon(_getIconForType(item.type), color: PersonInfoTheme.spideyCyan, size: 20),
                            ),
                            title: Text(
                              item.name.toUpperCase(), 
                              style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                            ),
                            subtitle: Text(
                              item.type.toUpperCase(),
                              style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyCyanDim, fontSize: 12, fontWeight: FontWeight.w600)
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            expandedCrossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.why.isNotEmpty) _buildDetailRow("WHY", item.why),
                              if (item.how.isNotEmpty) _buildDetailRow("HOW", item.how),
                              if (item.what.isNotEmpty) _buildDetailRow("WHAT", item.what),
                              if (item.why.isEmpty && item.how.isEmpty && item.what.isEmpty)
                                const Text("No additional details provided.", style: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 12, fontStyle: FontStyle.italic)),
                              
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showAddOrEditDialog(context, provider, item),
                                  icon: Icon(MdiIcons.pencil, size: 14),
                                  label: const Text("EDIT DATA"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: PersonInfoTheme.textGrey,
                                    side: const BorderSide(color: Color(0xFF1f2f40)),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyRed, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: PersonInfoTheme.textWhite, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}