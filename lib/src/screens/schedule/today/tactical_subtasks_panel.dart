import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'tactical_planner_painters.dart';
import 'today_planner_models.dart';

class TacticalSubtasksPanel extends StatelessWidget {
  final PlanEntry entry;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final void Function(PlanCheckpoint cp) onToggleCheckpoint;
  final void Function(PlanCheckpoint cp) onRemoveCheckpoint;
  final VoidCallback onPromptAdd;

  const TacticalSubtasksPanel({
    super.key,
    required this.entry,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onToggleCheckpoint,
    required this.onRemoveCheckpoint,
    required this.onPromptAdd,
  });

  @override
  Widget build(BuildContext context) {
    final checkpoints = entry.checkpoints;
    if (checkpoints.isEmpty) {
      return const SizedBox.shrink();
    }
    final completedCount = checkpoints.where((c) => c.completed).length;
    final totalCount = checkpoints.length;
    final totalMinutes = checkpoints.fold<int>(0, (sum, c) => sum + c.durationMinutes);
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF060A0F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: JweTheme.isLight ? JweTheme.border : const Color(0xFF14202D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: JweTheme.isLight ? JweTheme.textMid : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.checklist_rounded,
                    size: 13,
                    color: totalCount > 0
                        ? (completedCount == totalCount ? JweTheme.accentTeal : JweTheme.accentCyan)
                        : JweTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CHECKPOINTS ($completedCount/$totalCount)',
                    style: GoogleFonts.rajdhani(
                      color: JweTheme.isLight ? JweTheme.textWhite : const Color(0xFFEAECF3),
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (totalMinutes > 0)
                    Text(
                      'Total: ${totalMinutes}m',
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (totalCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: JweTheme.isLight ? JweTheme.border : const Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completedCount == totalCount ? JweTheme.accentTeal : JweTheme.accentCyan,
                  ),
                  minHeight: 2,
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (checkpoints.isNotEmpty)
                          ...checkpoints.map((cp) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  CustomSquareCheck(
                                    checked: cp.completed,
                                    onTap: () => onToggleCheckpoint(cp),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cp.name,
                                      style: GoogleFonts.rajdhani(
                                        color: cp.completed ? JweTheme.textMuted : JweTheme.textWhite,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: cp.completed ? TextDecoration.lineThrough : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${cp.durationMinutes}m',
                                    style: GoogleFonts.rajdhani(
                                      color: JweTheme.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => onRemoveCheckpoint(cp),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Text(
                                        '✕',
                                        style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: onPromptAdd,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: JweTheme.lineSoft, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 12, color: JweTheme.accentCyan),
                                const SizedBox(width: 4),
                                Text(
                                  '+ ADD CHECKPOINT',
                                  style: GoogleFonts.rajdhani(
                                    color: JweTheme.accentCyan,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 4),
          ),
        ],
      ),
    );
  }
}

Future<void> promptAddSubtaskDialog({
  required BuildContext context,
  required Future<void> Function(String name, int minutes) onAdd,
}) async {
  final nameCtrl = TextEditingController();
  int selectedMinutes = 15;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDlgState) => AlertDialog(
        backgroundColor: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: JweTheme.accentCyan, width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.add_task, color: JweTheme.accentCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              'ADD CHECKPOINT',
              style: GoogleFonts.rajdhani(
                color: JweTheme.accentCyan,
                fontSize: 16,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 15, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Checkpoint title…',
                hintStyle: GoogleFonts.rajdhani(color: JweTheme.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: JweTheme.border),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: JweTheme.accentCyan),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ESTIMATED DURATION',
              style: GoogleFonts.rajdhani(
                color: JweTheme.textMuted,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [5, 10, 15, 25, 30].map((m) {
                final isSel = selectedMinutes == m;
                return ChoiceChip(
                  label: Text('${m}m',
                      style: GoogleFonts.rajdhani(
                        color: isSel ? JweTheme.onAccent : JweTheme.textWhite,
                        fontWeight: FontWeight.bold,
                      )),
                  selected: isSel,
                  selectedColor: JweTheme.accentCyan,
                  backgroundColor: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF111D28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  onSelected: (_) => setDlgState(() => selectedMinutes = m),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentCyan,
              foregroundColor: JweTheme.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text('ADD', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    ),
  );

  if (result == true && nameCtrl.text.trim().isNotEmpty) {
    await onAdd(nameCtrl.text.trim(), selectedMinutes);
    showGlobalToast('Checkpoint added');
  }
}

void showSubtasksModalBottomSheet({
  required BuildContext context,
  required AppProvider provider,
  required PlanEntry entry,
  required String subTaskName,
  required void Function(PlanCheckpoint cp) onToggleCheckpoint,
  required void Function(PlanCheckpoint cp) onRemoveCheckpoint,
  required Future<void> Function() onPromptAdd,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: JweTheme.isLight ? JweTheme.panel : const Color(0xFF090F16),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      side: BorderSide(color: JweTheme.border, width: 1.5),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final checkpoints = entry.checkpoints;
          final completedCount = checkpoints.where((c) => c.completed).length;

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHECKPOINTS',
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.accentCyan,
                                fontSize: 11,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              subTaskName,
                              style: GoogleFonts.rajdhani(
                                color: JweTheme.textWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF111D28),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: JweTheme.border),
                        ),
                        child: Text(
                          '$completedCount / ${checkpoints.length}',
                          style: GoogleFonts.rajdhani(
                            color: JweTheme.accentCyan,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: JweTheme.lineSoft, height: 1),
                  const SizedBox(height: 8),
                  if (checkpoints.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No checkpoints attached yet.',
                          style: GoogleFonts.rajdhani(color: JweTheme.textMuted, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: checkpoints.length,
                        itemBuilder: (context, idx) {
                          final cp = checkpoints[idx];
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: JweTheme.isLight ? JweTheme.panel2 : const Color(0xFF05080C),
                              border: Border.all(
                                color: cp.completed ? JweTheme.border : (JweTheme.isLight ? JweTheme.border : const Color(0xFF1F2F40)),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                CustomSquareCheck(
                                  checked: cp.completed,
                                  onTap: () {
                                    onToggleCheckpoint(cp);
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cp.name,
                                    style: GoogleFonts.rajdhani(
                                      color: cp.completed ? JweTheme.textMuted : JweTheme.textWhite,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      decoration: cp.completed ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${cp.durationMinutes}m',
                                  style: GoogleFonts.rajdhani(
                                    color: JweTheme.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    onRemoveCheckpoint(cp);
                                    setModalState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      '✕',
                                      style: TextStyle(color: JweTheme.textMuted, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await onPromptAdd();
                      setModalState(() {});
                    },
                    icon: Icon(Icons.add, size: 16, color: JweTheme.accentCyan),
                    label: Text(
                      'ADD CHECKPOINT',
                      style: GoogleFonts.rajdhani(
                        color: JweTheme.accentCyan,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: JweTheme.accentCyan),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
