import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/models/sop_model.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/screens/settings/sop_edit_screen.dart';
import 'package:missions/src/screens/settings/sop_running_screen.dart';
import 'package:missions/src/widgets/dialogs/sop_task_selection_modal.dart';

class SopListScreen extends StatefulWidget {
  const SopListScreen({super.key});

  @override
  State<SopListScreen> createState() => _SopListScreenState();
}

class _SopListScreenState extends State<SopListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final allSops = provider.sops;

    final filteredSops = allSops.where((sop) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return sop.title.toLowerCase().contains(q) ||
          sop.situation.toLowerCase().contains(q) ||
          sop.expectedOutcomes.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: JweTheme.bgCanvas,
      appBar: AppBar(
        backgroundColor: JweTheme.bgCanvas,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: JweTheme.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'STANDARD OPERATIONAL PROCEDURES',
          style: GoogleFonts.jetBrainsMono(
            color: JweTheme.accentAmber,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: JweTheme.lineSoft, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Active Running SOP Banner
          if (provider.activeSopSession != null)
            _buildActiveRunningSopBanner(context, provider),

          // Header / Search bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.fhBgMedium,
              border: Border(bottom: BorderSide(color: JweTheme.lineSoft)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search SOPs by title or situation...',
                      hintStyle: TextStyle(color: JweTheme.textMuted, fontSize: 13),
                      prefixIcon: Icon(MdiIcons.magnify, color: JweTheme.textMuted, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: JweTheme.bgCanvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: JweTheme.lineSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: JweTheme.lineSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: JweTheme.accentCyan),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SopEditScreen()),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    'NEW SOP',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.fhAccentTeal,
                    foregroundColor: AppTheme.fhBgDark,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // List of SOPs
          Expanded(
            child: filteredSops.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSops.length,
                    itemBuilder: (context, index) {
                      final sop = filteredSops[index];
                      return Dismissible(
                        key: ValueKey('sop_dismiss_${sop.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmDeleteSop(context, provider, sop),
                        onDismissed: (_) {
                          provider.deleteSop(sop.id);
                        },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.fhAccentRed.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'SWIPE TO DELETE',
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.delete, color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                        child: _SopCard(
                          sop: sop,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SopEditScreen(sop: sop)),
                            );
                          },
                          onPlay: () {
                            showDialog(
                              context: context,
                              builder: (_) => SopTaskSelectionModal(sop: sop),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRunningSopBanner(BuildContext context, AppProvider provider) {
    final session = provider.activeSopSession!;
    final elapsedSecs = session.elapsedSeconds;
    final mins = elapsedSecs ~/ 60;
    final secs = elapsedSecs % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.fhAccentTeal.withValues(alpha: 0.15),
        border: Border(bottom: BorderSide(color: AppTheme.fhAccentTeal.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.fhAccentTeal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOP RUNNING: ${session.sop.title.isNotEmpty ? session.sop.title : "Untitled"}',
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.fhAccentTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Elapsed: $timeStr • ${session.completedStepIndices.length}/${session.sop.steps.length} Steps Completed',
                  style: TextStyle(color: JweTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SopRunningScreen()),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 14),
            label: Text(
              'OPEN VIEW',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.fhAccentTeal,
              foregroundColor: AppTheme.fhBgDark,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.clipboardListOutline, size: 54, color: JweTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'NO MATCHING SOPS FOUND' : 'NO SOPS CREATED YET',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try modifying your search term.'
                  : 'Standard Operational Procedures save time by documenting clear, actionable steps for recurring situations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: JweTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SopEditScreen()),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'CREATE YOUR FIRST SOP',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.fhAccentTeal,
                  foregroundColor: AppTheme.fhBgDark,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteSop(BuildContext context, AppProvider provider, SopModel sop) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.fhBgMedium,
        title: Text(
          'DELETE SOP',
          style: GoogleFonts.jetBrainsMono(color: AppTheme.fhAccentRed, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${sop.title}"? This cannot be undone.',
          style: TextStyle(color: JweTheme.textWhite, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.fhAccentRed),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _SopCard extends StatelessWidget {
  final SopModel sop;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _SopCard({
    required this.sop,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final logCount = sop.executionLogs.length;
    final successCount = sop.executionLogs.where((l) => l.successStatus == 'success').length;
    final successRate = logCount > 0 ? ((successCount / logCount) * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.fhBgMedium,
        border: Border.all(color: JweTheme.lineSoft),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.fhAccentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(MdiIcons.clipboardListOutline, color: AppTheme.fhAccentTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sop.title.isNotEmpty ? sop.title : 'Untitled SOP',
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (sop.situation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            sop.situation,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: JweTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: Text(
                      'START',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.fhAccentTeal,
                      foregroundColor: AppTheme.fhBgDark,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: JweTheme.lineSoft, height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatBadge(
                    icon: MdiIcons.formatListNumbered,
                    label: '${sop.steps.length} Steps',
                    color: JweTheme.accentCyan,
                  ),
                  const SizedBox(width: 12),
                  _StatBadge(
                    icon: MdiIcons.history,
                    label: '$logCount Trials',
                    color: JweTheme.accentAmber,
                  ),
                  if (logCount > 0) ...[
                    const SizedBox(width: 12),
                    _StatBadge(
                      icon: MdiIcons.checkCircleOutline,
                      label: '$successRate% Success',
                      color: successRate >= 70 ? AppTheme.fhAccentGreen : AppTheme.fhAccentOrange,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    DateFormat('d MMM').format(sop.updatedAt),
                    style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
