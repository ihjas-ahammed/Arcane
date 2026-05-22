import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';

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
    const textStyle = TextStyle(fontFamily: 'RobotoMono', fontSize: 13, color: AppTheme.fhTextPrimary);
    const keyStyle = TextStyle(fontFamily: 'RobotoMono', fontSize: 13, color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold);

    if (data is Map) {
      final map = data as Map;
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(label, style: keyStyle),
          subtitle: Text("{ ${map.length} entries }", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, fontFamily: 'RobotoMono')),
          collapsedIconColor: AppTheme.fhTextSecondary,
          iconColor: AppTheme.fhAccentTeal,
          childrenPadding: const EdgeInsets.only(left: 16),
          children: map.entries.map((entry) {
            return JsonEditorWidget(
              label: entry.key.toString(),
              data: entry.value,
              onChanged: (newValue) {
                final newMap = Map.from(map);
                newMap[entry.key] = newValue;
                onChanged(newMap);
              },
            );
          }).toList(),
        ),
      );
    } else if (data is List) {
      final list = data as List;
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(label, style: keyStyle),
          subtitle: Text("[ ${list.length} items ]", style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, fontFamily: 'RobotoMono')),
          collapsedIconColor: AppTheme.fhTextSecondary,
          iconColor: AppTheme.fhAccentTeal,
          childrenPadding: const EdgeInsets.only(left: 16),
          children: list.asMap().entries.map((entry) {
            return JsonEditorWidget(
              label: "[${entry.key}]",
              data: entry.value,
              onChanged: (newValue) {
                final newList = List.from(list);
                newList[entry.key] = newValue;
                onChanged(newList);
              },
            );
          }).toList(),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Text("$label: ", style: const TextStyle(color: AppTheme.fhTextSecondary, fontFamily: 'RobotoMono', fontSize: 12)),
            Expanded(
              child: InkWell(
                onTap: () => _editValue(context, data),
                child: Text(
                  data?.toString() ?? "null",
                  style: textStyle.copyWith(color: AppTheme.fhTextPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            InkWell(
              onTap: () => _editValue(context, data),
              child: const Icon(Icons.edit, size: 14, color: AppTheme.fhAccentGold),
            )
          ],
        ),
      );
    }
  }

  Future<void> _editValue(BuildContext context, dynamic currentValue) async {
    final controller = TextEditingController(text: currentValue?.toString() ?? "");
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: Text("EDIT VALUE", style: const TextStyle(color: AppTheme.fhTextPrimary, fontFamily: AppTheme.fontDisplay)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.fhTextPrimary, fontFamily: 'RobotoMono'),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(),
          ),
          maxLines: null,
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentTeal),
            onPressed: () {
              // Simple type preservation logic
              dynamic newValue = controller.text;
              if (currentValue is int) newValue = int.tryParse(controller.text) ?? currentValue;
              if (currentValue is double) newValue = double.tryParse(controller.text) ?? currentValue;
              if (currentValue is bool) newValue = controller.text.toLowerCase() == 'true';
              
              Navigator.pop(context);
              onChanged(newValue);
            },
            child: const Text("COMMIT"),
          ),
        ],
      ),
    );
  }
}