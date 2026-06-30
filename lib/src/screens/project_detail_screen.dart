import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:missions/src/widgets/screens/submission_detail_screen.dart';
import 'package:missions/src/utils/task_calculations.dart';

int calculateProjectStreak(Project project, AppProvider provider) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final Map<String, double> dailySeconds = {};

  for (final key in project.linkedTaskKeys) {
    final parts = key.split('|');
    if (parts.length < 2) continue;
    final mainId = parts[0];
    final subId = parts[1];

    final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
    final sub = mainTask?.subTasks.firstWhereOrNull((s) => s.id == subId);
    if (sub == null) continue;

    for (final session in sub.sessions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(session.startTime);
      dailySeconds[dateStr] = (dailySeconds[dateStr] ?? 0.0) + session.durationSeconds;
    }

    final timer = provider.activeTimers[sub.id];
    if (timer != null && timer.isRunning) {
      final elapsed = DateTime.now().difference(timer.startTime).inSeconds;
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      dailySeconds[dateStr] = (dailySeconds[dateStr] ?? 0.0) + elapsed;
    }
  }

  final Set<DateTime> activeDates = {};
  dailySeconds.forEach((dateStr, seconds) {
    if (seconds >= 900.0) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        activeDates.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
    }
  });

  if (activeDates.isEmpty) return 0;

  int streak = 0;
  DateTime checkDate = today;

  if (activeDates.contains(today)) {
    streak = 1;
    checkDate = today.subtract(const Duration(days: 1));
    while (activeDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
  } else if (activeDates.contains(today.subtract(const Duration(days: 1)))) {
    streak = 1;
    checkDate = today.subtract(const Duration(days: 2));
    while (activeDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
  }

  return streak;
}

class ProjectDetailView extends StatefulWidget {
  final Project project;
  final VoidCallback onBack;

  const ProjectDetailView({super.key, required this.project, required this.onBack});

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Project? _liveProject;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Project _getLiveProject(AppProvider provider) {
    try {
      return provider.projects.firstWhere((p) => p.id == widget.project.id);
    } catch (_) {
      return _liveProject ?? widget.project;
    }
  }

  void _showAddReleaseDialog(BuildContext context, AppProvider provider, Project project) {
    final versionController = TextEditingController();
    final titleController = TextEditingController();
    DateTime? selectedDate;
    bool isReleased = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: JweTheme.panel,
          scrollable: true,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentAmber, width: 2),
            borderRadius: BorderRadius.zero,
          ),
          title: Text(
            'PLAN PROJECT RELEASE',
            style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: versionController,
                style: const TextStyle(color: JweTheme.textWhite),
                decoration: InputDecoration(
                  labelText: 'VERSION (e.g. v1.0.0)',
                  labelStyle: const TextStyle(color: JweTheme.textMuted),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                style: const TextStyle(color: JweTheme.textWhite),
                decoration: InputDecoration(
                  labelText: 'RELEASE TITLE / MILESTONE',
                  labelStyle: const TextStyle(color: JweTheme.textMuted),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  selectedDate == null ? 'SELECT TARGET DATE' : DateFormat('yyyy-MM-dd').format(selectedDate!),
                  style: TextStyle(color: selectedDate == null ? JweTheme.textMuted : JweTheme.textWhite, fontSize: 13),
                ),
                trailing: Icon(MdiIcons.calendar, color: JweTheme.accentAmber),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
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
                title: const Text('MARK AS SHIPPED', style: TextStyle(color: JweTheme.textWhite, fontSize: 13)),
                activeThumbColor: JweTheme.accentAmber,
                value: isReleased,
                onChanged: (val) => setDialogState(() => isReleased = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ABORT', style: TextStyle(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: Colors.black,
                shape: const BeveledRectangleBorder(),
              ),
              onPressed: () {
                final version = versionController.text.trim();
                final title = titleController.text.trim();
                if (version.isNotEmpty && title.isNotEmpty) {
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
                  Navigator.pop(ctx);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, AppProvider provider, Project project) {
    final titleController = TextEditingController();
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
          'ADD PROTOCOL NOTE',
          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'NOTE TITLE',
                labelStyle: const TextStyle(color: JweTheme.textMuted),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 4,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'CONTENT',
                labelStyle: const TextStyle(color: JweTheme.textMuted),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentAmber,
              foregroundColor: Colors.black,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isNotEmpty && content.isNotEmpty) {
                final newNote = ProjectNote(
                  id: const Uuid().v4(),
                  title: title,
                  content: content,
                  createdAt: DateTime.now(),
                );
                final updated = project.copyWith(
                  notes: [newNote, ...project.notes],
                );
                provider.updateProject(updated);
                Navigator.pop(ctx);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showAddFileDialog(BuildContext context, AppProvider provider, Project project) {
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
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'FILE NAME (e.g. roadmap.md)',
                labelStyle: const TextStyle(color: JweTheme.textMuted),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 4,
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                labelText: 'FILE MARKDOWN CONTENT',
                labelStyle: const TextStyle(color: JweTheme.textMuted),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentAmber,
              foregroundColor: Colors.black,
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

  void _showFileEditor(BuildContext context, AppProvider provider, Project project, ProjectFile file) {
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
              border: const OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: JweTheme.accentAmber,
              foregroundColor: Colors.black,
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

  void _showLinkTasksSearchDialog(BuildContext context, AppProvider provider, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => _LinkTaskDialog(provider: provider, project: project),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final project = _getLiveProject(provider);
    final accentColor = provider.getSelectedTask()?.taskColor ?? JweTheme.accentAmber;

    return Scaffold(
      backgroundColor: JweTheme.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: JweTheme.panel,
              child: TabBar(
                controller: _tabController,
                indicatorColor: accentColor,
                labelColor: accentColor,
                dividerColor: accentColor.withValues(alpha: 0.20),
                unselectedLabelColor: JweTheme.textMuted,
                labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(icon: Icon(MdiIcons.rocketLaunchOutline, size: 20)),
                  Tab(icon: Icon(MdiIcons.formatListCheckbox, size: 20)),
                  Tab(icon: Icon(MdiIcons.notebookOutline, size: 20)),
                  Tab(icon: Icon(MdiIcons.chartTimelineVariant, size: 20)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReleasesTab(provider, project, accentColor),
                  _buildTasksTab(provider, project, accentColor),
                  _buildLogsTab(provider, project, accentColor),
                  _buildAnalyticsTab(provider, project, accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ResolvedDayPlanItem? _resolveNextProjectTask(Project project, AppProvider provider) {
    for (final key in project.linkedTaskKeys) {
      final parts = key.split('|');
      if (parts.length < 2) continue;
      final mainId = parts[0];
      final subId = parts[1];

      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
      final sub = mainTask?.subTasks.firstWhereOrNull((s) => s.id == subId);
      if (mainTask == null || sub == null || sub.completed) continue;

      final cp = TaskCalculations.nextCheckpoint(sub);
      if (cp != null) {
        return ResolvedDayPlanItem(
          compoundId: '$mainId|$subId|${cp.id}',
          name: cp.name,
          parentName: '${mainTask.name} > ${sub.name}',
          color: mainTask.taskColor,
          isPhoenix: false,
          mainTaskId: mainId,
          subTaskId: subId,
          targetCheckpointId: cp.id,
        );
      } else {
        return ResolvedDayPlanItem(
          compoundId: '$mainId|$subId',
          name: sub.name,
          parentName: mainTask.name,
          color: mainTask.taskColor,
          isPhoenix: false,
          mainTaskId: mainId,
          subTaskId: subId,
        );
      }
    }
    return null;
  }

  Widget _buildReleasesTab(AppProvider provider, Project project, Color accentColor) {
    final unreleased = project.releases.where((r) => !r.isReleased).toList();
    final released = project.releases.where((r) => r.isReleased).toList();
    final nextTask = _resolveNextProjectTask(project, provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (nextTask != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.06),
                border: Border(left: BorderSide(color: nextTask.color, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXT ACTIVE CONTRACT STEP',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextTask.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          nextTask.parentName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(MdiIcons.checkboxBlankCircleOutline, color: accentColor, size: 22),
                    onPressed: () {
                      if (nextTask.targetCheckpointId != null) {
                        provider.taskActions.completeSubSubtask(
                          nextTask.mainTaskId,
                          nextTask.subTaskId,
                          nextTask.targetCheckpointId!,
                        );
                      } else {
                        provider.taskActions.completeSubtask(
                          nextTask.mainTaskId,
                          nextTask.subTaskId,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Text(
                'RELEASE MILESTONES',
                style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddReleaseDialog(context, provider, project),
                icon: Icon(MdiIcons.plus, size: 14, color: accentColor),
                label: Text('PLAN RELEASE', style: TextStyle(color: accentColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (project.releases.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: JweTheme.border),
              ),
              alignment: Alignment.center,
              child: const Text('NO PLANNED RELEASES AVAILABLE.', style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
            )
          else ...[
            if (unreleased.isNotEmpty) ...[
              Text(
                'PLANNED / NEXT RELEASES',
                style: GoogleFonts.jetBrainsMono(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...unreleased.map((r) => _buildReleaseCard(provider, project, r, accentColor)),
              const SizedBox(height: 16),
            ],
            if (released.isNotEmpty) ...[
              Text(
                'COMPLETED / SHIPPED RELEASES',
                style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...released.map((r) => _buildReleaseCard(provider, project, r, accentColor)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReleaseCard(AppProvider provider, Project project, ProjectRelease release, Color accentColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: JweTheme.panel,
      shape: Border(left: BorderSide(color: release.isReleased ? JweTheme.accentTeal : accentColor, width: 3)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: release.isReleased ? JweTheme.accentTeal.withValues(alpha: 0.12) : accentColor.withValues(alpha: 0.12),
                        child: Text(
                          release.version,
                          style: GoogleFonts.jetBrainsMono(
                            color: release.isReleased ? JweTheme.accentTeal : accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          release.title.toUpperCase(),
                          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (release.date != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'TARGET DATE: ${DateFormat('yyyy-MM-dd').format(release.date!)}',
                      style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                release.isReleased ? MdiIcons.checkboxMarkedCircleOutline : MdiIcons.checkboxBlankCircleOutline,
                color: release.isReleased ? JweTheme.accentTeal : JweTheme.textMuted,
              ),
              onPressed: () {
                final updatedReleases = project.releases.map((rel) {
                  if (rel.id == release.id) {
                    return ProjectRelease(
                      id: rel.id,
                      version: rel.version,
                      title: rel.title,
                      date: rel.date,
                      isReleased: !rel.isReleased,
                    );
                  }
                  return rel;
                }).toList();
                provider.updateProject(project.copyWith(releases: updatedReleases));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: JweTheme.accentRed),
              onPressed: () {
                final updatedReleases = project.releases.where((rel) => rel.id != release.id).toList();
                provider.updateProject(project.copyWith(releases: updatedReleases));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTab(AppProvider provider, Project project, Color accentColor) {
    final List<Widget> cards = [];

    for (var i = 0; i < project.linkedTaskKeys.length; i++) {
      final key = project.linkedTaskKeys[i];
      final parts = key.split('|');
      if (parts.length < 2) continue;
      final mainId = parts[0];
      final subId = parts[1];

      final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
      final sub = mainTask?.subTasks.firstWhereOrNull((s) => s.id == subId);

      if (mainTask != null && sub != null) {
        final timerState = provider.activeTimers[sub.id];
        final isRunning = timerState?.isRunning ?? false;

        final displayBaseTime = isRunning
            ? TaskCalculations.getHistoricalTodaySeconds(sub)
            : TaskCalculations.getTodaySeconds(sub, timerState);

        final hours = (displayBaseTime / 3600).floor();
        final minutes = ((displayBaseTime / 60) % 60).floor();
        final timeDisplay = '${hours}h ${minutes.toString().padLeft(2, '0')}m';

        final progress = sub.calculateProgress();

        cards.add(
          Padding(
            key: ValueKey(key),
            padding: const EdgeInsets.only(bottom: 10.0),
            child: HudPanel(
              clip: HudClip.br,
              accent: mainTask.taskColor,
              brackets: true,
              allBrackets: false,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(MdiIcons.drag, color: JweTheme.textMuted, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              color: mainTask.taskColor.withValues(alpha: 0.12),
                              child: Text(
                                mainTask.name.toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(color: mainTask.taskColor, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sub.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(color: JweTheme.textWhite, fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ),
                            if (isRunning) ...[
                              const HudDot(tone: HudTone.red, size: 5),
                              const SizedBox(width: 4),
                            ],
                            IconButton(
                              icon: Icon(MdiIcons.openInNew, color: accentColor, size: 16),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SubmissionDetailScreen(parentTask: mainTask, subTask: sub),
                                  ),
                                );
                              },
                              tooltip: 'Open Task Details',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(MdiIcons.linkOff, color: JweTheme.accentRed, size: 16),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (confirmCtx) => AlertDialog(
                                    backgroundColor: JweTheme.panel,
                                    title: const Text('UNLINK CONTRACT?', style: TextStyle(color: JweTheme.accentRed)),
                                    content: Text('Unlink "${sub.name}" from project?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text('CANCEL')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: JweTheme.accentRed),
                                        onPressed: () => Navigator.pop(confirmCtx, true),
                                        child: const Text('UNLINK'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final updatedKeys = project.linkedTaskKeys.where((k) => k != key).toList();
                                  provider.updateProject(project.copyWith(linkedTaskKeys: updatedKeys));
                                }
                              },
                              tooltip: 'Unlink Task',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'STATUS: ',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5),
                            ),
                            Text(
                              isRunning ? 'RUNNING' : (sub.completed ? 'COMPLETED' : 'PENDING'),
                              style: GoogleFonts.jetBrainsMono(
                                color: isRunning ? JweTheme.accentRed : (sub.completed ? JweTheme.accentTeal : JweTheme.textMid),
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'TIME SPENT: ',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5),
                            ),
                            Text(
                              timeDisplay,
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textMid, fontSize: 8.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: HudProgressBar(
                                value: progress * 100,
                                tone: sub.completed ? HudTone.teal : HudTone.cyan,
                                segments: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress * 100).round()}%',
                              style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'LINKED MISSION CONTRACTS',
                style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showLinkTasksSearchDialog(context, provider, project),
                icon: Icon(MdiIcons.link, size: 14, color: accentColor),
                label: Text('LINK CONTRACT', style: TextStyle(color: accentColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (cards.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: JweTheme.border),
              ),
              alignment: Alignment.center,
              child: const Text('NO CONTRACTS LINKED TO THIS MISSION.', style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final updatedKeys = List<String>.from(project.linkedTaskKeys);
                final item = updatedKeys.removeAt(oldIndex);
                updatedKeys.insert(newIndex, item);
                provider.updateProject(project.copyWith(linkedTaskKeys: updatedKeys));
              },
              children: cards,
            ),
        ],
      ),
    );
  }

  Widget _buildLogsTab(AppProvider provider, Project project, Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'LOGS & NOTES',
                style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddNoteDialog(context, provider, project),
                icon: Icon(MdiIcons.plus, size: 14, color: accentColor),
                label: Text('ADD LOG ENTRY', style: TextStyle(color: accentColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (project.notes.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: JweTheme.border),
              ),
              alignment: Alignment.center,
              child: const Text('NO LOG ENTRIES CREATED.', style: TextStyle(color: JweTheme.textMuted, fontSize: 12)),
            )
          else
            ...project.notes.map((n) => _ProjectNoteCard(note: n, onDelete: () {
                  final updatedNotes = project.notes.where((note) => note.id != n.id).toList();
                  provider.updateProject(project.copyWith(notes: updatedNotes));
                })),
        ],
      ),
    );
  }

  Widget _buildPlanBriefingHero(Project project, Color accentColor, AppProvider provider) {
    final planText = project.files.isNotEmpty 
        ? project.files.first.content 
        : (project.description.isNotEmpty ? project.description : 'NO OPERATIONAL PLAN INITIALIZED.');
    final planTitle = project.files.isNotEmpty 
        ? project.files.first.name 
        : 'OPERATIONAL DIRECTIVE';

    return HudPanel(
      clip: HudClip.both,
      accent: accentColor,
      brackets: true,
      allBrackets: true,
      background: accentColor.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(MdiIcons.shieldAlertOutline, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '// ${planTitle.toUpperCase()}',
                  style: GoogleFonts.jetBrainsMono(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (project.files.isNotEmpty) ...[
                IconButton(
                  icon: Icon(MdiIcons.pencilOutline, color: accentColor, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () => _showFileEditor(context, provider, project, project.files.first),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(MdiIcons.deleteOutline, color: JweTheme.accentRed, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final updated = project.files.where((x) => x.id != project.files.first.id).toList();
                    provider.updateProject(project.copyWith(files: updated));
                  },
                ),
              ] else
                IconButton(
                  icon: Icon(MdiIcons.plus, color: accentColor, size: 16),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () => _showAddFileDialog(context, provider, project),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: accentColor.withValues(alpha: 0.15)),
            ),
            child: Text(
              planText,
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textMid,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(AppProvider provider, Project project, Color accentColor) {
    final streak = calculateProjectStreak(project, provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPlanBriefingHero(project, accentColor, provider),
          const SizedBox(height: 16),
          // Streaks Display
          HudPanel(
            clip: HudClip.br,
            accent: accentColor,
            brackets: true,
            allBrackets: true,
            background: accentColor.withValues(alpha: 0.06),
            child: Row(
              children: [
                Icon(MdiIcons.fire, color: JweTheme.accentRed, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROJECT OPERATION STREAK',
                        style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$streak DAYS ACTIVE',
                        style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text(
                  'MIN 15m / DAY',
                  style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 8.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Weekly Chart Usage
          Text(
            'WEEKLY GRAPH USAGE',
            style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _ProjectWeeklyChart(project: project, accentColor: accentColor),
        ],
      ),
    );
  }
}

class _ProjectNoteCard extends StatefulWidget {
  final ProjectNote note;
  final VoidCallback onDelete;

  const _ProjectNoteCard({required this.note, required this.onDelete});

  @override
  State<_ProjectNoteCard> createState() => _ProjectNoteCardState();
}

class _ProjectNoteCardState extends State<_ProjectNoteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: JweTheme.panel,
      margin: const EdgeInsets.only(bottom: 10),
      shape: const Border(left: BorderSide(color: JweTheme.textMuted, width: 2)),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.note.title.toUpperCase(),
                          style: GoogleFonts.rajdhani(color: JweTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(widget.note.createdAt),
                          style: const TextStyle(color: JweTheme.textMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                    color: JweTheme.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(MdiIcons.deleteOutline, color: JweTheme.accentRed, size: 18),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.note.content,
                  style: GoogleFonts.inter(color: JweTheme.textMid, fontSize: 12, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkTaskDialog extends StatefulWidget {
  final AppProvider provider;
  final Project project;

  const _LinkTaskDialog({required this.provider, required this.project});

  @override
  State<_LinkTaskDialog> createState() => _LinkTaskDialogState();
}

class _LinkTaskDialogState extends State<_LinkTaskDialog> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
              style: const TextStyle(color: JweTheme.textWhite),
              decoration: InputDecoration(
                hintText: 'SEARCH CONTRACTS...',
                hintStyle: const TextStyle(color: JweTheme.textMuted),
                prefixIcon: const Icon(Icons.search, color: JweTheme.textMuted),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: JweTheme.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: JweTheme.accentAmber)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: availableTasks.isEmpty
                  ? const Center(child: Text('NO CONTRACTS DETECTED.', style: TextStyle(color: JweTheme.textMuted)))
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
                            title: Text(sub.name, style: const TextStyle(color: JweTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text('${parent.name.toUpperCase()} • ${sub.completed ? "COMPLETED" : "ONGOING"}', style: TextStyle(color: parent.taskColor, fontSize: 10)),
                            trailing: Icon(MdiIcons.plus, color: JweTheme.accentAmber),
                            onTap: () {
                              final updated = widget.project.copyWith(
                                linkedTaskKeys: [...widget.project.linkedTaskKeys, key],
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
          child: const Text('ABORT', style: TextStyle(color: JweTheme.textMuted)),
        ),
      ],
    );
  }
}

class _ProjectWeeklyChart extends StatelessWidget {
  final Project project;
  final Color accentColor;

  const _ProjectWeeklyChart({required this.project, required this.accentColor});

  String _fmtMins(double v) {
    final m = v.round();
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[];
    final mins = <double>[];

    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      days.add(d);
      double sec = 0;

      for (final key in project.linkedTaskKeys) {
        final parts = key.split('|');
        if (parts.length < 2) continue;
        final mainId = parts[0];
        final subId = parts[1];

        final mainTask = provider.mainTasks.firstWhereOrNull((t) => t.id == mainId);
        final sub = mainTask?.subTasks.firstWhereOrNull((s) => s.id == subId);

        if (sub != null) {
          for (var s in sub.sessions) {
            if (s.startTime.year == d.year && s.startTime.month == d.month && s.startTime.day == d.day) {
              sec += s.durationSeconds;
            }
          }
          final timer = provider.activeTimers[sub.id];
          if (timer != null && timer.isRunning) {
            final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final checkStr = DateFormat('yyyy-MM-dd').format(d);
            if (dateStr == checkStr) {
              final elapsed = DateTime.now().difference(timer.startTime).inSeconds;
              sec += elapsed;
            }
          }
        }
      }
      mins.add(sec / 60.0);
    }

    final hasData = mins.any((v) => v > 0);
    final maxV = hasData ? mins.reduce(math.max) : 0.0;
    final avg = mins.reduce((a, b) => a + b) / 7.0;

    return HudPanel(
      clip: HudClip.br,
      accent: accentColor,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.20))),
            ),
            child: Row(
              children: [
                Container(width: 4, height: 12, color: accentColor),
                const SizedBox(width: 10),
                Text(
                  '// PROJECT WEEKLY TIME USAGE',
                  style: GoogleFonts.jetBrainsMono(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                if (hasData)
                  Text(
                    'μ ${_fmtMins(avg)}/d',
                    style: GoogleFonts.jetBrainsMono(
                      color: JweTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: hasData
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 110,
                        child: CustomPaint(
                          painter: _WeeklyPainter(mins: mins, maxV: maxV, avg: avg, accent: accentColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(7, (i) {
                          final isToday = i == 6;
                          return Expanded(
                            child: Center(
                              child: Text(
                                DateFormat('E').format(days[i]).toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  color: isToday ? accentColor : JweTheme.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            color: accentColor.withValues(alpha: 0.12),
                            child: Text(
                              'TOTAL ${_fmtMins(mins.reduce((a, b) => a + b))}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'NO RECENT ACTIVITY DETECTED',
                        style: GoogleFonts.jetBrainsMono(
                          color: JweTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyPainter extends CustomPainter {
  final List<double> mins;
  final double maxV;
  final double avg;
  final Color accent;

  _WeeklyPainter({required this.mins, required this.maxV, required this.avg, required this.accent});

  String _fmtMins(double v) {
    final m = v.round();
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h${rem}m';
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (mins.isEmpty || maxV <= 0) return;

    final n = mins.length;
    const gap = 6.0;
    final barW = (size.width - gap * (n - 1)) / n;

    final avgY = size.height - (avg / maxV).clamp(0.0, 1.0) * size.height;
    final dashedPaint = Paint()
      ..color = accent.withValues(alpha: 0.30)
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, avgY), Offset(x + 4, avgY), dashedPaint);
      x += 8;
    }

    for (var i = 0; i < n; i++) {
      final v = mins[i];
      final ratio = (v / maxV).clamp(0.0, 1.0);
      final h = ratio * size.height;
      final left = i * (barW + gap);
      final isToday = i == n - 1;
      final isPeak = v > 0 && v == maxV;

      final color = v == 0
          ? const Color(0x1AA8B3C7)
          : (isToday || isPeak ? accent : accent.withValues(alpha: 0.40));

      final rect = Rect.fromLTWH(left, size.height - h, barW, math.max(2.0, h));
      if (isToday || isPeak) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = accent.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawRect(rect, Paint()..color = color);

      if (v > 0) {
        canvas.drawRect(
          Rect.fromLTWH(left, size.height - h - 2, barW, 2),
          Paint()..color = accent,
        );

        final valStr = _fmtMins(v);
        final p = TextPainter(
          text: TextSpan(
            text: valStr,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              color: isToday || isPeak ? accent : JweTheme.textMid,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: barW + gap);
        final ly = math.max(0.0, size.height - h - p.height - 4);
        p.paint(canvas, Offset(left + (barW - p.width) / 2, ly));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyPainter old) =>
      old.mins != mins || old.maxV != maxV || old.avg != avg || old.accent != accent;
}
