import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/launcher/launcher_icon.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/notification_app_selector_sheet.dart';
import 'package:missions/src/services/notification_journal_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/global_toast.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:provider/provider.dart';

/// Full notification journal view on the Arcane Launcher's left screen.
/// Displays real-time communication telemetry captured via NotificationListenerService,
/// persists daily logs to the database, and provides app selection controls.
class LauncherNotificationJournal extends StatefulWidget {
  final VoidCallback? onOpenArcane;

  const LauncherNotificationJournal({super.key, this.onOpenArcane});

  @override
  State<LauncherNotificationJournal> createState() => _LauncherNotificationJournalState();
}

class _LauncherNotificationJournalState extends State<LauncherNotificationJournal>
    with WidgetsBindingObserver {
  bool _permissionGranted = false;
  bool _isLoading = true;
  List<NotificationJournalEntry> _notifications = [];
  List<String> _selectedApps = [];
  DateTime _currentDate = DateTime.now();
  String _searchFilter = '';
  final TextEditingController _searchCtrl = TextEditingController();
  StreamSubscription<NotificationJournalEntry>? _streamSub;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_currentDate);
  bool get _isToday {
    final now = DateTime.now();
    return _currentDate.year == now.year &&
        _currentDate.month == now.month &&
        _currentDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _searchFilter) {
        setState(() => _searchFilter = q);
      }
    });

    _refreshAll();
    _subscribeToLiveEvents();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _subscribeToLiveEvents() {
    _streamSub?.cancel();
    _streamSub = NotificationJournalService.instance.onNotification.listen((entry) {
      if (!mounted) return;
      if (entry.dateStr == _dateStr) {
        setState(() {
          _notifications.removeWhere((e) => e.id == entry.id);
          _notifications.insert(0, entry);
        });

        // Sync directly to AppProvider daily database
        final provider = Provider.of<AppProvider>(context, listen: false);
        provider.saveNotificationsForDate(
          _dateStr,
          _notifications.map((e) => e.toMap()).toList(),
        );
      }
    });
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    final granted = await NotificationJournalService.instance.isPermissionGranted();
    final apps = await NotificationJournalService.instance.getSelectedApps();
    final notifs = await NotificationJournalService.instance.getNotifications(_dateStr);

    if (mounted) {
      // If DB has notifications for today, merge or take the most comprehensive set
      final provider = Provider.of<AppProvider>(context, listen: false);
      final dbNotifs = provider.getNotificationsForDate(_dateStr);

      final Map<String, NotificationJournalEntry> unified = {};
      for (final raw in dbNotifs) {
        final e = NotificationJournalEntry.fromMap(raw);
        if (e.id.isNotEmpty) unified[e.id] = e;
      }
      for (final e in notifs) {
        if (e.id.isNotEmpty) unified[e.id] = e;
      }

      final mergedList = unified.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Persist to provider if updated
      if (mergedList.isNotEmpty) {
        provider.saveNotificationsForDate(
          _dateStr,
          mergedList.map((e) => e.toMap()).toList(),
        );
      }

      setState(() {
        _permissionGranted = granted;
        _selectedApps = apps;
        _notifications = mergedList;
        _isLoading = false;
      });
    }
  }

  Future<void> _openPermissionSettings() async {
    await NotificationJournalService.instance.openPermissionSettings();
  }

  Future<void> _openAppSelector() async {
    final updated = await NotificationAppSelectorSheet.show(
      context,
      currentSelected: _selectedApps,
    );
    if (updated != null && mounted) {
      setState(() => _selectedApps = updated);
      _refreshAll();
    }
  }

  Future<void> _deleteEntry(NotificationJournalEntry entry) async {
    await NotificationJournalService.instance.deleteNotification(_dateStr, entry.id);
    if (!mounted) return;
    setState(() {
      _notifications.removeWhere((e) => e.id == entry.id);
    });
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.saveNotificationsForDate(
      _dateStr,
      _notifications.map((e) => e.toMap()).toList(),
    );
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LauncherTheme.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: LauncherTheme.line),
        ),
        title: Text(
          'PURGE NOTIFICATION LOG?',
          style: LauncherTheme.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: LauncherTheme.red,
          ),
        ),
        content: Text(
          'This will permanently delete all logged notifications for $_dateStr from both local memory and daily mission logs.',
          style: LauncherTheme.rajdhani(fontSize: 13, color: LauncherTheme.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: LauncherTheme.rajdhani(color: LauncherTheme.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: LauncherTheme.red),
            child: Text(
              'PURGE',
              style: LauncherTheme.rajdhani(
                fontWeight: FontWeight.w700,
                color: LauncherTheme.isLight ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await NotificationJournalService.instance.clearNotifications(_dateStr);
      if (!mounted) return;
      setState(() => _notifications.clear());
      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.saveNotificationsForDate(_dateStr, []);
      showGlobalToast('Cleared notification log for $_dateStr');
    }
  }

  void _launchAppForEntry(NotificationJournalEntry entry) {
    final app = LauncherService.instance.apps.value.firstWhere(
      (a) => a.package == entry.packageName,
      orElse: () => LauncherApp(package: entry.packageName, activity: '', label: entry.appName),
    );

    LauncherNative.launchApp(entry.packageName, app.activity, user: app.user);
  }

  void _showEntryOptions(NotificationJournalEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: LauncherTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: Icon(MdiIcons.openInApp, color: LauncherTheme.red),
                title: Text('OPEN ${entry.appName.toUpperCase()}',
                    style: LauncherTheme.rajdhani(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _launchAppForEntry(entry);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(MdiIcons.contentCopy, color: LauncherTheme.text),
                title: Text('COPY NOTIFICATION TEXT',
                    style: LauncherTheme.rajdhani(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  final text = '${entry.title}\n${entry.text}'.trim();
                  Clipboard.setData(ClipboardData(text: text));
                  showGlobalToast('Copied to clipboard');
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(MdiIcons.tune, color: LauncherTheme.text),
                title: Text('CONFIGURE JOURNAL APPS',
                    style: LauncherTheme.rajdhani(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAppSelector();
                },
              ),
              Divider(height: 1, color: LauncherTheme.line),
              ListTile(
                dense: true,
                leading: Icon(MdiIcons.trashCanOutline, color: LauncherTheme.red),
                title: Text('DELETE ENTRY',
                    style: LauncherTheme.rajdhani(fontWeight: FontWeight.w700, color: LauncherTheme.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteEntry(entry);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;
    final filtered = _searchFilter.isEmpty
        ? _notifications
        : _notifications.where((e) {
            return e.title.toLowerCase().contains(_searchFilter) ||
                e.text.toLowerCase().contains(_searchFilter) ||
                e.appName.toLowerCase().contains(_searchFilter);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Date & Status Header ─────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, size: 20, color: LauncherTheme.text),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _currentDate = _currentDate.subtract(const Duration(days: 1));
                    });
                    _refreshAll();
                  },
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _currentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _currentDate = picked);
                      _refreshAll();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: LauncherTheme.panel2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: LauncherTheme.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.calendarToday, size: 12, color: LauncherTheme.red),
                        const SizedBox(width: 6),
                        Text(
                          _isToday
                              ? 'TODAY · ${DateFormat('MMM dd').format(_currentDate).toUpperCase()}'
                              : DateFormat('EEE, MMM dd').format(_currentDate).toUpperCase(),
                          style: LauncherTheme.rajdhani(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: LauncherTheme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (!_isToday)
                  IconButton(
                    icon: Icon(Icons.chevron_right, size: 20, color: LauncherTheme.text),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _currentDate = _currentDate.add(const Duration(days: 1));
                      });
                      _refreshAll();
                    },
                  ),
              ],
            ),
            Row(
              children: [
                // App Selector Button
                InkWell(
                  onTap: _openAppSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: LauncherTheme.panel2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: LauncherTheme.line),
                    ),
                    child: Row(
                      children: [
                        Icon(MdiIcons.tuneVariant, size: 13, color: LauncherTheme.red),
                        const SizedBox(width: 5),
                        Text(
                          'APPS (${_selectedApps.length})',
                          style: LauncherTheme.rajdhani(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: LauncherTheme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_notifications.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(MdiIcons.trashCanOutline, size: 16, color: LauncherTheme.muted),
                    tooltip: 'Purge notifications',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _confirmClearAll,
                  ),
                ],
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Permission Warning Card (if not granted) ─────────
        if (!_permissionGranted) ...[
          ClipPath(
            clipper: const Chamfer4CornerClipper(chamfer: 8),
            child: CustomPaint(
              foregroundPainter: TacticalCardBorderPainter(
                themeColor: JweTheme.accentAmber,
                chamfer: 8,
                bracketSize: 8,
                leftBarWidth: 3.0,
                borderColor: JweTheme.accentAmber.withValues(alpha: 0.6),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                color: isLight ? const Color(0xFFFFF8EC) : const Color(0xFF1E1810),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.shieldAlertOutline, size: 18, color: JweTheme.accentAmber),
                        const SizedBox(width: 8),
                        Text(
                          'NOTIFICATION ACCESS REQUIRED',
                          style: LauncherTheme.rajdhani(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: JweTheme.accentAmber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Arcane requires Android Notification Listener permission to record incoming communications from selected apps for your daily AI briefings.',
                      style: LauncherTheme.rajdhani(
                        fontSize: 11.5,
                        color: LauncherTheme.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: _openPermissionSettings,
                        icon: const Icon(Icons.settings, size: 14),
                        label: Text(
                          'ENABLE NOTIFICATION ACCESS',
                          style: LauncherTheme.rajdhani(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: JweTheme.accentAmber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Search & Filter Input ────────────────────────────
        if (_notifications.length > 3 || _searchFilter.isNotEmpty) ...[
          TextField(
            controller: _searchCtrl,
            style: LauncherTheme.rajdhani(fontSize: 13, color: LauncherTheme.text),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: LauncherTheme.panel2,
              hintText: 'Search logged communications...',
              hintStyle: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted),
              prefixIcon: Icon(MdiIcons.magnify, size: 16, color: LauncherTheme.muted),
              suffixIcon: _searchFilter.isNotEmpty
                  ? IconButton(
                      icon: Icon(MdiIcons.close, size: 14, color: LauncherTheme.muted),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          const SizedBox(height: 10),
        ],

        // ── Telemetry Summary Bar ────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: LauncherTheme.panel2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: LauncherTheme.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LOGGED: ${_notifications.length} COMMUNICATIONS',
                style: LauncherTheme.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: LauncherTheme.text,
                ),
              ),
              Text(
                'INGESTED TO AI BRIEFING',
                style: LauncherTheme.rajdhani(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: JweTheme.accentCyan,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Notifications Feed ───────────────────────────────
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: LauncherTheme.red),
              ),
            ),
          )
        else if (filtered.isEmpty)
          ClipPath(
            clipper: const Chamfer4CornerClipper(chamfer: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              color: LauncherTheme.panel,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(MdiIcons.bellSleepOutline, size: 36, color: LauncherTheme.muted),
                  const SizedBox(height: 10),
                  Text(
                    _searchFilter.isNotEmpty
                        ? 'NO MATCHING NOTIFICATIONS'
                        : 'NO NOTIFICATIONS RECORDED FOR $_dateStr',
                    style: LauncherTheme.rajdhani(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: LauncherTheme.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Notifications from your monitored communication apps will be archived here and synthesized in your daily AI tactical briefings.',
                    style: LauncherTheme.rajdhani(
                      fontSize: 11,
                      color: LauncherTheme.muted,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: _openAppSelector,
                      icon: Icon(MdiIcons.tune, size: 14, color: LauncherTheme.red),
                      label: Text(
                        'CONFIGURE MONITORED APPS',
                        style: LauncherTheme.rajdhani(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: LauncherTheme.red,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: LauncherTheme.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final entry = filtered[i];
              return _buildNotificationCard(entry);
            },
          ),
      ],
    );
  }

  Widget _buildNotificationCard(NotificationJournalEntry entry) {
    final isLight = LauncherTheme.isLight;
    final allApps = LauncherService.instance.apps.value;
    final app = allApps.firstWhere(
      (a) => a.package == entry.packageName,
      orElse: () => LauncherApp(
        package: entry.packageName,
        activity: '',
        label: entry.appName.isNotEmpty ? entry.appName : entry.packageName,
      ),
    );

    return InkWell(
      onTap: () => _launchAppForEntry(entry),
      onLongPress: () => _showEntryOptions(entry),
      child: ClipPath(
        clipper: const Chamfer4CornerClipper(chamfer: 6),
        child: CustomPaint(
          foregroundPainter: TacticalCardBorderPainter(
            themeColor: LauncherTheme.red,
            chamfer: 6,
            bracketSize: 6,
            leftBarWidth: 2.5,
            borderColor: LauncherTheme.line,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: LauncherTheme.panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Row
                Row(
                  children: [
                    if (app.activity.isNotEmpty)
                      LauncherAppIcon(app: app, size: 20)
                    else
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: LauncherTheme.panel2,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: LauncherTheme.line),
                        ),
                        child: Icon(MdiIcons.bellOutline, size: 12, color: LauncherTheme.red),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.appName.toUpperCase(),
                        style: LauncherTheme.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: LauncherTheme.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      entry.timeStr,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: LauncherTheme.muted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _deleteEntry(entry),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 14, color: LauncherTheme.muted),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                // Title (Sender / Chat Name)
                if (entry.title.isNotEmpty)
                  Text(
                    entry.title,
                    style: LauncherTheme.rajdhani(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: LauncherTheme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                // Message Text Body
                if (entry.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.text,
                    style: LauncherTheme.rajdhani(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isLight ? const Color(0xFF3B362F) : const Color(0xFFC0C5CF),
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // SubText if present
                if (entry.subText.isNotEmpty &&
                    entry.subText.toLowerCase() != entry.appName.toLowerCase() &&
                    entry.subText.toLowerCase() != entry.title.toLowerCase()) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: LauncherTheme.panel2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.subText,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: LauncherTheme.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact tactical preview card for the ALL feed of Arcane Deck.
class LauncherNotificationDeckCard extends StatelessWidget {
  final VoidCallback onOpenNotificationsTab;

  const LauncherNotificationDeckCard({super.key, required this.onOpenNotificationsTab});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dayNotifs = provider.getNotificationsForDate(todayStr);

    return InkWell(
      onTap: onOpenNotificationsTab,
      child: ClipPath(
        clipper: const Chamfer4CornerClipper(chamfer: 8),
        child: CustomPaint(
          foregroundPainter: TacticalCardBorderPainter(
            themeColor: LauncherTheme.red,
            chamfer: 8,
            bracketSize: 8,
            leftBarWidth: 3.0,
            borderColor: LauncherTheme.redSoft,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            color: LauncherTheme.panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(MdiIcons.messageFlashOutline, size: 16, color: LauncherTheme.red),
                        const SizedBox(width: 8),
                        Text(
                          'COMMUNICATIONS JOURNAL',
                          style: LauncherTheme.rajdhani(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: LauncherTheme.text,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: dayNotifs.isNotEmpty
                            ? LauncherTheme.red.withValues(alpha: 0.15)
                            : LauncherTheme.panel2,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: dayNotifs.isNotEmpty ? LauncherTheme.red : LauncherTheme.line,
                        ),
                      ),
                      child: Text(
                        '${dayNotifs.length} TODAY',
                        style: LauncherTheme.rajdhani(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: dayNotifs.isNotEmpty ? LauncherTheme.red : LauncherTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (dayNotifs.isEmpty)
                  Text(
                    'No communication telemetry logged yet today. Tapping will configure monitored apps.',
                    style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted),
                  )
                else ...[
                  Text(
                    '${dayNotifs.first['appName']?.toString().toUpperCase() ?? 'MSG'} · ${dayNotifs.first['title'] ?? ''}',
                    style: LauncherTheme.rajdhani(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: LauncherTheme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayNotifs.first['text']?.toString() ?? '',
                    style: LauncherTheme.rajdhani(
                      fontSize: 12,
                      color: LauncherTheme.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'OPEN JOURNAL',
                      style: LauncherTheme.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: LauncherTheme.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 13, color: LauncherTheme.red),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
