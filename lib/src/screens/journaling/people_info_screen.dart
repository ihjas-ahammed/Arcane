import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/screens/journaling/person_detail_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
export 'people/people.dart';

// Helper function to categorize relationships based on priority
String getRelationCategory(String relation) => PersonInfo.getRelationCategory(relation);

class PeopleInfoScreen extends StatefulWidget {
  const PeopleInfoScreen({super.key});

  @override
  State<PeopleInfoScreen> createState() => _PeopleInfoScreenState();
}

class _PeopleInfoScreenState extends State<PeopleInfoScreen> {
  String _searchQuery = "";
  String _sortBy = "Priority"; // "Priority", "Alphabetical", "Last Scanned"

  // Multiselect state properties
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _showExtractionWizard(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16),
        child: PeopleExtractionWizard(),
      ),
    );
  }

  void _confirmMultiDelete(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PersonInfoTheme.bgPanel,
        shape: BeveledRectangleBorder(
          side: BorderSide(color: PersonInfoTheme.spideyRed, width: 1.5),
        ),
        title: Text(
          "PURGE INTELLIGENCE DOSSIERS",
          style: GoogleFonts.rajdhani(
            color: PersonInfoTheme.spideyRed,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        content: Text(
          "Are you sure you want to permanently erase ${_selectedIds.length} selected individual dossiers from the system archives?",
          style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "ABORT",
              style: GoogleFonts.rajdhani(color: PersonInfoTheme.textGrey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PersonInfoTheme.spideyRed,
              foregroundColor: Colors.white,
              shape: const BeveledRectangleBorder(),
            ),
            onPressed: () {
              Navigator.pop(context);
              _performMultiDelete(provider);
            },
            child: Text(
              "CONFIRM PURGE",
              style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _performMultiDelete(AppProvider provider) {
    final updatedList = List<PersonInfo>.from(provider.chatbotMemory.people)
      ..removeWhere((p) => _selectedIds.contains(p.id));

    provider.updatePeopleList(updatedList);

    final count = _selectedIds.length;
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$count records successfully purged from archives.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final people = provider.chatbotMemory.people;

    // 1. Filter by search query
    List<PersonInfo> filteredList = people.where((p) {
      final nameMatches = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final relationMatches = p.relation.toLowerCase().contains(_searchQuery.toLowerCase());
      return nameMatches || relationMatches;
    }).toList();

    // 2. Sort overall
    if (_sortBy == "Alphabetical") {
      filteredList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortBy == "Last Scanned") {
      filteredList.sort((a, b) {
        final aTime = a.scanRangeEnd ?? a.lastUpdated ?? DateTime(2000);
        final bTime = b.scanRangeEnd ?? b.lastUpdated ?? DateTime(2000);
        return bTime.compareTo(aTime); // Newest first
      });
    } else {
      // Priority sorting
      filteredList.sort((a, b) {
        final catA = getRelationCategory(a.relation);
        final catB = getRelationCategory(b.relation);
        final priorityMap = {
          'Family & Partner': 1,
          'Friends': 2,
          'Professional & Mentors': 3,
          'Acquaintances & Others': 4,
        };
        final pA = priorityMap[catA] ?? 5;
        final pB = priorityMap[catB] ?? 5;
        if (pA != pB) return pA.compareTo(pB);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase()); // Sub-sort alphabetically
      });
    }

    // 3. Group by priority category
    final grouped = <String, List<PersonInfo>>{
      'Family & Partner': [],
      'Friends': [],
      'Professional & Mentors': [],
      'Acquaintances & Others': [],
    };

    for (var p in filteredList) {
      final cat = getRelationCategory(p.relation);
      grouped[cat]?.add(p);
    }

    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close, color: PersonInfoTheme.textWhite),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : null,
        title: _isSelectionMode
            ? Text(
                "${_selectedIds.length} SELECTED",
                style: GoogleFonts.rajdhani(
                  color: PersonInfoTheme.spideyCyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                  shadows: [
                    Shadow(color: ArcEffects.cyanGlow(0.4), blurRadius: 8),
                  ],
                ),
              )
            : const Text("PEOPLE INTEL"),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(Icons.delete, color: PersonInfoTheme.spideyRed),
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => _confirmMultiDelete(context, provider),
            )
          else if (people.isNotEmpty)
            IconButton(
              icon: Icon(Icons.checklist, color: PersonInfoTheme.spideyCyan),
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // SCAN/REFRESH TRIGGER (Visible only when not selecting)
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ValorantButton(
                  label: "INITIATE TACTICAL SCANS",
                  icon: MdiIcons.accountSearchOutline,
                  isPrimary: true,
                  color: AppTheme.fhAccentTeal,
                  onPressed: () => _showExtractionWizard(context),
                ),
              ),
            ),

          // SEARCH & SORT BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.fhBgDark,
                      border: Border.all(color: ArcStrokes.steel),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: GoogleFonts.rajdhani(color: AppTheme.fhTextPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "SEARCH IDENTIFIED TARGET...",
                        hintStyle: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 11),
                        prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.fhTextSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark,
                    border: Border.all(color: ArcStrokes.steel),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      dropdownColor: AppTheme.fhBgDeepDark,
                      icon: Icon(Icons.sort, color: PersonInfoTheme.spideyCyan, size: 16),
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.fhTextPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Priority",
                          child: Text("PRIORITY"),
                        ),
                        DropdownMenuItem(
                          value: "Alphabetical",
                          child: Text("A - Z"),
                        ),
                        DropdownMenuItem(
                          value: "Last Scanned",
                          child: Text("LAST SCANNED"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _sortBy = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LIST CONTENT
          Expanded(
            child: people.isEmpty
                ? Center(child: Text("NO INTEL AVAILABLE.", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay, fontSize: 20)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      for (var entry in grouped.entries)
                        if (entry.value.isNotEmpty) ...[
                          _buildCategoryHeader(entry.key, entry.value.length),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: entry.value.length,
                            itemBuilder: (context, index) {
                              final p = entry.value[index];
                              final isSelected = _selectedIds.contains(p.id);

                              return TacticalPersonCard(
                                person: p,
                                isSelectionMode: _isSelectionMode,
                                isSelected: isSelected,
                                onSelectedChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIds.add(p.id);
                                    } else {
                                      _selectedIds.remove(p.id);
                                    }
                                  });
                                },
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    setState(() {
                                      _isSelectionMode = true;
                                      _selectedIds.add(p.id);
                                    });
                                  }
                                },
                                onTap: () {
                                  if (_isSelectionMode) {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedIds.remove(p.id);
                                      } else {
                                        _selectedIds.add(p.id);
                                      }
                                    });
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: p.id)),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      if (filteredList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 80.0),
                          child: Center(
                            child: Text(
                              "NO CORRESPONDING RECORDS FOUND.",
                              style: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 13, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                    ],
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String category, int count) {
    Color accentColor = AppTheme.fhTextSecondary;
    if (category == 'Family & Partner') accentColor = Colors.pinkAccent;
    if (category == 'Friends') accentColor = Colors.greenAccent;
    if (category == 'Professional & Mentors') accentColor = PersonInfoTheme.spideyCyan;

    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          color: accentColor,
        ),
        const SizedBox(width: 8),
        Text(
          "${category.toUpperCase()} [$count]",
          style: GoogleFonts.rajdhani(
            color: accentColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: accentColor.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}