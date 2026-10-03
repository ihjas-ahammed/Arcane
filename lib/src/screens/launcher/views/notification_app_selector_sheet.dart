import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_icon.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/services/notification_journal_service.dart';
import 'package:missions/src/utils/global_toast.dart';

/// Modal bottom sheet allowing the operator to select which installed apps should be
/// monitored and journaled into daily briefings and notification history.
class NotificationAppSelectorSheet extends StatefulWidget {
  final List<String> initialSelected;

  const NotificationAppSelectorSheet({
    super.key,
    required this.initialSelected,
  });

  static Future<List<String>?> show(BuildContext context, {List<String>? currentSelected}) async {
    final selected = currentSelected ?? await NotificationJournalService.instance.getSelectedApps();
    if (!context.mounted) return null;
    return showModalBottomSheet<List<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: LauncherTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: NotificationAppSelectorSheet(initialSelected: selected),
        ),
      ),
    );
  }

  @override
  State<NotificationAppSelectorSheet> createState() => _NotificationAppSelectorSheetState();
}

class _NotificationAppSelectorSheetState extends State<NotificationAppSelectorSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedPackages = <String>{};
  String _filter = '';
  bool _saving = false;

  static const Set<String> _kKnownMessagingKeywords = {
    'whatsapp',
    'telegram',
    'signal',
    'discord',
    'slack',
    'message',
    'messaging',
    'sms',
    'mail',
    'gmail',
    'outlook',
    'instagram',
    'chat',
    'teams',
    'viber',
    'wechat',
  };

  @override
  void initState() {
    super.initState();
    _selectedPackages.addAll(widget.initialSelected);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _filter) setState(() => _filter = q);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LauncherApp> get _allApps {
    final list = LauncherService.instance.apps.value
        .where((a) => a.kind == LauncherAppKind.app && a.package.isNotEmpty)
        .toList();
    list.sort((a, b) {
      final aSelected = _selectedPackages.contains(a.package);
      final bSelected = _selectedPackages.contains(b.package);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return list;
  }

  void _selectMessagingPreset() {
    final apps = _allApps;
    final toAdd = <String>[];
    for (final app in apps) {
      final pkg = app.package.toLowerCase();
      final lbl = app.label.toLowerCase();
      final matches = _kKnownMessagingKeywords.any((kw) => pkg.contains(kw) || lbl.contains(kw));
      if (matches) {
        toAdd.add(app.package);
      }
    }
    setState(() {
      _selectedPackages.addAll(toAdd);
    });
    showGlobalToast('Added ${toAdd.length} communication apps to monitoring');
  }

  void _toggleSelectAll() {
    final apps = _allApps;
    setState(() {
      if (_selectedPackages.length >= apps.length) {
        _selectedPackages.clear();
      } else {
        _selectedPackages.addAll(apps.map((a) => a.package));
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final list = _selectedPackages.toList();
    await NotificationJournalService.instance.setSelectedApps(list);
    if (!mounted) return;
    showGlobalToast('Updated journal: monitoring ${list.length} apps');
    Navigator.of(context).pop(list);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;
    final allApps = _allApps;
    final filtered = _filter.isEmpty
        ? allApps
        : allApps.where((a) {
            return a.label.toLowerCase().contains(_filter) ||
                a.package.toLowerCase().contains(_filter);
          }).toList();

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JOURNAL APPS',
                      style: LauncherTheme.rajdhani(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: LauncherTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SELECT APPS TO CAPTURE FOR DAILY BRIEFINGS & HISTORY',
                      style: LauncherTheme.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: LauncherTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedPackages.isNotEmpty
                      ? LauncherTheme.red.withValues(alpha: 0.15)
                      : (isLight ? const Color(0xFFE2DDD5) : const Color(0xFF1E222A)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _selectedPackages.isNotEmpty ? LauncherTheme.red : LauncherTheme.line,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_selectedPackages.length} SELECTED',
                  style: LauncherTheme.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: _selectedPackages.isNotEmpty ? LauncherTheme.red : LauncherTheme.muted,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Search & Filter Controls ─────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _searchCtrl,
            style: LauncherTheme.rajdhani(fontSize: 14, color: LauncherTheme.text),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: LauncherTheme.panel2,
              hintText: 'Search installed applications...',
              hintStyle: LauncherTheme.rajdhani(fontSize: 13, color: LauncherTheme.muted),
              prefixIcon: Icon(MdiIcons.magnify, size: 18, color: LauncherTheme.muted),
              suffixIcon: _filter.isNotEmpty
                  ? IconButton(
                      icon: Icon(MdiIcons.close, size: 16, color: LauncherTheme.muted),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: LauncherTheme.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: LauncherTheme.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: LauncherTheme.red),
              ),
            ),
          ),
        ),

        // ── Preset Filter Chips ──────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: Icon(MdiIcons.chatProcessingOutline, size: 14, color: LauncherTheme.red),
                  label: Text('MESSAGING PRESET', style: LauncherTheme.rajdhani(fontSize: 11, fontWeight: FontWeight.w700)),
                  backgroundColor: LauncherTheme.panel2,
                  side: BorderSide(color: LauncherTheme.line),
                  onPressed: _selectMessagingPreset,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(MdiIcons.checkboxMultipleMarkedOutline, size: 14, color: LauncherTheme.text),
                  label: Text(
                    _selectedPackages.length >= allApps.length ? 'DESELECT ALL' : 'SELECT ALL',
                    style: LauncherTheme.rajdhani(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: LauncherTheme.panel2,
                  side: BorderSide(color: LauncherTheme.line),
                  onPressed: _toggleSelectAll,
                ),
                if (_selectedPackages.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: Icon(MdiIcons.closeCircleOutline, size: 14, color: LauncherTheme.muted),
                    label: Text('CLEAR', style: LauncherTheme.rajdhani(fontSize: 11, fontWeight: FontWeight.w700, color: LauncherTheme.muted)),
                    backgroundColor: LauncherTheme.panel2,
                    side: BorderSide(color: LauncherTheme.line),
                    onPressed: () => setState(() => _selectedPackages.clear()),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 4),
        Divider(height: 1, color: LauncherTheme.line),

        // ── Apps List ────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MdiIcons.applicationOutline, size: 36, color: LauncherTheme.muted),
                      const SizedBox(height: 8),
                      Text(
                        'NO MATCHING APPS FOUND',
                        style: LauncherTheme.rajdhani(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: LauncherTheme.muted,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: LauncherTheme.line.withValues(alpha: 0.5)),
                  itemBuilder: (ctx, i) {
                    final app = filtered[i];
                    final isChecked = _selectedPackages.contains(app.package);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _selectedPackages.remove(app.package);
                          } else {
                            _selectedPackages.add(app.package);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            LauncherAppIcon(app: app, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.label,
                                    style: LauncherTheme.rajdhani(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: LauncherTheme.text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    app.package,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: LauncherTheme.muted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: isChecked,
                              activeColor: LauncherTheme.red,
                              checkColor: isLight ? Colors.black : Colors.white,
                              side: BorderSide(color: LauncherTheme.line, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPackages.add(app.package);
                                  } else {
                                    _selectedPackages.remove(app.package);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // ── Sticky Save Footer ───────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: LauncherTheme.panel,
            border: Border(top: BorderSide(color: LauncherTheme.line)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isLight ? Colors.black : Colors.white,
                      ),
                    )
                  : Icon(Icons.check, size: 18, color: isLight ? Colors.black : Colors.white),
              label: Text(
                'APPLY MONITORING LIST (${_selectedPackages.length} APPS)',
                style: LauncherTheme.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: isLight ? Colors.black : Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: LauncherTheme.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
