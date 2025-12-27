import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:arcane/src/theme/app_theme.dart';

class JsonEditorWidget extends StatelessWidget {
  final dynamic data;
  final ValueChanged<dynamic> onChanged;
  final String label;

  const JsonEditorWidget({
    super.key,
    required this.data,
    required this.onChanged,
    this.label = 'Root',
  });

  @override
  Widget build(BuildContext context) {
    if (data is Map) {
      return _buildMapNode(context, data as Map, label);
    } else if (data is List) {
      return _buildListNode(context, data as List, label);
    } else {
      return _buildLeafNode(context, data, label);
    }
  }

  Widget _buildMapNode(BuildContext context, Map map, String keyLabel) {
    return ExpansionTile(
      title: Text(keyLabel,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary)),
      subtitle: Text("Map (${map.length} items)",
          style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
      childrenPadding: const EdgeInsets.only(left: 16),
      collapsedIconColor: AppTheme.fhTextSecondary,
      iconColor: AppTheme.fhAccentTeal,
      children: [
        ...map.entries.map((entry) {
          return JsonEditorWidget(
            label: entry.key.toString(),
            data: entry.value,
            onChanged: (newValue) {
              final newMap = Map.from(map);
              newMap[entry.key] = newValue;
              onChanged(newMap);
            },
          );
        }),
        // Add capability could be here
      ],
    );
  }

  Widget _buildListNode(BuildContext context, List list, String keyLabel) {
    return ExpansionTile(
      title: Text(keyLabel,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppTheme.fhTextPrimary)),
      subtitle: Text("List (${list.length} items)",
          style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
      childrenPadding: const EdgeInsets.only(left: 16),
      collapsedIconColor: AppTheme.fhTextSecondary,
      iconColor: AppTheme.fhAccentTeal,
      children: [
        ...list.asMap().entries.map((entry) {
          return JsonEditorWidget(
            label: "[${entry.key}]",
            data: entry.value,
            onChanged: (newValue) {
              final newList = List.from(list);
              newList[entry.key] = newValue;
              onChanged(newList);
            },
          );
        }),
        // Add item capability could be here
      ],
    );
  }

  Widget _buildLeafNode(BuildContext context, dynamic value, String keyLabel) {
    return ListTile(
      title: Text(keyLabel,
          style:
              const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12)),
      subtitle: Text(value?.toString() ?? "null",
          style: const TextStyle(
              color: AppTheme.fhTextPrimary,
              fontFamily: 'RobotoMono',
              fontSize: 14)),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 16, color: AppTheme.fhAccentGold),
        onPressed: () => _editValue(context, value),
      ),
    );
  }

  Future<void> _editValue(BuildContext context, dynamic currentValue) async {
    final controller =
        TextEditingController(text: currentValue?.toString() ?? "");
    dynamic newValue;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.fhBgDark,
        title: Text("Edit $label",
            style: const TextStyle(color: AppTheme.fhTextPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.fhTextPrimary),
              decoration: const InputDecoration(
                filled: true,
                fillColor: AppTheme.fhBgMedium,
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 8),
            Text(
              "Original Type: ${currentValue.runtimeType}",
              style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Save",
                style: TextStyle(color: AppTheme.fhAccentTeal)),
            onPressed: () {
              final text = controller.text;
              if (currentValue is int) {
                newValue = int.tryParse(text) ?? currentValue;
              } else if (currentValue is double) {
                newValue = double.tryParse(text) ?? currentValue;
              } else if (currentValue is bool) {
                newValue = text.toLowerCase() == 'true';
              } else {
                newValue = text;
              }
              Navigator.pop(context);
              onChanged(newValue);
            },
          ),
        ],
      ),
    );
  }
}
