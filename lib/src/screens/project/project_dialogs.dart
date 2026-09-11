import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

void showAddOrEditReleaseDialog(
  BuildContext context,
  AppProvider provider,
  Project project, {
  ProjectRelease? existingRelease,
  Color? accent,
}) {
  final accentColor = accent ?? provider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;
  final isEditing = existingRelease != null;
  final versionController = TextEditingController(text: existingRelease?.version ?? '');
  final titleController = TextEditingController(text: existingRelease?.title ?? '');
  DateTime? selectedDate = existingRelease?.date;
  bool isReleased = existingRelease?.isReleased ?? false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: JweTheme.panel,
        scrollable: true,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: accentColor, width: 2),
          borderRadius: BorderRadius.zero,
        ),
        title: Text(
          isEditing ? 'MODIFY PROJECT RELEASE' : 'PLAN PROJECT RELEASE',
          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: versionController,
              style: TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'VERSION (e.g. v1.0.0)',
                labelStyle: TextStyle(color: JweTheme.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              style: TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'RELEASE TITLE / MILESTONE',
                labelStyle: TextStyle(color: JweTheme.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                selectedDate == null ? 'SELECT TARGET DATE' : DateFormat('yyyy-MM-dd').format(selectedDate!),
                style: TextStyle(color: selectedDate == null ? JweTheme.textMuted : JweTheme.textWhite, fontSize: 13),
              ),
              trailing: Icon(MdiIcons.calendar, color: accentColor),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) {
                  setDialogState(() => selectedDate = picked);
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('MARK AS SHIPPED', style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
              activeThumbColor: accentColor,
              value: isReleased,
              onChanged: (val) => setDialogState(() => isReleased = val),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ABORT', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: JweTheme.onAccent,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final version = versionController.text.trim();
              final title = titleController.text.trim();
              if (version.isNotEmpty && title.isNotEmpty) {
                if (isEditing) {
                  final updatedRelease = existingRelease.copyWith(
                    version: version,
                    title: title,
                    date: selectedDate,
                    isReleased: isReleased,
                  );
                  final updatedReleases = project.releases.map((r) => r.id == existingRelease.id ? updatedRelease : r).toList();
                  provider.updateProject(project.copyWith(releases: updatedReleases));
                } else {
                  final newRelease = ProjectRelease(
                    id: const Uuid().v4(),
                    version: version,
                    title: title,
                    date: selectedDate,
                    isReleased: isReleased,
                  );
                  final updated = project.copyWith(
                    releases: [...project.releases, newRelease],
                  );
                  provider.updateProject(updated);
                }
                Navigator.pop(ctx);
              }
            },
            child: Text(isEditing ? 'UPDATE' : 'SAVE'),
          ),
        ],
      ),
    ),
  );
}

void showAddOrEditNoteDialog(
  BuildContext context,
  AppProvider provider,
  Project project, {
  ProjectNote? existingNote,
  Color? accent,
}) {
  final accentColor = accent ?? provider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;
  final isEditing = existingNote != null;
  final titleController = TextEditingController(text: existingNote?.title ?? '');
  final contentController = TextEditingController(text: existingNote?.content ?? '');

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: JweTheme.panel,
      scrollable: true,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: accentColor, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      title: Text(
        isEditing ? 'EDIT PROTOCOL NOTE' : 'ADD PROTOCOL NOTE',
        style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            style: TextStyle(color: JweTheme.textWhite),
            decoration: InputDecoration(
              labelText: 'NOTE TITLE',
              labelStyle: TextStyle(color: JweTheme.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentController,
            maxLines: 5,
            style: TextStyle(color: JweTheme.textWhite),
            decoration: InputDecoration(
              labelText: 'CONTENT',
              labelStyle: TextStyle(color: JweTheme.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: JweTheme.onAccent,
            shape: const BeveledRectangleBorder(),
          ),
          onPressed: () {
            final title = titleController.text.trim();
            final content = contentController.text.trim();
            if (title.isNotEmpty || content.isNotEmpty) {
              if (isEditing) {
                final updatedNote = existingNote.copyWith(
                  title: title.isNotEmpty ? title : 'UNTITLED NOTE',
                  content: content,
                );
                final updatedNotes = project.notes.map((n) => n.id == existingNote.id ? updatedNote : n).toList();
                final updated = project.copyWith(notes: updatedNotes);
                provider.updateProject(updated);
              } else {
                final newNote = ProjectNote(
                  id: const Uuid().v4(),
                  title: title.isNotEmpty ? title : 'UNTITLED NOTE',
                  content: content,
                  createdAt: DateTime.now(),
                );
                final updated = project.copyWith(
                  notes: [newNote, ...project.notes],
                );
                provider.updateProject(updated);
              }
              Navigator.pop(ctx);
            }
          },
          child: Text(isEditing ? 'UPDATE' : 'SAVE'),
        ),
      ],
    ),
  );
}

