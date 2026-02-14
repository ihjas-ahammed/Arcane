import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/models/task_models.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/widgets/dialogs/color_selector_dialog.dart';

class ProtocolControlPanel extends StatelessWidget {
  final List<MainTask> protocols;
  final String? selectedProtocolId;
  final Function(String) onSelect;
  final Function(MainTask) onEdit;
  final VoidCallback onAdd;

  const ProtocolControlPanel({
    super.key,
    required this.protocols,
    required this.selectedProtocolId,
    required this.onSelect,
    required this.onEdit,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.fhBgDeepDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.5))),
              color: AppTheme.fhBgDark,
            ),
            child: Row(
              children: [
                Icon(MdiIcons.consoleLine, color: AppTheme.fhAccentTeal),
                const SizedBox(width: 12),
                const Text(
                  "PROTOCOL CONTROL",
                  style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: AppTheme.fhTextPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.fhTextSecondary),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: protocols.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final protocol = protocols[index];
                final isSelected = protocol.id == selectedProtocolId;
                
                return GestureDetector(
                  onTap: () => onSelect(protocol.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? protocol.taskColor.withOpacity(0.1) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? protocol.taskColor : AppTheme.fhBorderColor.withOpacity(0.3),
                        width: isSelected ? 2 : 1
                      ),
                      borderRadius: BorderRadius.circular(4), // Slightly rounded for comfort
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Color Indicator / Selector
                        GestureDetector(
                          onTap: () => _showColorPicker(context, protocol),
                          child: Container(
                            width: 16, height: 16,
                            decoration: BoxDecoration(
                              color: protocol.taskColor,
                              border: Border.all(color: Colors.white30),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                protocol.name.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? AppTheme.fhTextPrimary : AppTheme.fhTextSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  fontFamily: AppTheme.fontDisplay,
                                  letterSpacing: 1.0
                                ),
                              ),
                              Text(
                                protocol.theme.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? protocol.taskColor : AppTheme.fhTextDisabled,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Edit Action
                        IconButton(
                          icon: Icon(MdiIcons.pencilOutline, size: 20, color: AppTheme.fhTextSecondary),
                          onPressed: () => onEdit(protocol),
                        ),
                        
                        if (isSelected)
                          Icon(MdiIcons.checkBold, color: protocol.taskColor, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Add Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ValorantButton(
              label: "INITIALIZE NEW PROTOCOL",
              icon: MdiIcons.plus,
              isPrimary: true,
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, MainTask protocol) {
    showDialog(
      context: context,
      builder: (ctx) => ColorSelectorDialog(
        selectedColor: protocol.taskColor,
        onColorSelected: (color) {
          final hex = color.value.toRadixString(16).toUpperCase().substring(2);
          // We need to trigger an update. Since MainTask is immutable-ish in provider lists without action,
          // we use the onEdit callback or a direct action if available.
          // For simplicity, we assume onEdit handles full updates, but here we just want color.
          // Let's modify the copy and pass it to onEdit.
          final updated = protocol.copyWith(colorHex: hex);
          onEdit(updated);
        },
      ),
    );
  }
}