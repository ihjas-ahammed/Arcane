import 'package:flutter/material.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/models/app_state_models.dart';
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
  static const List<String> _popularSuggestions = [
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-pro-exp-02-05',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-2.5-pro',
    'gemini-3.1-flash-live-preview',
    'meta-llama/llama-3.3-70b-instruct',
    'groq/compound',
  ];

  Future<void> _showCustomModelDialog({
    required String title,
    required String initialValue,
    required ValueChanged<String> onSaved,
  }) async {
    final controller = TextEditingController(
      text: (initialValue == '__enter_custom__' || initialValue.isEmpty) ? '' : initialValue,
    );
    final isLight = JweTheme.isLight;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isLight ? JweTheme.panel : AppTheme.fhBgMedium,
          title: Row(
            children: [
              Icon(MdiIcons.robotOutline, color: JweTheme.accentAmber, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Type any valid AI model identifier (e.g. gemini-2.5-pro, openrouter/auto, meta-llama/llama-3.3-70b):",
                    style: TextStyle(
                      color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: TextStyle(
                      color: isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Model Identifier",
                      hintText: "e.g. gemini-2.5-pro",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "QUICK SUGGESTIONS:",
                    style: TextStyle(
                      color: JweTheme.accentAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _popularSuggestions.map((m) {
                      return ActionChip(
                        label: Text(m, style: const TextStyle(fontSize: 11)),
                        backgroundColor: isLight ? JweTheme.bgDeep : AppTheme.fhBgDark,
                        onPressed: () {
                          controller.text = m;
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text("CANCEL", style: TextStyle(color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  onSaved(trimmed);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text("APPLY"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddModelDialog({
    required String prefix,
    required List<String> currentList,
    required ValueChanged<String> onAdded,
  }) async {
    final candidateModels = <String>{
      ...widget.availableModels,
      ...AppSettings.defaultHeavyModels,
      ...AppSettings.defaultLiteModels,
    }.where((m) => !currentList.contains(m)).toList();

    final isLight = JweTheme.isLight;
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isLight ? JweTheme.panel : AppTheme.fhBgMedium,
          title: Row(
            children: [
              Icon(MdiIcons.plusCircleOutline, color: JweTheme.accentAmber, size: 22),
              const SizedBox(width: 10),
              Text(
                "Add $prefix Fallback Model",
                style: TextStyle(
                  color: isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Type any custom model identifier or choose an available model from below to add to the rolling fallback ladder:",
                    style: TextStyle(
                      color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: TextStyle(
                      color: isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Model Name / Identifier",
                      hintText: "e.g. gemini-2.5-pro",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (candidateModels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      "AVAILABLE MODELS:",
                      style: TextStyle(
                        color: JweTheme.accentAmber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: candidateModels.map((m) {
                        return ActionChip(
                          label: Text(m, style: const TextStyle(fontSize: 11)),
                          backgroundColor: isLight ? JweTheme.bgDeep : AppTheme.fhBgDark,
                          onPressed: () {
                            controller.text = m;
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text("CANCEL", style: TextStyle(color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  onAdded(trimmed);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text("ADD TO FALLBACKS"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModelPriorityList(
    String prefix,
    List<String> currentList,
    List<String> defaultModels,
    Color accentColor,
    Function(List<String>) onUpdate,
  ) {
    final isLight = JweTheme.isLight;
    // Ensure we have at least 1 item; default to defaultModels if empty
    final List<String> list = currentList.isNotEmpty ? List.from(currentList) : List.from(defaultModels);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(list.length, (index) {
          final isPrimary = index == 0;
          final currentSelection = list[index];
          final badgeLabel = isPrimary ? "PRIMARY" : "FALLBACK #$index";
          final fieldLabel = isPrimary ? "Primary $prefix Model" : "$prefix Fallback #$index";

          final effectiveItems = <String>{
            ...widget.availableModels,
            if (!widget.availableModels.contains(currentSelection)) currentSelection,
          }.toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 10.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: isLight ? JweTheme.panel2 : AppTheme.fhBgMedium.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPrimary
                    ? accentColor.withValues(alpha: 0.6)
                    : (isLight ? JweTheme.border : AppTheme.fhBorderColor.withValues(alpha: 0.4)),
                width: isPrimary ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? accentColor.withValues(alpha: 0.2)
                            : (isLight ? JweTheme.bgDeep : AppTheme.fhBgDark),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isPrimary ? accentColor : (isLight ? JweTheme.border : AppTheme.fhBorderColor),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPrimary ? accentColor : (isLight ? JweTheme.textMid : AppTheme.fhTextSecondary),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fieldLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
                        ),
                      ),
                    ),
                    // Move Up in priority order
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      tooltip: "Move Up in Priority",
                      onPressed: index > 0
                          ? () {
                              final newList = List<String>.from(list);
                              final item = newList.removeAt(index);
                              newList.insert(index - 1, item);
                              onUpdate(newList);
                            }
                          : null,
                    ),
                    // Move Down in priority order
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      tooltip: "Move Down in Priority",
                      onPressed: index < list.length - 1
                          ? () {
                              final newList = List<String>.from(list);
                              final item = newList.removeAt(index);
                              newList.insert(index + 1, item);
                              onUpdate(newList);
                            }
                          : null,
                    ),
                    // Type / Edit custom model string
                    IconButton(
                      icon: Icon(MdiIcons.pencilOutline, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      tooltip: "Type / Edit Custom Model Name",
                      onPressed: () {
                        _showCustomModelDialog(
                          title: "Edit $fieldLabel",
                          initialValue: currentSelection,
                          onSaved: (val) {
                            final newList = List<String>.from(list);
                            newList[index] = val;
                            onUpdate(newList);
                          },
                        );
                      },
                    ),
                    // Delete fallback slot
                    if (!isPrimary && list.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: AppTheme.fhAccentRed,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        tooltip: "Remove from Fallbacks",
                        onPressed: () {
                          final newList = List<String>.from(list);
                          newList.removeAt(index);
                          onUpdate(newList);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: effectiveItems.contains(currentSelection) ? currentSelection : null,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dropdownColor: isLight ? JweTheme.panel : AppTheme.fhBgMedium,
                  items: [
                    ...effectiveItems.map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(
                            m,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: AppTheme.fontDisplay,
                              color: isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
                            ),
                          ),
                        )),
                    const DropdownMenuItem(
                      value: '__enter_custom__',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 16),
                          SizedBox(width: 6),
                          Text("✍️ Enter custom model name...",
                              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == '__enter_custom__') {
                      _showCustomModelDialog(
                        title: "Custom Model for $fieldLabel",
                        initialValue: currentSelection,
                        onSaved: (customVal) {
                          final newList = List<String>.from(list);
                          newList[index] = customVal;
                          onUpdate(newList);
                        },
                      );
                    } else if (val != null) {
                      final newList = List<String>.from(list);
                      newList[index] = val;
                      onUpdate(newList);
                    }
                  },
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: Text(
                  "ADD $prefix FALLBACK MODEL",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _showAddModelDialog(
                    prefix: prefix,
                    currentList: list,
                    onAdded: (newModel) {
                      final newList = List<String>.from(list)..add(newModel);
                      onUpdate(newList);
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.restore_rounded, size: 16),
              label: const Text("RESET (3)", style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
              ),
              onPressed: () {
                onUpdate(List.from(defaultModels));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Reset $prefix models to default 3 models."),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = widget.appProvider;
    final isLight = JweTheme.isLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      color: isLight ? JweTheme.panel : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLight ? JweTheme.border : AppTheme.fhBorderColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  MdiIcons.robotHappyOutline,
                  color: (provider.getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Model Selection & Rolling Fallback',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isLight ? JweTheme.textWhite : AppTheme.fhTextPrimary,
                        ),
                      ),
                      Text(
                        'Configure primary and fallback models executed in rolling succession.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(
              height: 24,
              thickness: 0.5,
              color: isLight ? JweTheme.border : AppTheme.fhBorderColor.withValues(alpha: 0.5),
            ),

            // --- Lite Models Section ---
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 18, color: AppTheme.fhAccentTeal),
                const SizedBox(width: 6),
                Text(
                  "Lite Models",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.fhAccentTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "(${provider.settings.liteModels.length} active)",
                  style: TextStyle(
                    fontSize: 11,
                    color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              "Fast execution for sub-missions, chatbot replies, habit parsing & light fallbacks.",
              style: TextStyle(
                fontSize: 11,
                color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _buildModelPriorityList(
              "Lite",
              provider.settings.liteModels,
              AppSettings.defaultLiteModels,
              AppTheme.fhAccentTeal,
              (newList) {
                provider.setSettings(provider.settings..liteModels = newList);
              },
            ),
            const SizedBox(height: 24),

            // --- Heavy / Pro Models Section ---
            Row(
              children: [
                Icon(Icons.psychology_rounded, size: 18, color: AppTheme.fhAccentPurple),
                const SizedBox(width: 6),
                Text(
                  "Pro Models",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.fhAccentPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "(${provider.settings.heavyModels.length} active)",
                  style: TextStyle(
                    fontSize: 11,
                    color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              "Deep reasoning for daily briefings, monthly reviews, and complex project synthesis.",
              style: TextStyle(
                fontSize: 11,
                color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _buildModelPriorityList(
              "Pro",
              provider.settings.heavyModels,
              AppSettings.defaultHeavyModels,
              AppTheme.fhAccentPurple,
              (newList) {
                provider.setSettings(provider.settings..heavyModels = newList);
              },
            ),
            const SizedBox(height: 24),

            // --- Live Models Section ---
            Row(
              children: [
                Icon(Icons.stream_rounded, size: 18, color: AppTheme.fhAccentOrange),
                const SizedBox(width: 6),
                Text(
                  "Live Models",
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.fhAccentOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "(${provider.settings.liveModels.length} active)",
                  style: TextStyle(
                    fontSize: 11,
                    color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              "Realtime streaming API for Nora AI conversational agent interactions.",
              style: TextStyle(
                fontSize: 11,
                color: isLight ? JweTheme.textMuted : AppTheme.fhTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _buildModelPriorityList(
              "Live",
              provider.settings.liveModels,
              AppSettings.defaultLiveModels,
              AppTheme.fhAccentOrange,
              (newList) {
                provider.setSettings(provider.settings..liveModels = newList);
              },
            ),
            const SizedBox(height: 20),

            // Refetch Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: widget.isFetching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(MdiIcons.refresh, size: 18),
                label: const Text("REFETCH AVAILABLE GEMINI MODELS"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.fhAccentTeal,
                  side: BorderSide(color: AppTheme.fhAccentTeal.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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