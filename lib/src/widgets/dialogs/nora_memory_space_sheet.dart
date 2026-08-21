import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:uuid/uuid.dart';

class NoraMemorySpaceSheet extends StatefulWidget {
  final AppProvider provider;
  final String personaId;

  const NoraMemorySpaceSheet({
    super.key,
    required this.provider,
    required this.personaId,
  });

  static Future<void> show(BuildContext context, AppProvider provider, String personaId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoraMemorySpaceSheet(
        provider: provider,
        personaId: personaId,
      ),
    );
  }

  @override
  State<NoraMemorySpaceSheet> createState() => _NoraMemorySpaceSheetState();
}

class _NoraMemorySpaceSheetState extends State<NoraMemorySpaceSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  bool _isAdding = false;

  @override
  void dispose() {
    _searchController.dispose();
    _keyController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _saveNewMemory() {
    final key = _keyController.text.trim();
    final content = _contentController.text.trim();
    if (key.isEmpty || content.isEmpty) return;

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final item = NoraMemoryItem(
      id: const Uuid().v4(),
      key: key,
      content: content,
      tags: tags,
    );

    widget.provider.addPersonaMemoryItem(widget.personaId, item);

    _keyController.clear();
    _contentController.clear();
    _tagsController.clear();
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final persona = widget.provider.chatbotMemory.getPersona(widget.personaId);
    final memories = widget.provider.getPersonaMemories(widget.personaId);

    final query = _searchController.text.toLowerCase().trim();
    final filtered = memories.where((m) {
      if (query.isEmpty) return true;
      final combined = "${m.key} ${m.content} ${m.tags.join(' ')}".toLowerCase();
      return combined.contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDeepDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppTheme.fhAccentPurple.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(MdiIcons.brain, color: AppTheme.fhAccentPurple, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${persona.name.toUpperCase()}'S MEMORY SPACE",
                        style: TextStyle(
                          color: AppTheme.fhAccentPurple,
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        "${memories.length} persistent nodes across sessions",
                        style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar & Add Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Search memory space by keyword or tag...",
                    hintStyle: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 12),
                    prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.fhTextSecondary),
                    filled: true,
                    fillColor: AppTheme.fhBgDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.fhBorderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fhAccentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_isAdding ? Icons.close : Icons.add, size: 18),
                label: Text(_isAdding ? "CANCEL" : "STORE MEMORY"),
                onPressed: () => setState(() => _isAdding = !_isAdding),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Inline Add Form
          if (_isAdding) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.fhAccentPurple.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("STORE NEW MEMORY IN SPACE", style: TextStyle(color: AppTheme.fhAccentPurple, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _keyController,
                          style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "Memory Key / Topic (e.g. favorite_food, stress_trigger)",
                            filled: true,
                            fillColor: AppTheme.fhBgMedium,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _tagsController,
                          style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "Tags (comma separated, e.g. habit, health)",
                            filled: true,
                            fillColor: AppTheme.fhBgMedium,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contentController,
                    maxLines: 3,
                    style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Memory details, observation, rule, or user preference...",
                      filled: true,
                      fillColor: AppTheme.fhBgMedium,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ValorantButton(
                      label: "SAVE TO MEMORY SPACE",
                      icon: Icons.check,
                      color: AppTheme.fhAccentPurple,
                      onPressed: _saveNewMemory,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Memory List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(MdiIcons.brain, size: 48, color: AppTheme.fhTextDisabled.withOpacity(0.25)),
                        const SizedBox(height: 12),
                        Text(
                          memories.isEmpty ? "Memory Space is currently empty." : "No matching memories found.",
                          style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${persona.name} will autonomously remember key user details and character notes here as you chat.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.fhBgDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(MdiIcons.keyVariant, size: 14, color: AppTheme.fhAccentPurple),
                                    const SizedBox(width: 6),
                                    Text(
                                      item.key,
                                      style: TextStyle(
                                        color: AppTheme.fhAccentPurple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('MM/dd/yy').format(item.updatedAt),
                                      style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 10),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        widget.provider.deletePersonaMemoryItem(widget.personaId, item.id);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.content,
                              style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 12, height: 1.4),
                            ),
                            if (item.tags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: item.tags.map((t) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.fhAccentPurple.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.fhAccentPurple.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      "#$t",
                                      style: TextStyle(color: AppTheme.fhAccentPurple, fontSize: 10),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
