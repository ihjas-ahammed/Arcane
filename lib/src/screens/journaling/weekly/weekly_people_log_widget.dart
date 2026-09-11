import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/journaling/person_detail_screen.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class WeeklyPeopleLogWidget extends StatefulWidget {
  final List<String> sortedCategories;
  final Map<String, List<PersonInfo>> groupedPeople;
  final AppProvider provider;

  const WeeklyPeopleLogWidget({
    super.key,
    required this.sortedCategories,
    required this.groupedPeople,
    required this.provider,
  });

  @override
  State<WeeklyPeopleLogWidget> createState() => _WeeklyPeopleLogWidgetState();
}

class _WeeklyPeopleLogWidgetState extends State<WeeklyPeopleLogWidget> {
  bool _isExpanded = false;
  int _categoryToggleTrigger = 0;
  bool _categoryToggleValue = false;

  void _toggleAllCategories(bool expand) {
    setState(() {
      _isExpanded = true;
      _categoryToggleTrigger++;
      _categoryToggleValue = expand;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalContacts = widget.groupedPeople.values.fold<int>(0, (sum, l) => sum + l.length);
    if (totalContacts == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: JweTheme.bgBase.withOpacity(0.3),
          border: Border.all(color: JweTheme.lineSoft),
        ),
        child: Text(
          'NO REGISTERED CONTACTS LOGGED IN SYSTEM.',
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.4),
        border: Border.all(
          color: _isExpanded ? JweTheme.accentCyan.withOpacity(0.6) : JweTheme.lineSoft,
          width: _isExpanded ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: JweTheme.accentCyan,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(color: JweTheme.accentCyan.withOpacity(0.5), blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOCIAL DOSSIER & ENCOUNTERS',
                          style: GoogleFonts.saira(
                            color: JweTheme.textWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalContacts CONTACT${totalContacts > 1 ? 'S' : ''} ACROSS ${widget.sortedCategories.length} CATEGORIES',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isExpanded) ...[
                    InkWell(
                      onTap: () => _toggleAllCategories(true),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'EXPAND ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentTeal,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _toggleAllCategories(false),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'COLLAPSE ALL',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.accentTeal,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                    color: _isExpanded ? JweTheme.accentCyan : JweTheme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: JweTheme.accentCyan.withOpacity(0.2))),
                color: JweTheme.accentCyan.withOpacity(0.03),
              ),
              child: Column(
                children: widget.sortedCategories.map((category) {
                  final members = widget.groupedPeople[category] ?? [];
                  return PeopleCategoryTile(
                    category: category,
                    members: members,
                    provider: widget.provider,
                    toggleTrigger: _categoryToggleTrigger,
                    toggleValue: _categoryToggleValue,
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class PeopleCategoryTile extends StatefulWidget {
  final String category;
  final List<PersonInfo> members;
  final AppProvider provider;
  final int toggleTrigger;
  final bool toggleValue;

  const PeopleCategoryTile({
    super.key,
    required this.category,
    required this.members,
    required this.provider,
    required this.toggleTrigger,
    required this.toggleValue,
  });

  @override
  State<PeopleCategoryTile> createState() => _PeopleCategoryTileState();
}

class _PeopleCategoryTileState extends State<PeopleCategoryTile> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = false;
  }

  @override
  void didUpdateWidget(covariant PeopleCategoryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.toggleTrigger != oldWidget.toggleTrigger) {
      _isExpanded = widget.toggleValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: JweTheme.bgBase.withOpacity(0.3),
        border: Border(
          left: BorderSide(color: JweTheme.accentCyan.withOpacity(0.6), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(MdiIcons.accountGroupOutline, size: 14, color: JweTheme.accentCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.category} (${widget.members.length})',
                      style: GoogleFonts.jetBrainsMono(
                        color: JweTheme.accentCyan,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                    size: 16,
                    color: JweTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Column(
                children: widget.members.map((p) {
                  return InkWell(
                    onTap: () {
                      final matches = widget.provider.chatbotMemory.people.where(
                          (e) => e.name.toLowerCase().trim() == p.name.toLowerCase().trim());
                      final existing = matches.isNotEmpty ? matches.first : null;
                      if (existing != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: existing.id)));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(MdiIcons.accountOutline, size: 13, color: JweTheme.accentTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name.toUpperCase(),
                                  style: GoogleFonts.saira(
                                    color: JweTheme.textWhite,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                ),
                                if (p.relation.trim().isNotEmpty && p.relation.toLowerCase() != 'acquaintance')
                                  Text(
                                    p.relation.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.textMuted,
                                      fontSize: 8.5,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(MdiIcons.chevronRight, size: 13, color: JweTheme.accentCyan),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
