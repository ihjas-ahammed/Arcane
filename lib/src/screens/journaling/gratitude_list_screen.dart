import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:arcane/src/widgets/dialogs/add_gratitude_dialog.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class GratitudeListScreen extends StatelessWidget {
  const GratitudeListScreen({super.key});

  void _showAddDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => const AddGratitudeDialog()
    ).then((newItem) {
      if (newItem != null && newItem is GratitudeItem) {
        final currentList = List<GratitudeItem>.from(provider.chatbotMemory.gratitudeList);
        currentList.insert(0, newItem); 
        provider.updateGratitudeList(currentList);
      }
    });
  }

  void _removeItem(AppProvider provider, String id) {
    final currentList = List<GratitudeItem>.from(provider.chatbotMemory.gratitudeList);
    currentList.removeWhere((item) => item.id == id);
    provider.updateGratitudeList(currentList);
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
    final items = provider.chatbotMemory.gratitudeList;

    return Scaffold(
      backgroundColor: PersonInfoTheme.bgDark,
      appBar: AppBar(
        title: Text("GRATITUDE & ASSETS", style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyCyan, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: PersonInfoTheme.textWhite),
        actions: [
          IconButton(
            icon:  Icon(MdiIcons.plusBox, color: PersonInfoTheme.spideyCyan),
            onPressed: () => _showAddDialog(context, provider),
          )
        ],
      ),
      body: SafeArea(
        child: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MdiIcons.handHeart, size: 64, color: PersonInfoTheme.textGrey.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text("NO ENTRIES YET", style: GoogleFonts.rajdhani(color: PersonInfoTheme.textGrey, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
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
                          const Text("No additional details provided.", style: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 12, fontStyle: FontStyle.italic))
                      ],
                    ),
                  ),
                );
              },
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