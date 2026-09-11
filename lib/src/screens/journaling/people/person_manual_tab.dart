import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/arc/arc_theme.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'people_common_widgets.dart';

class PersonManualTab extends StatefulWidget {
  final PersonInfo person;
  final AppProvider provider;
  final TextEditingController nextMeetController;
  final TextEditingController manualNotesController;
  final VoidCallback onSave;

  const PersonManualTab({
    super.key,
    required this.person,
    required this.provider,
    required this.nextMeetController,
    required this.manualNotesController,
    required this.onSave,
  });

  @override
  State<PersonManualTab> createState() => _PersonManualTabState();
}

class _PersonManualTabState extends State<PersonManualTab> {
  final TextEditingController _newIntelBulletController = TextEditingController();

  @override
  void dispose() {
    _newIntelBulletController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PLANNER SECTION
          const PersonSectionHeader(text: "TACTICAL PLANNER"),

          const PersonFieldLabel(label: "NEXT INTEL MEET/COLLABORATION PLAN"),
          CyberpunkTextField(controller: widget.nextMeetController, maxLines: 2),
          const SizedBox(height: 16),

          const PersonFieldLabel(label: "LAST CONTACT INTEL CHRONICLE"),
          _buildManualIntelList(),
          const SizedBox(height: 20),

          // NOTES SECTION
          const PersonSectionHeader(text: "STRATEGIC INTEL NOTES"),
          const PersonFieldLabel(label: "MANUAL REFLECTIONS & DOSSIER NOTES"),
          CyberpunkTextField(controller: widget.manualNotesController, maxLines: 5),
          const SizedBox(height: 24),

          // SAVE BUTTON
          SizedBox(
            width: double.infinity,
            child: ValorantButton(
              label: "SAVE MANUAL SYSTEM PLAN",
              isPrimary: true,
              color: PersonInfoTheme.spideyCyan,
              onPressed: widget.onSave,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualIntelList() {
    final intelList = widget.person.manualLastContactIntel ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArcSurfaces.deepPanel,
        border: Border.all(color: ArcStrokes.steel),
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
                        icon: Icon(Icons.delete_outline, color: PersonInfoTheme.spideyRed, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            intelList.removeAt(index);
                            widget.person.manualLastContactIntel = intelList;
                          });
                          widget.provider.updatePersonInfo(widget.person);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          Divider(color: ArcStrokes.steel, height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newIntelBulletController,
                  style: GoogleFonts.rajdhani(color: PersonInfoTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "ADD MANUAL INTEL MEMORY...",
                    hintStyle: TextStyle(color: PersonInfoTheme.textGrey, fontSize: 11),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_box, color: PersonInfoTheme.spideyCyan, size: 24),
                onPressed: () {
                  final text = _newIntelBulletController.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      intelList.add(text);
                      widget.person.manualLastContactIntel = intelList;
                    });
                    widget.provider.updatePersonInfo(widget.person);
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
