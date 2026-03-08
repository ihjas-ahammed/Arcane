import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _currentSelection = Set<String>.from(widget.selectedIds);
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
    final items = provider.chatbotMemory.gratitudeList;

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
          
          Flexible(
            child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text("No assets available. Add them in the Gratitude Log.", style: TextStyle(color: AppTheme.fhTextDisabled), textAlign: TextAlign.center),
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