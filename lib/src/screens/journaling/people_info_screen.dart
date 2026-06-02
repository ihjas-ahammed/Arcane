import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/screens/journaling/person_detail_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

// Helper function to categorize relationships based on priority
String getRelationCategory(String relation) {
  final rel = relation.toLowerCase().trim();
  if (rel.contains('spouse') || rel.contains('partner') || rel.contains('wife') || rel.contains('husband') ||
      rel.contains('mother') || rel.contains('father') || rel.contains('parent') || rel.contains('sibling') ||
      rel.contains('sister') || rel.contains('brother') || rel.contains('family') || rel.contains('son') ||
      rel.contains('daughter') || rel.contains('girlfriend') || rel.contains('boyfriend')) {
    return 'Family & Partner';
  }
  if (rel.contains('friend') || rel.contains('buddy') || rel.contains('mate') || rel.contains('bestie')) {
    return 'Friends';
  }
  if (rel.contains('boss') || rel.contains('colleague') || rel.contains('mentor') || rel.contains('manager') ||
      rel.contains('teacher') || rel.contains('coworker') || rel.contains('work') || rel.contains('client')) {
    return 'Professional & Mentors';
  }
  return 'Acquaintances & Others';
}

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
        shape: const BeveledRectangleBorder(
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
                icon: const Icon(Icons.close, color: PersonInfoTheme.textWhite),
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
                    const Shadow(color: Color(0x6600f0ff), blurRadius: 8),
                  ],
                ),
              )
            : const Text("PEOPLE INTEL"),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: PersonInfoTheme.spideyRed),
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => _confirmMultiDelete(context, provider),
            )
          else if (people.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.checklist, color: PersonInfoTheme.spideyCyan),
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
                      border: Border.all(color: const Color(0xFF1f2f40)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: GoogleFonts.rajdhani(color: AppTheme.fhTextPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "SEARCH IDENTIFIED TARGET...",
                        hintStyle: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 11),
                        prefixIcon: Icon(Icons.search, size: 16, color: AppTheme.fhTextSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                    border: Border.all(color: const Color(0xFF1f2f40)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      dropdownColor: AppTheme.fhBgDeepDark,
                      icon: const Icon(Icons.sort, color: PersonInfoTheme.spideyCyan, size: 16),
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
                ? const Center(child: Text("NO INTEL AVAILABLE.", style: TextStyle(color: AppTheme.fhTextDisabled, fontFamily: AppTheme.fontDisplay, fontSize: 20)))
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
                        const Padding(
                          padding: EdgeInsets.only(top: 80.0),
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

// --- DYNAMIC TACTICAL LIST VIEW CARD ---
class TacticalPersonCard extends StatelessWidget {
  final PersonInfo person;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  
  // Selection fields
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const TacticalPersonCard({
    super.key,
    required this.person,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color categoryColor = _getCategoryColor(person.relation);
    
    // Parse level details if available
    int level = 1;
    String title = "Entity";
    if (person.details != null && person.details!.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(person.details!);
        level = parsed['level'] ?? 1;
        title = parsed['title'] ?? "Entity";
      } catch (_) {}
    }

    final rangeText = person.scanRangeStart != null && person.scanRangeEnd != null
        ? "${DateFormat('MM/dd').format(person.scanRangeStart!)} - ${DateFormat('MM/dd').format(person.scanRangeEnd!)}"
        : "No active scan";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0e2133) : AppTheme.fhBgDark,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? PersonInfoTheme.spideyCyan : const Color(0xFF1f2f40), 
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              children: [
                // Glowing Left side Category Indicator (or checkbox if selecting)
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: PersonInfoTheme.spideyCyan,
                    checkColor: Colors.black,
                    side: const BorderSide(color: Color(0xFF1f2f40)),
                    onChanged: onSelectedChanged,
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withValues(alpha: 0.8),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                
                // Holographic Circle Avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.08),
                    border: Border.all(color: categoryColor.withValues(alpha: 0.3), width: 1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      person.name.isNotEmpty ? person.name[0].toUpperCase() : "?",
                      style: GoogleFonts.rajdhani(
                        color: categoryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Name & Relation & Age & Scan info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name.toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.fhTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              person.relation.toUpperCase(),
                              style: GoogleFonts.rajdhani(
                                color: categoryColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (person.manualAge != null) ...[
                            Text(
                              "AGE: ${person.manualAge}",
                              style: GoogleFonts.rajdhani(
                                color: AppTheme.fhTextSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              "SCAN: $rangeText",
                              style: GoogleFonts.rajdhani(
                                color: AppTheme.fhTextDisabled,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                
                // AI Level Indicators
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF1f2f40)),
                        borderRadius: BorderRadius.circular(4),
                        color: const Color(0xFF061019),
                      ),
                      child: Text(
                        "LVL $level",
                        style: GoogleFonts.rajdhani(
                          color: PersonInfoTheme.spideyCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.fhTextSecondary,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String relation) {
    final cat = getRelationCategory(relation);
    switch (cat) {
      case 'Family & Partner':
        return Colors.pinkAccent;
      case 'Friends':
        return Colors.greenAccent;
      case 'Professional & Mentors':
        return PersonInfoTheme.spideyCyan;
      default:
        return AppTheme.fhTextDisabled;
    }
  }
}

// --- INTERACTIVE BATCHED COGNITIVE EXTRACTION WIZARD ---
class PeopleExtractionWizard extends StatefulWidget {
  const PeopleExtractionWizard({super.key});

  @override
  State<PeopleExtractionWizard> createState() => _PeopleExtractionWizardState();
}

class _PeopleExtractionWizardState extends State<PeopleExtractionWizard> {
  int _step = 0; // 0: Options, 1: Scanning, 2: Resolving, 3: Success
  int _rangeDays = 30; // 7, 30, 90, 365 (All-Time)

  List<Map<String, dynamic>> _extractedPeople = [];
  String _scanError = "";

  int _resolvingIndex = 0;
  final List<Map<String, dynamic>> _resolvedItems = []; // List of final PersonInfo to save
  bool _showConfusionUI = false;
  Map<String, dynamic>? _conflictingExtracted;
  PersonInfo? _conflictingExisting;

  DateTime? _scanRangeStart;
  DateTime? _scanRangeEnd;

  bool isSimilar(String name1, String name2) {
    final n1 = name1.toLowerCase().trim();
    final n2 = name2.toLowerCase().trim();
    if (n1 == n2) return true;
    
    if (n1.length > 3 && n2.length > 3) {
      if (n1.contains(n2) || n2.contains(n1)) return true;
    }
    
    final parts1 = n1.split(' ');
    final parts2 = n2.split(' ');
    if (parts1.isNotEmpty && parts2.isNotEmpty) {
      final first1 = parts1[0];
      final first2 = parts2[0];
      if (first1.length > 2 && first1 == first2) {
        return true;
      }
    }

    int dist = _levenshtein(n1, n2);
    return dist <= 3;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    
    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);
    
    for (int i = 0; i < v0.length; i++) {
      v0[i] = i;
    }
    
    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }
      v0 = List<int>.from(v1);
    }
    return v0[t.length];
  }

  int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);

  Future<void> _startScan(AppProvider provider) async {
    setState(() {
      _step = 1;
      _scanError = "";
    });

    try {
      final now = DateTime.now();
      DateTime? limit;
      if (_rangeDays == 7) {
        limit = now.subtract(const Duration(days: 7));
      } else if (_rangeDays == 30) {
        limit = now.subtract(const Duration(days: 30));
      } else if (_rangeDays == 90) {
        limit = now.subtract(const Duration(days: 90));
      }

      final filteredLogs = limit == null
          ? provider.reflectionLogs
          : provider.reflectionLogs.where((l) => l.timestamp.isAfter(limit!)).toList();

      if (filteredLogs.isEmpty) {
        setState(() {
          _step = 0;
          _scanError = "No journal logs logged inside this timeframe.";
        });
        return;
      }

      DateTime minDate = filteredLogs.first.timestamp;
      DateTime maxDate = filteredLogs.first.timestamp;
      for (var log in filteredLogs) {
        if (log.timestamp.isBefore(minDate)) minDate = log.timestamp;
        if (log.timestamp.isAfter(maxDate)) maxDate = log.timestamp;
      }
      _scanRangeStart = minDate;
      _scanRangeEnd = maxDate;

      final logsText = filteredLogs
          .map((l) => "[${l.timestamp.toIso8601String()}] ${l.trigger}: ${l.emotion} - ${l.reason}")
          .join('\n');

      // Call AI Service with Lite Model per instructions
      final results = await provider.aiService.extractPeopleFromReflections(
        logsText: logsText,
        modelCandidates: provider.settings.liteModels,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKeys: provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[PeopleExtraction] $msg"),
      );

      if (results.isEmpty) {
        setState(() {
          _step = 3;
        });
        return;
      }

      setState(() {
        _extractedPeople = results;
        _step = 2;
        _resolvingIndex = 0;
      });

      _processNextEntity(provider);

    } catch (e) {
      setState(() {
        _step = 0;
        _scanError = "Cognitive scan aborted: $e";
      });
    }
  }

  void _processNextEntity(AppProvider provider) {
    if (_resolvingIndex >= _extractedPeople.length) {
      setState(() {
        _step = 3;
      });
      return;
    }

    final extracted = _extractedPeople[_resolvingIndex];
    final name = extracted['name'] as String? ?? '';
    final relation = extracted['relation'] as String? ?? 'Acquaintance';

    if (name.trim().isEmpty) {
      _resolvingIndex++;
      _processNextEntity(provider);
      return;
    }

    final existingPeople = provider.chatbotMemory.people;
    final exactMatchIdx = existingPeople.indexWhere((p) => p.name.toLowerCase().trim() == name.toLowerCase().trim());

    if (exactMatchIdx != -1) {
      // Match found! Auto-merge details & expand scan range
      final existing = existingPeople[exactMatchIdx];
      
      final newStart = (existing.scanRangeStart == null || _scanRangeStart!.isBefore(existing.scanRangeStart!))
          ? _scanRangeStart
          : existing.scanRangeStart;
      final newEnd = (existing.scanRangeEnd == null || _scanRangeEnd!.isAfter(existing.scanRangeEnd!))
          ? _scanRangeEnd
          : existing.scanRangeEnd;

      final updated = PersonInfo(
        id: existing.id,
        name: existing.name,
        relation: relation.isNotEmpty && relation != 'Acquaintance' ? relation : existing.relation,
        details: existing.details,
        lastUpdated: DateTime.now(),
        scanRangeStart: newStart,
        scanRangeEnd: newEnd,
        manualAge: existing.manualAge,
        manualGender: existing.manualGender,
        manualNotes: existing.manualNotes,
        manualNextMeetPlan: existing.manualNextMeetPlan,
        manualLastContactIntel: existing.manualLastContactIntel,
        manualOccupation: existing.manualOccupation,
        manualLocation: existing.manualLocation,
        manualBirthday: existing.manualBirthday,
        manualContact: existing.manualContact,
      );

      _resolvedItems.add({
        'type': 'merge_exact',
        'person': updated,
        'originalName': name,
      });

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _resolvingIndex++;
          });
          _processNextEntity(provider);
        }
      });
      return;
    }

    // Similarity checking for potential duplicates (AI Confusion)
    PersonInfo? conflicting;
    for (var p in existingPeople) {
      if (isSimilar(p.name, name)) {
        conflicting = p;
        break;
      }
    }

    if (conflicting != null) {
      // Pause automatic loader and show confusion selection panel
      setState(() {
        _showConfusionUI = true;
        _conflictingExtracted = extracted;
        _conflictingExisting = conflicting;
      });
    } else {
      // Brand new entity
      final newPerson = PersonInfo(
        id: const Uuid().v4(),
        name: name,
        relation: relation,
        scanRangeStart: _scanRangeStart,
        scanRangeEnd: _scanRangeEnd,
        lastUpdated: DateTime.now(),
      );

      _resolvedItems.add({
        'type': 'new',
        'person': newPerson,
        'originalName': name,
      });

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _resolvingIndex++;
          });
          _processNextEntity(provider);
        }
      });
    }
  }

  void _resolveConfusion(AppProvider provider, bool merge) {
    if (merge) {
      final existing = _conflictingExisting!;
      final relation = _conflictingExtracted!['relation'] as String? ?? 'Acquaintance';
      
      final newStart = (existing.scanRangeStart == null || _scanRangeStart!.isBefore(existing.scanRangeStart!))
          ? _scanRangeStart
          : existing.scanRangeStart;
      final newEnd = (existing.scanRangeEnd == null || _scanRangeEnd!.isAfter(existing.scanRangeEnd!))
          ? _scanRangeEnd
          : existing.scanRangeEnd;

      final updated = PersonInfo(
        id: existing.id,
        name: existing.name,
        relation: relation.isNotEmpty && relation != 'Acquaintance' ? relation : existing.relation,
        details: existing.details,
        lastUpdated: DateTime.now(),
        scanRangeStart: newStart,
        scanRangeEnd: newEnd,
        manualAge: existing.manualAge,
        manualGender: existing.manualGender,
        manualNotes: existing.manualNotes,
        manualNextMeetPlan: existing.manualNextMeetPlan,
        manualLastContactIntel: existing.manualLastContactIntel,
        manualOccupation: existing.manualOccupation,
        manualLocation: existing.manualLocation,
        manualBirthday: existing.manualBirthday,
        manualContact: existing.manualContact,
      );

      _resolvedItems.add({
        'type': 'merge_confusion',
        'person': updated,
        'originalName': _conflictingExtracted!['name'],
      });
    } else {
      final newPerson = PersonInfo(
        id: const Uuid().v4(),
        name: _conflictingExtracted!['name'],
        relation: _conflictingExtracted!['relation'] ?? 'Acquaintance',
        scanRangeStart: _scanRangeStart,
        scanRangeEnd: _scanRangeEnd,
        lastUpdated: DateTime.now(),
      );

      _resolvedItems.add({
        'type': 'new',
        'person': newPerson,
        'originalName': _conflictingExtracted!['name'],
      });
    }

    setState(() {
      _showConfusionUI = false;
      _resolvingIndex++;
    });
    _processNextEntity(provider);
  }

  void _commitChanges(AppProvider provider) {
    final list = List<PersonInfo>.from(provider.chatbotMemory.people);

    for (var r in _resolvedItems) {
      final person = r['person'] as PersonInfo;
      final type = r['type'] as String;

      if (type.startsWith('merge')) {
        final idx = list.indexWhere((p) => p.id == person.id);
        if (idx != -1) {
          list[idx] = person;
        }
      } else {
        list.insert(0, person);
      }
    }

    provider.updatePeopleList(list);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 500, maxWidth: 450),
      decoration: BoxDecoration(
        color: PersonInfoTheme.bgPanel,
        border: Border.all(color: PersonInfoTheme.spideyCyan, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x3300f0ff), blurRadius: 20, spreadRadius: 1)
        ],
      ),
      child: Column(
        children: [
          // Cyberpunk glowing title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [PersonInfoTheme.headerGradientStart, Color(0xFF0b1623)],
              ),
              border: Border(bottom: BorderSide(color: Color(0xFF1f2f40))),
            ),
            child: Row(
              children: [
                const Icon(Icons.radar, color: PersonInfoTheme.spideyCyan, size: 18),
                const SizedBox(width: 8),
                Text(
                  "TACTICAL COGNITIVE SCANNER",
                  style: GoogleFonts.rajdhani(
                    color: PersonInfoTheme.spideyCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                if (_step != 1)
                  IconButton(
                    icon: const Icon(Icons.close, color: PersonInfoTheme.textGrey, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Content view
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildWizardStep(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizardStep(AppProvider provider) {
    if (_step == 0) {
      // Step 0: Choose range
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SELECT REFLECTION ARCHIVES SCALING",
            style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_scanError.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: PersonInfoTheme.spideyRed.withValues(alpha: 0.1),
                border: Border.all(color: PersonInfoTheme.spideyRed.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _scanError,
                style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyRed, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          _buildRangeRadioOption(7, "7 DAYS ARCHIVE MATRIX"),
          _buildRangeRadioOption(30, "30 DAYS ARCHIVE MATRIX"),
          _buildRangeRadioOption(90, "90 DAYS ARCHIVE MATRIX"),
          _buildRangeRadioOption(365, "ALL-TIME SYSTEM ARCHIVES"),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ValorantButton(
              label: "LAUNCH INTEL EXTRACTION",
              isPrimary: true,
              color: PersonInfoTheme.spideyCyan,
              onPressed: () => _startScan(provider),
            ),
          ),
        ],
      );
    } else if (_step == 1) {
      // Step 1: Scanning
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: PersonInfoTheme.spideyCyan,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "SCANNING JOURNAL RECORDS...",
                style: GoogleFonts.rajdhani(
                  color: PersonInfoTheme.spideyCyan,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "AI is parsing your raw reflections to identify referenced individuals using highly optimized Lite intelligence models...",
                style: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 11, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (_step == 2) {
      // Step 2: Resolving & Similarity checking
      if (_showConfusionUI) {
        return _buildConfusionUI(provider);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "COMPILING SCANNED COGNITIONS",
            style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyCyan, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _extractedPeople.length,
            itemBuilder: (context, index) {
              final isCurrent = index == _resolvingIndex;
              final isResolved = index < _resolvingIndex;
              final pName = _extractedPeople[index]['name'] as String? ?? '';
              final pRelation = _extractedPeople[index]['relation'] as String? ?? '';

              // Find resolution type
              String statusText = "WAITING SYSTEM QUEUE";
              Color statusColor = PersonInfoTheme.textGrey;
              IconData icon = Icons.hourglass_empty;

              if (isResolved) {
                final resolved = _resolvedItems.firstWhere((r) => r['originalName'] == pName);
                final type = resolved['type'] as String;
                if (type.startsWith('merge')) {
                  statusText = "MERGED TO SYSTEM FILE";
                  statusColor = Colors.greenAccent;
                  icon = Icons.done_all;
                } else {
                  statusText = "NEW SYSTEM ENTRY APPROVED";
                  statusColor = PersonInfoTheme.spideyCyan;
                  icon = Icons.person_add;
                }
              } else if (isCurrent) {
                statusText = "ANALYZING TARGET STRUCTURE...";
                statusColor = Colors.orangeAccent;
                icon = Icons.sync;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFF0d1e2f) : const Color(0xFF07121c),
                  border: Border.all(color: isCurrent ? PersonInfoTheme.spideyCyan : const Color(0xFF1f2f40)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: statusColor, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pName.toUpperCase(),
                            style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pRelation.toUpperCase(),
                            style: GoogleFonts.rajdhani(color: PersonInfoTheme.textGrey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      statusText.toUpperCase(),
                      style: GoogleFonts.rajdhani(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    } else {
      // Step 3: Completed
      final newCount = _resolvedItems.where((r) => r['type'] == 'new').length;
      final mergeCount = _resolvedItems.where((r) => r['type'].toString().startsWith('merge')).length;

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_good, color: PersonInfoTheme.spideyCyan, size: 48),
              const SizedBox(height: 16),
              Text(
                "INTEGRATION SPECS REGISTERED",
                style: GoogleFonts.rajdhani(
                  color: PersonInfoTheme.spideyCyan,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF07121c),
                  border: Border.all(color: const Color(0xFF1f2f40)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow("ENTITIES SCANNED", "${_extractedPeople.length}"),
                    const Divider(color: Color(0xFF1f2f40), height: 16),
                    _buildSummaryRow("NEW CONTACT NODES", "$newCount"),
                    const Divider(color: Color(0xFF1f2f40), height: 16),
                    _buildSummaryRow("OPTIMIZED SYSTEM DOSSIERS", "$mergeCount"),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ValorantButton(
                  label: "SYNC COGNITION TO SYSTEM",
                  isPrimary: true,
                  color: PersonInfoTheme.spideyCyan,
                  onPressed: () => _commitChanges(provider),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildRangeRadioOption(int days, String label) {
    final isSelected = _rangeDays == days;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0d1e2f) : const Color(0xFF07121c),
        border: Border.all(color: isSelected ? PersonInfoTheme.spideyCyan : const Color(0xFF1f2f40)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: RadioListTile<int>(
        value: days,
        groupValue: _rangeDays,
        title: Text(
          label,
          style: GoogleFonts.rajdhani(
            color: isSelected ? PersonInfoTheme.spideyCyan : PersonInfoTheme.textWhite,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        activeColor: PersonInfoTheme.spideyCyan,
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _rangeDays = val;
            });
          }
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.rajdhani(color: PersonInfoTheme.textGrey, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          val,
          style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildConfusionUI(AppProvider provider) {
    final scannedName = _conflictingExtracted!['name'] as String? ?? '';
    final scannedRelation = _conflictingExtracted!['relation'] as String? ?? 'Acquaintance';
    final contextSnippet = _conflictingExtracted!['context'] as String? ?? 'Mentioned in reflection archives.';
    final existingName = _conflictingExisting!.name;
    final existingRelation = _conflictingExisting!.relation;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF261811), // custom glowing orange container
        border: Border.all(color: Colors.orangeAccent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orangeAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                "DUPLICATION CONFLICT DETECTED!",
                style: GoogleFonts.rajdhani(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Is the scanned entity name '$scannedName' the same person as existing archival record '$existingName'?",
            style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          
          // Show how AI found them
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF140c08),
              border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI DISCOVERY MATRIX PATHWAY (HOW AI FOUND THEM):",
                  style: GoogleFonts.rajdhani(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "\"$contextSnippet\"",
                  style: GoogleFonts.rajdhani(
                    color: PersonInfoTheme.textWhite.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("SCANNED EXTRACT", style: GoogleFonts.rajdhani(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                    Text(scannedName.toUpperCase(), style: const TextStyle(color: PersonInfoTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(scannedRelation.toUpperCase(), style: const TextStyle(color: PersonInfoTheme.textGrey, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(
                height: 30,
                child: VerticalDivider(color: Colors.orangeAccent, width: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("EXISTING DOSSIER", style: GoogleFonts.rajdhani(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                    Text(existingName.toUpperCase(), style: const TextStyle(color: PersonInfoTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(existingRelation.toUpperCase(), style: const TextStyle(color: PersonInfoTheme.textGrey, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(color: Colors.orangeAccent),
                    shape: const BeveledRectangleBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _resolveConfusion(provider, false),
                  child: Text(
                    "NO, KEEP SEPARATE",
                    style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    shape: const BeveledRectangleBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _resolveConfusion(provider, true),
                  child: Text(
                    "YES, MERGE FILES",
                    style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}