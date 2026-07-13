import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/settings/api_key_manager.dart';

/// Compact, single-dropdown manager for every AI provider. Gemini is primary
/// (its user keys live in [ApiKeyManager] / AppProvider); Groq, Cerebras and
/// OpenRouter are OpenAI-compatible fallbacks whose keys and model lists are
/// stored in SharedPreferences under the same keys the [AiService] reads.
class AiProvidersManager extends StatefulWidget {
  const AiProvidersManager({super.key});

  @override
  State<AiProvidersManager> createState() => _AiProvidersManagerState();
}

class _AiProviderSpec {
  const _AiProviderSpec({
    required this.label,
    required this.prefix,
    required this.defaultModels,
  });
  final String label;
  final String prefix; // SharedPreferences key prefix, e.g. 'groq'
  final String defaultModels;
}

const List<_AiProviderSpec> _providers = [
  _AiProviderSpec(label: 'Gemini (Primary)', prefix: 'gemini', defaultModels: ''),
  _AiProviderSpec(
    label: 'Groq',
    prefix: 'groq',
    defaultModels: 'llama-3.3-70b-versatile, groq/compound',
  ),
  _AiProviderSpec(
    label: 'Cerebras',
    prefix: 'cerebras',
    defaultModels: 'llama-3.3-70b, llama-3.1-70b',
  ),
  _AiProviderSpec(
    label: 'OpenRouter',
    prefix: 'openrouter',
    defaultModels: 'meta-llama/llama-3.3-70b-instruct, google/gemini-2.5-pro',
  ),
];

class _AiProvidersManagerState extends State<AiProvidersManager> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final spec = _providers[_selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provider selector.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.fhBgDark,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: AppTheme.fhBorderColor.withValues(alpha: 0.4)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selected,
              isExpanded: true,
              dropdownColor: AppTheme.fhBgDeepDark,
              icon: Icon(MdiIcons.chevronDown, color: AppTheme.fhTextSecondary),
              style: TextStyle(
                  color: AppTheme.fhTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
              items: [
                for (int i = 0; i < _providers.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Row(
                      children: [
                        Icon(MdiIcons.robotOutline,
                            size: 18, color: AppTheme.fhAccentTeal),
                        const SizedBox(width: 8),
                        Text(_providers[i].label),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _selected = v ?? 0),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (spec.prefix == 'gemini') ...[
          Text('Custom Gemini API Keys',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.fhTextPrimary,
                  fontSize: 13)),
          const SizedBox(height: 8),
          const ApiKeyManager(),
        ] else ...[
          Text(
            'Fallback provider — used automatically when Gemini is rate-limited or fails. Leave keys empty to use the shared built-in keys.',
            style: TextStyle(
                color: AppTheme.fhTextSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          _PrefStringListEditor(
            key: ValueKey('${spec.prefix}_keys'),
            title: '${spec.label} API Keys',
            prefsKey: '${spec.prefix}_api_keys_list',
            hint: 'Enter ${spec.label} API key',
            icon: MdiIcons.keyVariant,
            obscureDisplay: true,
          ),
          const SizedBox(height: 16),
          _PrefStringListEditor(
            key: ValueKey('${spec.prefix}_models'),
            title: '${spec.label} Models (priority order)',
            prefsKey: '${spec.prefix}_model_primary_text_list',
            hint: 'e.g. ${spec.defaultModels.split(',').first.trim()}',
            icon: MdiIcons.chip,
            obscureDisplay: false,
            emptyHint: 'Using defaults: ${spec.defaultModels}',
          ),
        ],
      ],
    );
  }
}

/// Add/remove editor backed by a SharedPreferences string list. Used for both
/// API keys (masked) and model names (plain) for a provider.
class _PrefStringListEditor extends StatefulWidget {
  const _PrefStringListEditor({
    super.key,
    required this.title,
    required this.prefsKey,
    required this.hint,
    required this.icon,
    required this.obscureDisplay,
    this.emptyHint,
  });

  final String title;
  final String prefsKey;
  final String hint;
  final IconData icon;
  final bool obscureDisplay;
  final String? emptyHint;

  @override
  State<_PrefStringListEditor> createState() => _PrefStringListEditorState();
}

class _PrefStringListEditorState extends State<_PrefStringListEditor> {
  List<String> _values = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _values = prefs.getStringList(widget.prefsKey) ?? [];
      _loaded = true;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(widget.prefsKey, _values);
  }

  Future<void> _add(String raw) async {
    // Accept comma-separated entries in one go.
    final additions = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !_values.contains(e));
    if (additions.isEmpty) return;
    setState(() => _values = [..._values, ...additions]);
    await _persist();
  }

  Future<void> _remove(String v) async {
    setState(() => _values = _values.where((e) => e != v).toList());
    await _persist();
  }

  String _display(String v) {
    if (!widget.obscureDisplay) return v;
    if (v.length <= 8) return '••••';
    return '${v.substring(0, 4)}...${v.substring(v.length - 4)}';
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgDeepDark,
        title: Text('Add — ${widget.title}',
            style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: 'Separate multiple with commas',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _add(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.fhTextPrimary,
                fontSize: 13)),
        const SizedBox(height: 8),
        if (!_loaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_values.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              widget.emptyHint ?? 'None added.',
              style: TextStyle(
                  color: AppTheme.fhTextSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _values.length,
            separatorBuilder: (c, i) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final v = _values[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.fhBgDark,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppTheme.fhBorderColor.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Icon(widget.icon,
                      color: AppTheme.fhAccentTeal, size: 18),
                  title: Text(
                    _display(v),
                    style: TextStyle(
                        fontFamily: 'RobotoMono',
                        color: AppTheme.fhTextPrimary,
                        fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: Icon(MdiIcons.deleteOutline,
                        color: AppTheme.fhAccentRed, size: 18),
                    onPressed: () => _remove(v),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _showAddDialog,
          icon: Icon(MdiIcons.plus, size: 16),
          label: Text('ADD ${widget.obscureDisplay ? 'KEY' : 'MODEL'}',
              style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.fhBgDark,
            foregroundColor: AppTheme.fhTextPrimary,
            side: BorderSide(
                color: AppTheme.fhBorderColor.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}
