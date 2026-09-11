import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/widgets/journaling/person_core_stats.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'people_common_widgets.dart';

class PersonAIDossierTab extends StatefulWidget {
  final PersonInfo person;
  final AppProvider provider;
  final VoidCallback onRefreshRequested;

  const PersonAIDossierTab({
    super.key,
    required this.person,
    required this.provider,
    required this.onRefreshRequested,
  });

  @override
  State<PersonAIDossierTab> createState() => _PersonAIDossierTabState();
}

class _PersonAIDossierTabState extends State<PersonAIDossierTab> {
  bool _isEditingProfile = false;
  late TextEditingController _profileController;

  bool _isEditingComms = false;
  late TextEditingController _commsController;

  bool _isEditingHistory = false;
  late TextEditingController _historyController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant PersonAIDossierTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.details != widget.person.details) {
      _initControllers();
    }
  }

  void _initControllers() {
    Map<String, dynamic> parsedDetails = {};
    if (widget.person.details != null && widget.person.details!.isNotEmpty) {
      try {
        parsedDetails = jsonDecode(widget.person.details!);
      } catch (_) {}
    }

    final profile = parsedDetails['psychological_profile'] ?? "";
    _profileController = TextEditingController(text: profile);

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
  }

  @override
  void dispose() {
    _profileController.dispose();
    _commsController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  void _saveAIDossierField(String fieldKey) {
    Map<String, dynamic> parsedDetails = {};
    if (widget.person.details != null && widget.person.details!.isNotEmpty) {
      try {
        parsedDetails = jsonDecode(widget.person.details!);
      } catch (_) {}
    }

    if (fieldKey == 'profile') {
      parsedDetails['psychological_profile'] = _profileController.text.trim();
      setState(() => _isEditingProfile = false);
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
      setState(() => _isEditingComms = false);
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
      setState(() => _isEditingHistory = false);
    }

    widget.person.details = jsonEncode(parsedDetails);
    widget.person.lastUpdated = DateTime.now();
    widget.provider.updatePersonInfo(widget.person);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("AI Dossier section updated manually.")),
    );
  }

  Future<void> _generateProfile() async {
    try {
      await widget.provider.journalingActions.generatePersonDetails(widget.person.id);
      widget.onRefreshRequested();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? parsedDetails;
    String? legacyText;

    if (widget.person.details != null && widget.person.details!.isNotEmpty) {
      try {
        parsedDetails = jsonDecode(widget.person.details!);
      } catch (e) {
        legacyText = widget.person.details;
      }
    }

    if (parsedDetails != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonCoreStats(
              relation: widget.person.relation,
              status: parsedDetails['status'] ?? "Unknown",
              updatedStr: widget.person.lastUpdated != null
                  ? DateFormat('MMM dd, yyyy').format(widget.person.lastUpdated!)
                  : "N/A",
              role: parsedDetails['role'] ?? "Unknown",
            ),

            // PSYCHOLOGICAL PROFILE
            _buildDossierSectionHeader("PSYCHOLOGICAL PROFILE", _isEditingProfile, () {
              if (_isEditingProfile) {
                _saveAIDossierField('profile');
              } else {
                setState(() => _isEditingProfile = true);
              }
            }, () {
              setState(() {
                _isEditingProfile = false;
                _profileController.text = parsedDetails?['psychological_profile'] ?? "";
              });
            }),

            _isEditingProfile
                ? CyberpunkTextField(controller: _profileController, maxLines: null)
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
                _saveAIDossierField('history');
              } else {
                setState(() => _isEditingHistory = true);
              }
            }, () {
              setState(() {
                _isEditingHistory = false;
                final history = parsedDetails?['interaction_history'] as List? ?? [];
                _historyController.text = history
                    .map((h) => h is Map ? "${h['highlight'] ?? ''}: ${h['text'] ?? ''}" : h.toString())
                    .join('\n');
              });
            }),

            _isEditingHistory
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Format: 'Highlight Prefix: description text' (one per line)",
                        style: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 6),
                      CyberpunkTextField(controller: _historyController, maxLines: 6),
                    ],
                  )
                : _buildDossierList(parsedDetails['interaction_history'] ?? []),

            const SizedBox(height: 15),

            // COMMUNICATION TIPS
            _buildDossierSectionHeader("COMMUNICATION TIPS", _isEditingComms, () {
              if (_isEditingComms) {
                _saveAIDossierField('comms');
              } else {
                setState(() => _isEditingComms = true);
              }
            }, () {
              setState(() {
                _isEditingComms = false;
                final comms = parsedDetails?['communication_tips'] as List? ?? [];
                _commsController.text = comms
                    .map((c) => c is Map ? "${c['highlight'] ?? ''}: ${c['text'] ?? ''}" : c.toString())
                    .join('\n');
              });
            }),

            _isEditingComms
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Format: 'Highlight Prefix: description text' (one per line)",
                        style: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 6),
                      CyberpunkTextField(controller: _commsController, maxLines: 6),
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
          style: TextStyle(color: PersonInfoTheme.textWhite, fontSize: 15, height: 1.6),
        ),
      );
    } else {
      // Empty state
      final isUpdating = widget.provider.journalingActions.isPersonUpdating(widget.person.id);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Profile not yet analyzed.\nScan reflections first, then click below to generate intelligence dossier.",
                style: TextStyle(color: PersonInfoTheme.textGrey, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ValorantButton(
                  label: isUpdating ? "ANALYZING..." : "ANALYZE REFLECTIONS",
                  isPrimary: false,
                  color: PersonInfoTheme.spideyCyan,
                  onPressed: isUpdating ? null : () => _generateProfile(),
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
            decoration: BoxDecoration(
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
              icon: Icon(Icons.close, color: PersonInfoTheme.spideyRed, size: 18),
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
              icon: Icon(Icons.edit, color: PersonInfoTheme.spideyCyan, size: 16),
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
                        color: ArcContent.dossierBody,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      children: [
                        if (highlight.isNotEmpty)
                          TextSpan(
                            text: "$highlight ",
                            style: TextStyle(
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
}
