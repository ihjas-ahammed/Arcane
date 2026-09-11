import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/theme/app_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/widgets/journaling/person_info_header.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/spidey_theme.dart';
import 'people/people.dart';

export 'people/people.dart';

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

  // Biodata Controllers
  late TextEditingController _occupationController;
  late TextEditingController _locationController;
  late TextEditingController _birthdayController;
  late TextEditingController _contactController;

  // Planner Controllers
  late TextEditingController _nextMeetController;
  late TextEditingController _manualNotesController;

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
    }
    super.dispose();
  }

  void _initControllers(PersonInfo person) {
    if (_isInitialized) return;

    _nameController = TextEditingController(text: person.name);
    _relationController = TextEditingController(text: person.relation);
    _ageController = TextEditingController(text: person.manualAge?.toString() ?? "");
    _genderController = TextEditingController(text: person.manualGender ?? "");

    _occupationController = TextEditingController(text: person.manualOccupation ?? "");
    _locationController = TextEditingController(text: person.manualLocation ?? "");
    _birthdayController = TextEditingController(text: person.manualBirthday ?? "");
    _contactController = TextEditingController(text: person.manualContact ?? "");

    _nextMeetController = TextEditingController(text: person.manualNextMeetPlan ?? "");
    _manualNotesController = TextEditingController(text: person.manualNotes ?? "");

    _isInitialized = true;
  }

  Future<void> _generateProfile(BuildContext context, AppProvider provider) async {
    try {
      await provider.journalingActions.generatePersonDetails(widget.personId);
      setState(() {
        _isInitialized = false;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
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
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            colors: [SpideyTheme.bgElevated, SpideyTheme.bgDeep],
            radius: 1.0,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: PersonInfoTheme.textWhite),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.refresh, color: PersonInfoTheme.spideyRed),
                        tooltip: "RESET PERSON DATA",
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: PersonInfoTheme.bgPanel,
                              shape: BeveledRectangleBorder(
                                side: BorderSide(color: PersonInfoTheme.spideyRed, width: 1.5),
                              ),
                              title: Text(
                                "RESET COGNITIVE DATA",
                                style: GoogleFonts.rajdhani(color: PersonInfoTheme.spideyRed, fontWeight: FontWeight.bold),
                              ),
                              content: Text(
                                "Are you sure you want to clear all manual data and AI dossier details for ${person.name}?",
                                style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text("ABORT", style: GoogleFonts.rajdhani(color: PersonInfoTheme.textGrey, fontWeight: FontWeight.bold)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: PersonInfoTheme.spideyRed),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text("RESET", style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            person.relation = 'Acquaintance';
                            person.details = null;
                            person.lastUpdated = null;
                            person.scanRangeStart = null;
                            person.scanRangeEnd = null;
                            person.manualAge = null;
                            person.manualGender = null;
                            person.manualNotes = null;
                            person.manualNextMeetPlan = null;
                            person.manualLastContactIntel = null;
                            person.manualOccupation = null;
                            person.manualLocation = null;
                            person.manualBirthday = null;
                            person.manualContact = null;
                            provider.updatePersonInfo(person);

                            setState(() {
                              _isInitialized = false;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Person dossier data has been reset.")),
                              );
                            }
                          }
                        },
                      ),
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
                        color: ArcSurfaces.deepPanel,
                        border: Border.all(color: ArcStrokes.steel),
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
                                  color: _activeTab == 0 ? ArcSurfaces.deepPanelRaised : Colors.transparent,
                                  border: _activeTab == 0
                                      ? Border(bottom: BorderSide(color: PersonInfoTheme.spideyCyan, width: 2))
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
                                  color: _activeTab == 1 ? ArcSurfaces.deepPanelRaised : Colors.transparent,
                                  border: _activeTab == 1
                                      ? Border(bottom: BorderSide(color: PersonInfoTheme.spideyCyan, width: 2))
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
                                  color: _activeTab == 2 ? ArcSurfaces.deepPanelRaised : Colors.transparent,
                                  border: _activeTab == 2
                                      ? Border(bottom: BorderSide(color: PersonInfoTheme.spideyCyan, width: 2))
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
                        border: Border.all(color: ArcStrokes.steel),
                        boxShadow: [
                          BoxShadow(
                            color: ArcEffects.shadow(1.0),
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
                          onPressed: provider.journalingActions.isPersonUpdating(widget.personId)
                              ? null
                              : () => _generateProfile(context, provider),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PersonInfoTheme.textGrey,
                            side: BorderSide(color: ArcStrokes.steel),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                          ),
                          child: Text(
                            provider.journalingActions.isPersonUpdating(widget.personId) ? "RECALCULATING..." : "REFRESH AI DOSSIER",
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

  Widget _buildActiveTabContent(
    BuildContext context,
    AppProvider provider,
    PersonInfo person,
    Map<String, dynamic>? parsedDetails,
    String? legacyText,
  ) {
    switch (_activeTab) {
      case 0:
        return PersonAIDossierTab(
          person: person,
          provider: provider,
          onRefreshRequested: () {
            setState(() {
              _isInitialized = false;
            });
          },
        );
      case 1:
        return PersonManualTab(
          person: person,
          provider: provider,
          nextMeetController: _nextMeetController,
          manualNotesController: _manualNotesController,
          onSave: () => _saveManualChanges(provider, person),
        );
      case 2:
        return PersonBiodataTab(
          nameController: _nameController,
          relationController: _relationController,
          ageController: _ageController,
          genderController: _genderController,
          occupationController: _occupationController,
          locationController: _locationController,
          birthdayController: _birthdayController,
          contactController: _contactController,
          onSave: () => _saveBiodataChanges(provider, person),
        );
      default:
        return const SizedBox();
    }
  }
}