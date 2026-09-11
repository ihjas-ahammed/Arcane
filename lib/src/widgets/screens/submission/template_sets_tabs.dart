import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class TemplateSetsTabs extends StatelessWidget {
  final MainTask parentTask;
  final SubTask subTask;
  final AppProvider provider;

  const TemplateSetsTabs({
    super.key,
    required this.parentTask,
    required this.subTask,
    required this.provider,
  });

  void _showAddDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text('New Template Set', style: TextStyle(color: JweTheme.textWhite)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: JweTheme.textWhite),
          decoration: InputDecoration(
            hintText: 'e.g. Monday, Routine A',
            hintStyle: TextStyle(color: JweTheme.textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                provider.taskActions.addTemplateSet(parentTask.id, subTask.id, name);
              }
              Navigator.pop(ctx);
            },
            child: Text('ADD', style: TextStyle(color: JweTheme.accentCyan)),
          ),
        ],
      ),
    );
  }

  void _showOptionsDialog(BuildContext context, SubTaskTemplateSet templateSet) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: JweTheme.panel,
        title: Text('Template Set: ${templateSet.name}', style: TextStyle(color: JweTheme.textWhite)),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _showRenameDialog(context, templateSet);
            },
            child: Row(
              children: [
                Icon(Icons.edit, color: JweTheme.accentCyan, size: 18),
                const SizedBox(width: 12),
                Text('Rename', style: TextStyle(color: JweTheme.textWhite)),
              ],
            ),
          ),
          if (subTask.safeTemplateSets.length > 1)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                provider.taskActions.deleteTemplateSet(parentTask.id, subTask.id, templateSet.id);
              },
              child: Row(
                children: [
                  Icon(Icons.delete, color: JweTheme.accentRed, size: 18),
                  const SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: JweTheme.textWhite)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, SubTaskTemplateSet templateSet) {
    final textController = TextEditingController(text: templateSet.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text('Rename Template Set', style: TextStyle(color: JweTheme.textWhite)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: JweTheme.textWhite),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                provider.taskActions.renameTemplateSet(parentTask.id, subTask.id, templateSet.id, name);
              }
              Navigator.pop(ctx);
            },
            child: Text('SAVE', style: TextStyle(color: JweTheme.accentCyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = parentTask.taskColor;
    final templateSets = subTask.safeTemplateSets;
    final activeId = subTask.safeActiveTemplateSetId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: templateSets.length + 1,
        itemBuilder: (context, index) {
          if (index == templateSets.length) {
            return GestureDetector(
              onTap: () => _showAddDialog(context),
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: JweTheme.border),
                  color: Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add, color: JweTheme.textMid, size: 16),
              ),
            );
          }

          final set = templateSets[index];
          final isActive = set.id == activeId;

          return GestureDetector(
            onTap: () => provider.taskActions.selectTemplateSet(parentTask.id, subTask.id, set.id),
            onLongPress: () => _showOptionsDialog(context, set),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive ? activeColor : JweTheme.border,
                ),
                color: isActive ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: Text(
                set.name.toUpperCase(),
                style: GoogleFonts.chakraPetch(
                  color: isActive ? activeColor : JweTheme.textMid,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
