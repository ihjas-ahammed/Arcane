import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ApiKeyManager extends StatefulWidget {
  const ApiKeyManager({super.key});

  @override
  State<ApiKeyManager> createState() => _ApiKeyManagerState();
}

class _ApiKeyManagerState extends State<ApiKeyManager> {
  final TextEditingController _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _addKey() {
    final key = _keyController.text.trim();
    if (key.isNotEmpty) {
      final provider = context.read<AppProvider>();
      provider.addCustomApiKey(key);
      _keyController.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final keys = provider.settings.customApiKeys;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (keys.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "No custom API keys added. Using built-in keys.",
              style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: keys.length,
            separatorBuilder: (c, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final key = keys[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(MdiIcons.keyVariant, color: AppTheme.fhAccentTeal, size: 20),
                  title: Text(
                    "${key.substring(0, 4)}...${key.substring(key.length - 4)}",
                    style: const TextStyle(fontFamily: 'RobotoMono', color: AppTheme.fhTextPrimary),
                  ),
                  trailing: IconButton(
                    icon: Icon(MdiIcons.deleteOutline, color: AppTheme.fhAccentRed, size: 20),
                    onPressed: () => provider.removeCustomApiKey(key),
                  ),
                ),
              );
            },
          ),
        
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context, 
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.fhBgDeepDark,
                title: const Text("Add API Key"),
                content: TextField(
                  controller: _keyController,
                  decoration: const InputDecoration(
                    hintText: "Enter Gemini API Key",
                    border: OutlineInputBorder(),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  ElevatedButton(onPressed: _addKey, child: const Text("Add")),
                ],
              )
            );
          },
          icon: Icon(MdiIcons.plus, size: 18),
          label: const Text("ADD API KEY"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.fhBgDark,
            foregroundColor: AppTheme.fhTextPrimary,
            side: BorderSide(color: AppTheme.fhBorderColor.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}