void showAddFileDialog(BuildContext context, AppProvider provider, Project project) {
  final nameController = TextEditingController();
  final contentController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: JweTheme.panel,
      scrollable: true,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: JweTheme.accentAmber, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      title: Text(
        'CREATE PROJECT FILE / PLAN',
        style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            style: TextStyle(color: JweTheme.textWhite),
            decoration: InputDecoration(
              labelText: 'FILE NAME (e.g. roadmap.md)',
              labelStyle: TextStyle(color: JweTheme.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentController,
            maxLines: 4,
            style: TextStyle(color: JweTheme.textWhite),
            decoration: InputDecoration(
              labelText: 'FILE MARKDOWN CONTENT',
              labelStyle: TextStyle(color: JweTheme.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentAmber,
            foregroundColor: JweTheme.onAccent,
            shape: const BeveledRectangleBorder(),
          ),
          onPressed: () {
            final name = nameController.text.trim();
            final content = contentController.text.trim();
            if (name.isNotEmpty) {
              final newFile = ProjectFile(
                id: const Uuid().v4(),
                name: name,
                content: content,
                createdAt: DateTime.now(),
              );
              final updated = project.copyWith(
                files: [newFile, ...project.files],
              );
              provider.updateProject(updated);
              Navigator.pop(ctx);
            }
          },
          child: const Text('CREATE'),
        ),
      ],
    ),
  );
}

void showFileEditor(BuildContext context, AppProvider provider, Project project, ProjectFile file) {
  final contentController = TextEditingController(text: file.content);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: JweTheme.panel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: JweTheme.accentAmber, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      title: Text(
        file.name.toUpperCase(),
        style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: TextField(
          controller: contentController,
          maxLines: null,
          minLines: 20,
          keyboardType: TextInputType.multiline,
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 12),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('CLOSE', style: TextStyle(color: JweTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: JweTheme.accentAmber,
            foregroundColor: JweTheme.onAccent,
            shape: const BeveledRectangleBorder(),
          ),
          onPressed: () {
            final newContent = contentController.text;
            final updatedFile = ProjectFile(
              id: file.id,
              name: file.name,
              content: newContent,
              createdAt: file.createdAt,
            );
            final updatedFiles = project.files.map((f) => f.id == file.id ? updatedFile : f).toList();
            final updated = project.copyWith(files: updatedFiles);
            provider.updateProject(updated);
            Navigator.pop(ctx);
          },
          child: const Text('SAVE PLAN'),
        ),
      ],
    ),
  );
}

void showLinkTasksSearchDialog(BuildContext context, AppProvider provider, Project project) {
  showDialog(
    context: context,
    builder: (ctx) => LinkTaskDialog(provider: provider, project: project),
  );
}

class LinkTaskDialog extends StatefulWidget {
  final AppProvider provider;
  final Project project;

  const LinkTaskDialog({super.key, required this.provider, required this.project});

  @override
  State<LinkTaskDialog> createState() => _LinkTaskDialogState();
}

class _LinkTaskDialogState extends State<LinkTaskDialog> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> availableTasks = [];

    for (final mainTask in widget.provider.mainTasks) {
      if (mainTask.isDeleted) continue;
      for (final sub in mainTask.subTasks) {
        if (sub.isDeleted) continue;
        final key = '${mainTask.id}|${sub.id}';
        if (widget.project.linkedTaskKeys.contains(key)) continue;

        if (_searchQuery.isEmpty || sub.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          availableTasks.add({
            'key': key,
            'sub': sub,
            'parent': mainTask,
          });
        }
      }
    }

    return AlertDialog(
      backgroundColor: JweTheme.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: JweTheme.accentAmber, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      title: Text(
        'LINK MISSION CONTRACT',
        style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              style: TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                hintText: 'SEARCH CONTRACTS...',
                hintStyle: TextStyle(color: JweTheme.textMuted),
                prefixIcon: Icon(Icons.search, color: JweTheme.textMuted),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: availableTasks.isEmpty
                  ? Center(child: Text('NO CONTRACTS DETECTED.', style: TextStyle(color: JweTheme.textMuted)))
                  : ListView.builder(
                      itemCount: availableTasks.length,
                      itemBuilder: (ctx, idx) {
                        final item = availableTasks[idx];
                        final sub = item['sub'] as SubTask;
                        final parent = item['parent'] as MainTask;
                        final key = item['key'] as String;

                        return Card(
                          color: JweTheme.bgDeep,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(sub.name, style: TextStyle(color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text('${parent.name.toUpperCase()} • ${sub.completed ? "COMPLETED" : "ONGOING"}', style: TextStyle(color: parent.taskColor, fontSize: 10)),
                            trailing: Icon(MdiIcons.plus, color: JweTheme.accentAmber),
                            onTap: () {
                              final updated = widget.project.copyWith(
                                linkedTaskKeys: [key, ...widget.project.linkedTaskKeys],
                              );
                              widget.provider.updateProject(updated);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ABORT', style: TextStyle(color: JweTheme.textMuted)),
        ),
      ],
    );
  }
}
