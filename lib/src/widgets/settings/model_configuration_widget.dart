import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ModelConfigurationWidget extends StatefulWidget {
  final AppProvider appProvider;
  final List<String> availableModels;
  final bool isFetching;
  final VoidCallback onFetch;

  const ModelConfigurationWidget({
    super.key,
    required this.appProvider,
    required this.availableModels,
    required this.isFetching,
    required this.onFetch,
  });

  @override
  State<ModelConfigurationWidget> createState() => _ModelConfigurationWidgetState();
}

class _ModelConfigurationWidgetState extends State<ModelConfigurationWidget> {
  
  Widget _buildModelPriorityList(String prefix, List<String> currentList, Function(List<String>) onUpdate, {int slots = 3}) {
    // Ensure we have `slots` slots
    List<String> list = List.from(currentList);
    while (list.length < slots) {
      list.add(widget.availableModels.isNotEmpty ? widget.availableModels.first : 'gemini-2.0-flash');
    }

    return Column(
      children: List.generate(slots, (index) {
        final label = index == 0 ? "Primary $prefix Model" : "$prefix Fallback $index";
        final currentSelection = list[index];

        // Ensure selection exists in available, otherwise add it temporarily
        final effectiveItems = {
          ...widget.availableModels,
          if (!widget.availableModels.contains(currentSelection)) currentSelection
        }.toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: effectiveItems.contains(currentSelection) ? currentSelection : null,
            decoration: InputDecoration(
              labelText: label,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: const OutlineInputBorder(),
            ),
            dropdownColor: AppTheme.fhBgMedium,
            items: effectiveItems.map((m) => DropdownMenuItem(
              value: m,
              child: Text(m, overflow: TextOverflow.ellipsis, maxLines: 1),
            )).toList(),
            onChanged: (val) {
              if (val != null) {
                final newList = List<String>.from(list);
                newList[index] = val;
                onUpdate(newList);
              }
            },
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = widget.appProvider;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.robotHappyOutline,
                    color: (provider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed),
                    size: 22),
                const SizedBox(width: 10),
                Text('AI Configuration',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            Divider(height: 24, thickness: 0.5, color: AppTheme.fhBorderColor.withValues(alpha: 0.5)),
            
            // --- Lite Models Section ---
            Text("Lite Models (Fast - for Sub-missions & Chat)",
                style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.fhAccentTeal)),
            const SizedBox(height: 8),
            _buildModelPriorityList(
                "Lite", provider.settings.liteModels,
                (newList) {
                  provider.setSettings(provider.settings..liteModels = newList);
                }),
            const SizedBox(height: 16),

            // --- Heavy Models Section ---
            Text("Pro Models (Advanced - for Projects)",
                style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.fhAccentPurple)),
            const SizedBox(height: 8),
            _buildModelPriorityList(
                "Pro", provider.settings.heavyModels,
                (newList) {
                  provider.setSettings(provider.settings..heavyModels = newList);
                }),
            const SizedBox(height: 16),

            // --- Live Models Section ---
            Text("Live Models (Realtime - Nora's default)",
                style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.fhAccentOrange)),
            const SizedBox(height: 8),
            _buildModelPriorityList(
                "Live", provider.settings.liveModels,
                (newList) {
                  provider.setSettings(provider.settings..liveModels = newList);
                }, slots: 2),
            const SizedBox(height: 16),

            // Refetch Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: widget.isFetching
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(MdiIcons.refresh, size: 18),
                label: const Text("REFETCH AVAILABLE MODELS"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.fhAccentTeal,
                  side: BorderSide(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
                ),
                onPressed: widget.isFetching ? null : widget.onFetch,
              ),
            ),
          ],
        ),
      ),
    );
  }
}