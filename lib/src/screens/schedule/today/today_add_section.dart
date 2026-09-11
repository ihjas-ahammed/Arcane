import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/theme/app_theme.dart';

class AddSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Widget child;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const AddSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.searchController,
    required this.onSearchChanged,
    required this.child,
    required this.activeTab,
    required this.onTabChanged,
  });

  static const double _headerHeight = 53;
  static const double _expandedHeight = 340;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: expanded ? _expandedHeight : _headerHeight,
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border(top: BorderSide(color: AppTheme.fhBorderColor)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(MdiIcons.plusBoxOutline,
                        size: 18, color: AppTheme.fhAccentTeal),
                    const SizedBox(width: 8),
                    Text('ADD MISSIONS',
                        style: GoogleFonts.rajdhani(
                            color: AppTheme.fhAccentTeal,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 14)),
                    const Spacer(),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: Icon(
                        Icons.expand_less,
                        color: AppTheme.fhTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            // Fixed-height content clipped while the container grows, so the
            // expand animation never triggers a transient RenderFlex overflow.
            Expanded(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: _expandedHeight - _headerHeight,
                  maxHeight: _expandedHeight - _headerHeight,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PlannerTabButton(
                              title: 'MISSIONS',
                              isActive: activeTab == 0,
                              onTap: () => onTabChanged(0),
                            ),
                            const SizedBox(width: 24),
                            PlannerTabButton(
                              title: 'ROUTINES',
                              isActive: activeTab == 1,
                              onTap: () => onTabChanged(1),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          style: TextStyle(color: AppTheme.fhTextPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: activeTab == 0 ? 'Search missions…' : 'Search routines…',
                            hintStyle: TextStyle(color: AppTheme.fhTextDisabled, fontSize: 13),
                            prefixIcon: Icon(Icons.search,
                                size: 16, color: AppTheme.fhTextSecondary),
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 32, minHeight: 32),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.fhBorderColor)),
                            focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.fhAccentTeal)),
                          ),
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ).animate().fadeIn(duration: 200.ms, delay: 60.ms),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PlannerTabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const PlannerTabButton({
    super.key,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: isActive ? AppTheme.fhAccentTeal : AppTheme.fhTextDisabled,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 40,
            color: isActive ? AppTheme.fhAccentTeal : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
