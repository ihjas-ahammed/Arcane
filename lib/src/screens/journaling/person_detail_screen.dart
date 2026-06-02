import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'package:missions/src/widgets/journaling/person_info_header.dart';
import 'package:missions/src/widgets/journaling/person_core_stats.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class PersonDetailScreen extends StatefulWidget {
  final String personId;

  const PersonDetailScreen({super.key, required this.personId});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  int _activeTab = 0; // 0: AI DOSSIER, 1: THE MANUAL, 2: BIODATA

  // Controllers for manual fields
  late TextEditingController _nameController;
  late TextEditingController _relationController;
  late TextEditingController _ageController;
  late TextEditingController _genderController;
  
  // New Biodata Controllers
  late TextEditingController _occupationController;
  late TextEditingController _locationController;
  late TextEditingController _birthdayController;
  late TextEditingController _contactController;

  // Planner Controllers
  late TextEditingController _nextMeetController;
  late TextEditingController _manualNotesController;
  final TextEditingController _newIntelBulletController = TextEditingController();

  // Controllers for editing AI generated fields
  bool _isEditingProfile = false;
  late TextEditingController _profileController;

  bool _isEditingComms = false;
  late TextEditingController _commsController;

  bool _isEditingHistory = false;
  late TextEditingController _historyController;

  bool _isInitialized = false;

  @override
  void dispose() {
    if (_isInitialized) {
      _nameController.dispose();
      _relationController.dispose();
      _ageController.dispose();
      _genderController.dispose();
      _occupationController.dispose();
      _locationController.dispose();
      _birthdayController.dispose();
      _contactController.dispose();
      _nextMeetController.dispose();
      _manualNotesController.dispose();
      _profileController.dispose();
      _commsController.dispose();
      _historyController.dispose();
    }
    _newIntelBulletController.dispose();
    super.dispose();
  }

  void _initControllers(PersonInfo person) {
    if (_isInitialized) return;

    _nameController = TextEditingController(text: person.name);
    _relationController = TextEditingController(text: person.relation);
    _ageController = TextEditingController(text: person.manualAge?.toString() ?? "");
    _genderController = TextEditingController(text: person.manualGender ?? "");
    
    // New fields
    _occupationController = TextEditingController(text: person.manualOccupation ?? "");
    _locationController = TextEditingController(text: person.manualLocation ?? "");
    _birthdayController = TextEditingController(text: person.manualBirthday ?? "");
    _contactController = TextEditingController(text: person.manualContact ?? "");

    _nextMeetController = TextEditingController(text: person.manualNextMeetPlan ?? "");
    _manualNotesController = TextEditingController(text: person.manualNotes ?? "");

    // Parse AI details if available
    Map<String, dynamic> parsedDetails = {};
    if (person.details != null && person.details!.isNotEmpty) {
      try {
        parsedDetails = jsonDecode(person.details!);
      } catch (_) {}
    }

    final profile = parsedDetails['psychological_profile'] ?? "";
    _profileController = TextEditingController(text: profile);

    // Tips and history as multiline text for easy editing
    final comms = parsedDetails['communication_tips'] as List? ?? [];
    final commsText = comms.map((c) {
      if (c is Map) {
        final highlight = c['highlight'] as String? ?? '';
        final text = c['text'] as String? ?? '';
        return highlight.isNotEmpty ? "$highlight: $text" : text;
      }
      return c.toString();
    }).join('\n');
    _commsController = TextEditingController(text: commsText);

    final history = parsedDetails['interaction_history'] as List? ?? [];
    final historyText = history.map((h) {
      if (h is Map) {
        final highlight = h['highlight'] as String? ?? '';
        final text = h['text'] as String? ?? '';
        return highlight.isNotEmpty ? "$highlight: $text" : text;
      }
      return h.toString();
    }).join('\n');
    _historyController = TextEditingController(text: historyText);

    _isInitialized = true;
  }

  Future<void> _generateProfile(BuildContext context, AppProvider provider) async {
    try {
      await provider.journalingActions.generatePersonDetails(widget.personId);
      // Reset initialization so controllers reload new data
      setState(() {
        _isInitialized = false;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _saveAIDossierField(AppProvider provider, PersonInfo person, String fieldKey) {
    Map<String, dynamic> parsedDetails = {};
    if (person.details != null && person.details!.isNotEmpty) {
      try {
        parsedDetails = jsonDecode(person.details!);
      } catch (_) {}
    }

    if (fieldKey == 'profile') {
      parsedDetails['psychological_profile'] = _profileController.text.trim();
      setState(() {
        _isEditingProfile = false;
      });
    } else if (fieldKey == 'comms') {
      final lines = _commsController.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final List<Map<String, String>> newList = [];
      for (var l in lines) {
        final idx = l.indexOf(':');
        if (idx != -1) {
          newList.add({
            'highlight': l.substring(0, idx).trim(),
            'text': l.substring(idx + 1).trim(),
          });
        } else {
          newList.add({
            'highlight': '',
            'text': l.trim(),
          });
        }
      }
      parsedDetails['communication_tips'] = newList;
      setState(() {
        _isEditingComms = false;
      });
    } else if (fieldKey == 'history') {
      final lines = _historyController.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final List<Map<String, String>> newList = [];
      for (var l in lines) {
        final idx = l.indexOf(':');
        if (idx != -1) {
          newList.add({
            'highlight': l.substring(0, idx).trim(),
            'text': l.substring(idx + 1).trim(),
          });
        } else {
          newList.add({
            'highlight': '',
            'text': l.trim(),
          });
        }
      }
      parsedDetails['interaction_history'] = newList;
      setState(() {
        _isEditingHistory = false;
      });
    }

    person.details = jsonEncode(parsedDetails);
    person.lastUpdated = DateTime.now();
    provider.updatePersonInfo(person);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("AI Dossier section updated manually.")),
    );
  }

  void _saveManualChanges(AppProvider provider, PersonInfo person) {
    setState(() {
      person.manualNotes = _manualNotesController.text.trim();
      person.manualNextMeetPlan = _nextMeetController.text.trim();
    });

    provider.updatePersonInfo(person);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Manual planner details saved successfully.")),
    );
  }

  void _saveBiodataChanges(AppProvider provider, PersonInfo person) {
    setState(() {
      person.name = _nameController.text.trim();
      person.relation = _relationController.text.trim();
      person.manualAge = int.tryParse(_ageController.text.trim());
      person.manualGender = _genderController.text.trim();
      
      // New Biodata saves
      person.manualOccupation = _occupationController.text.trim();
      person.manualLocation = _locationController.text.trim();
      person.manualBirthday = _birthdayController.text.trim();
      person.manualContact = _contactController.text.trim();
    });

    provider.updatePersonInfo(person);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Dossier Biodata archives updated successfully.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final personIndex = provider.chatbotMemory.people.indexWhere((p) => p.id == widget.personId);

    if (personIndex == -1) {
      return Scaffold(
        backgroundColor: PersonInfoTheme.bgDark,
        appBar: AppBar(title: const Text("NOT FOUND"), backgroundColor: Colors.transparent),
      );
    }

    final person = provider.chatbotMemory.people[personIndex];
    _initControllers(person);

    // Parse the JSON details if available
    Map<String, dynamic>? parsedDetails;
    String? legacyText;

    if (person.details != null && person.details!.isNotEmpty) {
      try {
        parsedDetails = jsonDecode(person.details!);
      } catch (e) {
        legacyText = person.details;
      }
    }

    final int level = parsedDetails?['level'] ?? 1;
    final int xp = parsedDetails?['xp'] ?? 0;
    final String role = parsedDetails?['role'] ?? person.relation;
    final String titleName = person.name;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            colors: [Color(0xFF132030), Color(0xFF000000)],
            radius: 1.0,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  // App Bar override
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: PersonInfoTheme.textWhite),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),

                  // Header details
                  PersonInfoHeader(
                    level: parsedDetails != null ? level : 0,
                    xp: parsedDetails != null ? xp : 0,
                    role: role,
                    titleName: titleName,
                  ),

                  // Cyberpunk 3-Tab Switcher
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF07121d),
                        border: Border.all(color: const Color(0xFF1f2f40)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _activeTab = 0),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _activeTab == 0 ? const Color(0xFF0f2136) : Colors.transparent,
                                  border: _activeTab == 0
                                      ? const Border(bottom: BorderSide(color: PersonInfoTheme.spideyCyan, width: 2))
                                      : null,
                                ),
                                child: Text(
                                  "AI DOSSIER",
                                  style: GoogleFonts.rajdhani(
                                    color: _activeTab == 0 ? PersonInfoTheme.spideyCyan : PersonInfoTheme.textGrey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _activeTab = 1),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _activeTab == 1 ? const Color(0xFF0f2136) : Colors.transparent,
                                  border: _activeTab == 1
                                      ? const Border(bottom: BorderSide(color: PersonInfoTheme.spideyCyan, width: 2))
                                      : null,
                                ),
                                child: Text(
                                  "THE MANUAL",
                                  style: GoogleFonts.rajdhani(
                                    color: _activeTab == 1 ? PersonInfoTheme.spideyCyan : PersonInfoTheme.textGrey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _activeTab = 2),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _activeTab == 2 ? const Color(0xFF0f2136) : Colors.transparent,
                                  border: _activeTab == 2
                                      ? const Border(bottom: BorderSide(color: PersonInfoTheme.spideyCyan, width: 2))
                                      : null,
                                ),
                                child: Text(
                                  "BIODATA",
                                  style: GoogleFonts.rajdhani(
                                    color: _activeTab == 2 ? PersonInfoTheme.spideyCyan : PersonInfoTheme.textGrey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Main UI Content Scrollable
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: PersonInfoTheme.bgPanel,
                        border: Border.all(color: const Color(0xFF1f2f40)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 30,
                          )
                        ],
                      ),
                      child: _buildActiveTabContent(context, provider, person, parsedDetails, legacyText),
                    ),
                  ),

                  // Bottom Regenerate button for AI Tab
                  if (_activeTab == 0 && (parsedDetails != null || legacyText != null))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0, left: 16, right: 16, top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: provider.loadingTaskName != null ? null : () => _generateProfile(context, provider),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PersonInfoTheme.textGrey,
                            side: const BorderSide(color: Color(0xFF1f2f40)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                          ),
                          child: Text(
                            provider.loadingTaskName == "Analyzing Profile..." ? "RECALCULATING..." : "REFRESH AI DOSSIER",
                            style: const TextStyle(fontFamily: AppTheme.fontDisplay, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(BuildContext context, AppProvider provider, PersonInfo person, Map<String, dynamic>? parsedDetails, String? legacyText) {
    switch (_activeTab) {
      case 0:
        return _buildAIDossierTab(context, provider, person, parsedDetails, legacyText);
      case 1:
        return _buildManualTab(context, provider, person);
      case 2:
        return _buildBiodataTab(context, provider, person);
      default:
        return const SizedBox();
    }
  }

  // --- AI DOSSIER TAB ---
  Widget _buildAIDossierTab(BuildContext context, AppProvider provider, PersonInfo person, Map<String, dynamic>? parsedDetails, String? legacyText) {
    if (parsedDetails != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonCoreStats(
              relation: person.relation,
              status: parsedDetails['status'] ?? "Unknown",
              updatedStr: person.lastUpdated != null ? DateFormat('MMM dd, yyyy').format(person.lastUpdated!) : "N/A",
              role: parsedDetails['role'] ?? "Unknown",
            ),
            
            // PSYCHOLOGICAL PROFILE
            _buildDossierSectionHeader("PSYCHOLOGICAL PROFILE", _isEditingProfile, () {
              if (_isEditingProfile) {
                _saveAIDossierField(provider, person, 'profile');
              } else {
                setState(() => _isEditingProfile = true);
              }
            }, () {
              setState(() {
                _isEditingProfile = false;
                _profileController.text = parsedDetails['psychological_profile'] ?? "";
              });
            }),
            
            _isEditingProfile
                ? _buildCyberpunkTextField(_profileController, maxLines: null)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      parsedDetails['psychological_profile'] ?? "No profile details found.",
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.rajdhani(
                        color: PersonInfoTheme.textWhite.withValues(alpha: 0.9),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),

            // INTERACTION HISTORY
            _buildDossierSectionHeader("INTERACTION HISTORY", _isEditingHistory, () {
              if (_isEditingHistory) {
                _saveAIDossierField(provider, person, 'history');
              } else {
                setState(() => _isEditingHistory = true);
              }
            }, () {
              setState(() {
                _isEditingHistory = false;
                final history = parsedDetails['interaction_history'] as List? ?? [];
                _historyController.text = history.map((h) => h is Map ? "${h['highlight'] ?? ''}: ${h['text'] ?? ''}" : h.toString()).join('\n');
              });
            }),

            _isEditingHistory
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Format: 'Highlight Prefix: description text' (one per line)",
                        style: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 6),
                      _buildCyberpunkTextField(_historyController, maxLines: 6),
                    ],
                  )
                : _buildDossierList(parsedDetails['interaction_history'] ?? []),

            const SizedBox(height: 15),

            // COMMUNICATION TIPS
            _buildDossierSectionHeader("COMMUNICATION TIPS", _isEditingComms, () {
              if (_isEditingComms) {
                _saveAIDossierField(provider, person, 'comms');
              } else {
                setState(() => _isEditingComms = true);
              }
            }, () {
              setState(() {
                _isEditingComms = false;
                final comms = parsedDetails['communication_tips'] as List? ?? [];
                _commsController.text = comms.map((c) => c is Map ? "${c['highlight'] ?? ''}: ${c['text'] ?? ''}" : c.toString()).join('\n');
              });
            }),

            _isEditingComms
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Format: 'Highlight Prefix: description text' (one per line)",
                        style: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 6),
                      _buildCyberpunkTextField(_commsController, maxLines: 6),
                    ],
                  )
                : _buildDossierList(parsedDetails['communication_tips'] ?? []),
          ],
        ),
      );
    } else if (legacyText != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          legacyText,
          style: const TextStyle(color: PersonInfoTheme.textWhite, fontSize: 15, height: 1.6),
        ),
      );
    } else {
      // Empty state
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Profile not yet analyzed.\nScan reflections first, then click below to generate intelligence dossier.",
                style: TextStyle(color: PersonInfoTheme.textGrey, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ValorantButton(
                  label: provider.loadingTaskName == "Analyzing Profile..." ? "ANALYZING..." : "ANALYZE REFLECTIONS",
                  isPrimary: false,
                  color: PersonInfoTheme.spideyCyan,
                  onPressed: provider.loadingTaskName != null ? null : () => _generateProfile(context, provider),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDossierSectionHeader(String title, bool isEditing, VoidCallback onEditSave, VoidCallback onCancel) {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 10.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: PersonInfoTheme.spideyRed, width: 3)),
            ),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.rajdhani(
                color: PersonInfoTheme.textGrey,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const Spacer(),
          if (isEditing) ...[
            IconButton(
              icon: const Icon(Icons.close, color: PersonInfoTheme.spideyRed, size: 18),
              onPressed: onCancel,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.greenAccent, size: 18),
              onPressed: onEditSave,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit, color: PersonInfoTheme.spideyCyan, size: 16),
              onPressed: onEditSave,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _buildDossierList(List<dynamic> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 12.0, bottom: 10.0),
        child: Text("None logged.", style: GoogleFonts.rajdhani(color: PersonInfoTheme.textGrey, fontSize: 13)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          String highlight = "";
          String text = "";
          if (item is Map) {
            highlight = item['highlight'] as String? ?? '';
            text = item['text'] as String? ?? '';
          } else {
            text = item.toString();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ">",
                  style: GoogleFonts.rajdhani(
                    color: PersonInfoTheme.spideyCyanDim,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      children: [
                        if (highlight.isNotEmpty)
                          TextSpan(
                            text: "$highlight ",
                            style: const TextStyle(
                              color: PersonInfoTheme.spideyCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        TextSpan(text: text),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- THE MANUAL TAB (PLANNER & NOTES) ---
  Widget _buildManualTab(BuildContext context, AppProvider provider, PersonInfo person) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PLANNER SECTION
          _buildManualSectionHeader("TACTICAL PLANNER"),
          
          _buildManualLabel("NEXT INTEL MEET/COLLABORATION PLAN"),
          _buildCyberpunkTextField(_nextMeetController, maxLines: 2),
          const SizedBox(height: 16),
          
          _buildManualLabel("LAST CONTACT INTEL CHRONICLE"),
          _buildManualIntelList(person, provider),
          const SizedBox(height: 20),

          // NOTES SECTION
          _buildManualSectionHeader("STRATEGIC INTEL NOTES"),
          _buildManualLabel("MANUAL REFLECTIONS & DOSSIER NOTES"),
          _buildCyberpunkTextField(_manualNotesController, maxLines: 5),
          const SizedBox(height: 24),

          // SAVE BUTTON
          SizedBox(
            width: double.infinity,
            child: ValorantButton(
              label: "SAVE MANUAL SYSTEM PLAN",
              isPrimary: true,
              color: PersonInfoTheme.spideyCyan,
              onPressed: () => _saveManualChanges(provider, person),
            ),
          ),
        ],
      ),
    );
  }

  // --- BIODATA TAB (DEDICATED PANEL) ---
  Widget _buildBiodataTab(BuildContext context, AppProvider provider, PersonInfo person) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildManualSectionHeader("ARCHIVE BIODATA SPECIFICATIONS"),
          
          _buildManualLabel("FULL ARCHIVE NAME"),
          _buildCyberpunkTextField(_nameController),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildManualLabel("RELATION TYPE"),
                    _buildCyberpunkTextField(_relationController),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildManualLabel("BIOLOGICAL AGE"),
                    _buildCyberpunkTextField(_ageController, keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildManualLabel("GENDER"),
                    _buildCyberpunkTextField(_genderController),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildManualLabel("OCCUPATION / ROLE"),
                    _buildCyberpunkTextField(_occupationController),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          _buildManualLabel("BASE LOCATION / FIELD DEPOT"),
          _buildCyberpunkTextField(_locationController),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildManualLabel("BIRTHDAY / SPECIAL DATE"),
                    _buildCyberpunkTextField(_birthdayController),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildManualLabel("CONTACT ADDRESS / SOCIAL GRID"),
                    _buildCyberpunkTextField(_contactController),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SAVE BIODATA BUTTON
          SizedBox(
            width: double.infinity,
            child: ValorantButton(
              label: "COMMIT BIODATA ARCHIVES",
              isPrimary: true,
              color: PersonInfoTheme.spideyCyan,
              onPressed: () => _saveBiodataChanges(provider, person),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 15.0),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: GoogleFonts.rajdhani(
              color: PersonInfoTheme.spideyCyan,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [PersonInfoTheme.spideyCyanDim, Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.rajdhani(
          color: PersonInfoTheme.textGrey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCyberpunkTextField(
    TextEditingController controller, {
    int? maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF06101a),
        border: Border.all(color: const Color(0xFF1f2f40)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.rajdhani(
          color: PersonInfoTheme.textWhite,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildManualIntelList(PersonInfo person, AppProvider provider) {
    final intelList = person.manualLastContactIntel ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF06101a),
        border: Border.all(color: const Color(0xFF1f2f40)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (intelList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "No intel logs recorded yet. Add nodes below.",
                style: GoogleFonts.rajdhani(color: PersonInfoTheme.textGrey, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: intelList.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Text(
                        ">",
                        style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyRed, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          intelList[index],
                          style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: PersonInfoTheme.spideyRed, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            intelList.removeAt(index);
                            person.manualLastContactIntel = intelList;
                          });
                          provider.updatePersonInfo(person);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          const Divider(color: Color(0xFF1f2f40), height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newIntelBulletController,
                  style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "ADD MANUAL INTEL MEMORY...",
                    hintStyle: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 11),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_box, color: PersonInfoTheme.spideyCyan, size: 24),
                onPressed: () {
                  final text = _newIntelBulletController.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      intelList.add(text);
                      person.manualLastContactIntel = intelList;
                    });
                    provider.updatePersonInfo(person);
                    _newIntelBulletController.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}