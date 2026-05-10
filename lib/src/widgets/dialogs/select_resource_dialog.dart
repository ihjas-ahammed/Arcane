import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SelectResourceDialog extends StatefulWidget {
  final List<String> selectedIds;
  final Color accentColor;

  const SelectResourceDialog({
    super.key,
    required this.selectedIds,
    required this.accentColor,
  });

  @override
  State<SelectResourceDialog> createState() => _SelectResourceDialogState();
}

class _SelectResourceDialogState extends State<SelectResourceDialog> {
  late Set<String> _currentSelection;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentSelection = Set<String>.from(widget.selectedIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_currentSelection.contains(id)) {
        _currentSelection.remove(id);
      } else {
        _currentSelection.add(id);
      }
    });
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
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Filter and Sort
    var items = provider.chatbotMemory.gratitudeList.toList();
    if (_searchQuery.isNotEmpty) {
      items = items.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Dialog(
      backgroundColor: AppTheme.fhBgMedium,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: widget.accentColor, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5)))),
            child: Row(
              children: [
                Icon(MdiIcons.databaseSearchOutline, color: widget.accentColor),
                const SizedBox(width: 12),
                Text("ASSIGN ASSETS", style: GoogleFonts.chakraPetch(color: AppTheme.fhTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: AppTheme.fhTextPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: "SEARCH...",
                hintStyle: TextStyle(color: AppTheme.fhTextDisabled.withOpacity(0.5), fontSize: 12, letterSpacing: 1.0),
                prefixIcon: const Icon(Icons.search, color: AppTheme.fhTextSecondary, size: 18),
                filled: true,
                fillColor: AppTheme.fhBgDark,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: const OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
          
          Flexible(
            child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text("No matching assets found.", style: TextStyle(color: AppTheme.fhTextDisabled), textAlign: TextAlign.center),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _currentSelection.contains(item.id);
                    
                    return GestureDetector(
                      onTap: () => _toggleSelection(item.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? widget.accentColor.withOpacity(0.1) : AppTheme.fhBgDark,
                          border: Border.all(color: isSelected ? widget.accentColor : AppTheme.fhBorderColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(_getIconForType(item.type), color: isSelected ? widget.accentColor : AppTheme.fhTextSecondary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name.toUpperCase(), style: TextStyle(color: isSelected ? AppTheme.fhTextPrimary : AppTheme.fhTextSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(item.type.toUpperCase(), style: TextStyle(color: isSelected ? widget.accentColor : AppTheme.fhTextDisabled, fontSize: 10)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(MdiIcons.checkBold, color: widget.accentColor, size: 20)
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.fhTextSecondary,
                      side: const BorderSide(color: AppTheme.fhBorderColor),
                      shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCEL"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      foregroundColor: Colors.black,
                      shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                    ),
                    onPressed: () => Navigator.pop(context, _currentSelection.toList()),
                    child: const Text("CONFIRM", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}