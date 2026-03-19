import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:arcane/src/widgets/dialogs/select_resource_dialog.dart';
import 'package:arcane/src/widgets/dialogs/asset_info_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/task_models.dart';

class ActionPlanResourcesCard extends StatelessWidget {
  final String initialResources;
  final ValueChanged<String> onChanged;
  final Color accentColor;
  // Added to enable auto-assignment context
  final String? mainTaskId;
  final String? subTaskId;

  const ActionPlanResourcesCard({
    super.key,
    required this.initialResources,
    required this.onChanged,
    required this.accentColor,
    this.mainTaskId,
    this.subTaskId,
  });

  List<String> _getSelectedIds() {
    if (initialResources.isEmpty) return [];
    try {
      final decoded = jsonDecode(initialResources);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      return initialResources.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  void _openSelector(BuildContext context) async {
    final currentIds = _getSelectedIds();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => SelectResourceDialog(
        selectedIds: currentIds,
        accentColor: accentColor,
      ),
    );

    if (result != null) {
      onChanged(jsonEncode(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = _getSelectedIds();
    final provider = Provider.of<AppProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Container(
          margin: const EdgeInsets.only(top: 15, bottom: 5),
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "REQUIRED ASSETS",
                style: TextStyle(
                  color: AppTheme.fhTextSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Row(
                children: [
                  if (mainTaskId != null && subTaskId != null)
                    InkWell(
                      onTap: provider.loadingTaskName == "Scanning Assets..." ? null : () => provider.aiGenerationActions.autoAssignAssets(mainTaskId!, subTaskId!),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                        child: Text(
                          provider.loadingTaskName == "Scanning Assets..." ? "SCANNING..." : "AUTO-ASSIGN (AI)",
                          style: TextStyle(color: PersonInfoTheme.spideyCyan, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: () => _openSelector(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                      child: Text(
                        "ASSIGN ASSET",
                        style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark.withOpacity(0.5),
            border: Border.all(color: AppTheme.fhBorderColor),
          ),
          child: selectedIds.isEmpty
            ? const Text(
                "No assets assigned.", 
                style: TextStyle(color: AppTheme.fhTextDisabled, fontStyle: FontStyle.italic, fontSize: 12)
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedIds.map((id) {
                  return _ResourceChipBuilder(id: id, accentColor: accentColor);
                }).toList(),
              )
        )
      ],
    );
  }
}

class _ResourceChipBuilder extends StatelessWidget {
  final String id;
  final Color accentColor;

  const _ResourceChipBuilder({required this.id, required this.accentColor});

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
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final item = provider.chatbotMemory.gratitudeList.where((g) => g.id == id).firstOrNull;
        if (item == null) return const SizedBox.shrink(); 
        var name = item.name;
        if(item.name.length > 40) name = name.substring(0,40)+"...";

        return InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AssetInfoDialog(item: item)
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              border: Border.all(color: accentColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getIconForType(item.type), size: 14, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  name.toUpperCase(),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.chakraPetch(color: AppTheme.fhTextPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}