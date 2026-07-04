import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/widgets/dialogs/add_edit_protocol_dialog.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class JweTaskOptionsDialog extends StatelessWidget {
  final MainTask task;

  const JweTaskOptionsDialog({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final isActive = task.isActive;

    return Dialog(
      backgroundColor: JweTheme.panel,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: JweTheme.accentCyan, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(MdiIcons.consoleLine, color: JweTheme.accentCyan, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "PROTOCOL CONFIG",
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JweTheme.bgBase,
                  border: Border.all(color: JweTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TARGET:",
                      style: TextStyle(color: JweTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      task.name.toUpperCase(),
                      style: GoogleFonts.chakraPetch(color: JweTheme.accentAmber, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              OutlinedButton.icon(
                icon: Icon(MdiIcons.pencilOutline, size: 18),
                label: const Text("EDIT PROTOCOL"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.textWhite,
                  side: const BorderSide(color: JweTheme.border),
                  shape: const BeveledRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(context: context, builder: (_) => AddEditProtocolDialog(task: task));
                },
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                icon: Icon(isActive ? MdiIcons.pauseOctagonOutline : MdiIcons.playCircleOutline, size: 18),
                label: Text(isActive ? "SUSPEND PROTOCOL" : "REACTIVATE PROTOCOL"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isActive ? JweTheme.accentAmber : JweTheme.accentCyan,
                  side: BorderSide(color: isActive ? JweTheme.accentAmber : JweTheme.accentCyan),
                  shape: const BeveledRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  provider.taskActions.toggleTaskStatus(task.id, !isActive);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onSecondaryTap: () => _handlePaste(context, provider),
                child: OutlinedButton.icon(
                  icon: Icon(MdiIcons.contentCopy, size: 18),
                  label: const Text("COPY STRUCTURE"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: JweTheme.accentCyan,
                    side: const BorderSide(color: JweTheme.accentCyan),
                    shape: const BeveledRectangleBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: task.toCopyStructure()));
                    showGlobalToast("Protocol structure copied to clipboard");
                    Navigator.pop(context);
                  },
                  onLongPress: () => _handlePaste(context, provider),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                icon: Icon(MdiIcons.deleteOutline, size: 18),
                label: const Text("DELETE PROTOCOL"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.accentRed,
                  side: const BorderSide(color: JweTheme.accentRed),
                  shape: const BeveledRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: JweTheme.panel,
                      title: Text("DELETE PROTOCOL?", style: GoogleFonts.rajdhani(color: JweTheme.accentRed, fontWeight: FontWeight.bold)),
                      content: const Text("This action cannot be undone and will delete all nested missions.", style: TextStyle(color: JweTheme.textMuted)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("DELETE")
                        )
                      ],
                    )
                  );
                  
                  if (confirm == true && context.mounted) {
                    provider.taskActions.deleteMainTask(task.id);
                    Navigator.pop(context);
                  }
                },
              ),

              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: JweTheme.textMuted,
                  side: const BorderSide(color: Colors.transparent),
                  shape: const BeveledRectangleBorder(),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL"),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showPasteAlertDialog(BuildContext context, String title, Function(String) onImport) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        title: Text(title, style: GoogleFonts.rajdhani(color: JweTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Paste the copied structure text here to import:", style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: JweTheme.bgDeep,
                border: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: JweTheme.accentCyan)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentCyan,
              foregroundColor: Colors.black,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                onImport(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text("IMPORT"),
          ),
        ],
      ),
    );
  }

  void _handlePaste(BuildContext context, AppProvider provider) {
    _showPasteAlertDialog(context, "PASTE TASK STRUCTURE", (pastedText) {
      final parsed = parseTaskOutline(pastedText);
      if (parsed.isNotEmpty) {
        final newSub = SubTask(
          id: const Uuid().v4(),
          name: parsed['name'] as String? ?? 'Unnamed Task',
          why: parsed['why'] as String? ?? '',
          what: parsed['what'] as String? ?? '',
          subSubTasks: (parsed['children'] as List<dynamic>).map((c) {
            return SubSubTask(
              id: const Uuid().v4(),
              name: c['name'] as String? ?? 'Unnamed Objective',
              why: c['why'] as String? ?? '',
              what: c['what'] as String? ?? '',
              type: 'check',
              substeps: (c['children'] as List<dynamic>?)?.map((cc) {
                return SubSubTask(
                  id: const Uuid().v4(),
                  name: cc['name'] as String? ?? 'Unnamed Objective',
                  why: cc['why'] as String? ?? '',
                  what: cc['what'] as String? ?? '',
                  type: 'check',
                );
              }).toList() ?? [],
            );
          }).toList(),
        );

        final newMainTasks = provider.mainTasks.map((t) {
          if (t.id == task.id) {
            return t.copyWith(
              subTasks: [...t.subTasks, newSub],
            );
          }
          return t;
        }).toList();
        provider.setProviderState(mainTasks: newMainTasks);
        showGlobalToast("Task pasted as new child");
        Navigator.pop(context);
      }
    });
  }
}