import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SavedPromptsList extends StatelessWidget {
  final Function(String) onSelect;

  const SavedPromptsList({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final savedPrompts = provider.settings.savedPrompts;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Saved Prompts",
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (savedPrompts.isEmpty)
          const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text("No saved prompts yet.",
                    style: TextStyle(
                        color: AppTheme.fhTextSecondary,
                        fontStyle: FontStyle.italic)),
              ))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: savedPrompts.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final prompt = savedPrompts[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.2)),
                ),
                child: ListTile(
                  title: Text(
                    prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppTheme.fhTextPrimary),
                  ),
                  onTap: () => onSelect(prompt),
                  trailing: IconButton(
                    icon: Icon(MdiIcons.deleteOutline, size: 20, color: AppTheme.fhAccentRed.withOpacity(0.7)),
                    onPressed: () {
                      final updatedList = List<String>.from(savedPrompts)..removeAt(index);
                      provider.setSettings(provider.settings..savedPrompts = updatedList);
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}