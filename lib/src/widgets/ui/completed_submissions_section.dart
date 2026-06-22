import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/widgets/cards/submission_card.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CompletedSubmissionsSection extends StatefulWidget {
  final MainTask parentTask;
  final List<SubTask> completedSubtasks;

  const CompletedSubmissionsSection({
    super.key,
    required this.parentTask,
    required this.completedSubtasks,
  });

  @override
  State<CompletedSubmissionsSection> createState() => _CompletedSubmissionsSectionState();
}

class _CompletedSubmissionsSectionState extends State<CompletedSubmissionsSection> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.completedSubtasks.isEmpty) return const SizedBox.shrink();

    final filtered = widget.completedSubtasks.where((st) {
      if (_searchQuery.isEmpty) return true;
      return st.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(MdiIcons.archiveCheckOutline,
                color: widget.parentTask.taskColor.withOpacity(0.7), size: 20),
            title: Text(
              _searchQuery.isEmpty
                  ? "ARCHIVED MISSIONS (${widget.completedSubtasks.length})"
                  : "ARCHIVED MISSIONS (${filtered.length}/${widget.completedSubtasks.length})",
              style: TextStyle(
                color: AppTheme.fhTextSecondary,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontDisplay,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
            childrenPadding: EdgeInsets.zero,
            children: [
              // Search Input Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "SEARCH ARCHIVED MISSIONS...",
                    hintStyle: GoogleFonts.jetBrainsMono(
                      color: AppTheme.fhTextSecondary.withOpacity(0.5),
                      fontSize: 11,
                    ),
                    prefixIcon: Icon(
                      MdiIcons.magnify,
                      color: widget.parentTask.taskColor.withOpacity(0.7),
                      size: 18,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.fhBgDark.withOpacity(0.3),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppTheme.fhBorderColor.withOpacity(0.15),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.zero,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: widget.parentTask.taskColor.withOpacity(0.5),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),
              
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      "NO MATCHING MISSIONS FOUND",
                      style: GoogleFonts.jetBrainsMono(
                        color: AppTheme.fhTextSecondary.withOpacity(0.5),
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map((st) {
                  return SubmissionCard(parentTask: widget.parentTask, subTask: st);
                }),
            ],
          ),
        ),
      ],
    );
  }
}