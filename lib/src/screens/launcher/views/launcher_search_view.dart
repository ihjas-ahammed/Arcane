import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_swipe_detector.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';

class LauncherSearchView extends StatefulWidget {
  final List<LauncherAppItem> apps;
  final VoidCallback onBack;
  final Function(LauncherAppItem app) onLaunchApp;
  final Function(String action) onAction;
  final VoidCallback onHome;

  const LauncherSearchView({
    super.key,
    required this.apps,
    required this.onBack,
    required this.onLaunchApp,
    required this.onAction,
    required this.onHome,
  });

  @override
  State<LauncherSearchView> createState() => _LauncherSearchViewState();
}

class _LauncherSearchViewState extends State<LauncherSearchView> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, int> _alphabetIndices = {};
  String _query = '';

  static const List<String> _letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() {
      setState(() => _query = _queryController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLetter(String letter) {
    final idx = _alphabetIndices[letter];
    if (idx != null && _scrollController.hasClients) {
      final target = (idx * 52.0).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;

    // Filter apps by query and sort alphabetically
    final filtered = widget.apps.where((app) {
      if (_query.isEmpty) return true;
      return app.label.toLowerCase().contains(_query);
    }).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    // Cache alphabet indices for quick jumping
    _alphabetIndices.clear();
    for (int i = 0; i < filtered.length; i++) {
      final initial = filtered[i].label.isNotEmpty ? filtered[i].label[0].toUpperCase() : '';
      if (initial.isNotEmpty && !_alphabetIndices.containsKey(initial)) {
        _alphabetIndices[initial] = i;
      }
    }

    return LauncherSwipeDetector(
      behavior: HitTestBehavior.opaque,
      onSwipeDown: widget.onHome,
      onSwipeRight: widget.onBack,
      child: Column(
      children: [
        // ── Search Top ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 22, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: Icon(MdiIcons.arrowLeft, color: LauncherTheme.text, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: isLight ? const Color(0xFFF3EFE7) : const Color(0xFF0B0C10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LauncherTheme.red, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: LauncherTheme.redDim,
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(MdiIcons.magnify, size: 22, color: LauncherTheme.text),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          autofocus: false,
                          style: LauncherTheme.rajdhani(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            color: LauncherTheme.text,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search apps...',
                            hintStyle: LauncherTheme.rajdhani(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: LauncherTheme.muted,
                            ),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, size: 18, color: LauncherTheme.muted),
                          onPressed: () => _queryController.clear(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── RECENT Section (Visible when not actively filtering) ──
        if (_query.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'RECENT',
                style: LauncherTheme.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: LauncherTheme.muted,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: () {
                  final recentList = LauncherService.instance.getRecentApps(limit: 5);
                  return recentList.map((app) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _buildRecentButton(
                        app.icon,
                        app.label,
                        () => widget.onLaunchApp(app),
                      ),
                    );
                  }).toList();
                }(),
              ),
            ),
          ),
        ],

        // ── ALL APPS Label ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ALL APPS',
              style: LauncherTheme.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: LauncherTheme.muted,
              ),
            ),
          ),
        ),

        // ── Apps List + A-Z Fast Rail ─────────────────────────────
        Expanded(
          child: Row(
            children: [
              // Scrollable Apps List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No apps found',
                          style: LauncherTheme.rajdhani(
                            fontSize: 14,
                            letterSpacing: 1,
                            color: LauncherTheme.muted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(22, 0, 8, 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final app = filtered[index];
                          return InkWell(
                            onTap: () => widget.onLaunchApp(app),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isLight
                                        ? const Color(0x10000000)
                                        : const Color(0x0AFFFFFF),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: app.isHot
                                          ? LauncherTheme.red
                                          : LauncherTheme.panel,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        app.icon,
                                        size: 18,
                                        color: app.isHot ? Colors.white : LauncherTheme.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Text(
                                      app.label,
                                      style: LauncherTheme.rajdhani(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                        color: LauncherTheme.text,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    MdiIcons.chevronRight,
                                    size: 18,
                                    color: LauncherTheme.muted,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // A-Z Alphabet Fast Scroll Column
              Container(
                width: 26,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final letter in _letters)
                      GestureDetector(
                        onTap: () => _scrollToLetter(letter),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: _alphabetIndices.containsKey(letter)
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: _alphabetIndices.containsKey(letter)
                                ? LauncherTheme.red
                                : LauncherTheme.muted.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Home Indicator ─────────────────────────────────────────
        GestureDetector(
          onTap: widget.onHome,
          child: Container(
            width: 120,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: LauncherTheme.text.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildRecentButton(IconData icon, String label, VoidCallback onTap) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: LauncherTheme.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LauncherTheme.line),
          ),
          child: Center(
            child: Icon(icon, size: 24, color: LauncherTheme.text),
          ),
        ),
      ),
    );
  }
}
