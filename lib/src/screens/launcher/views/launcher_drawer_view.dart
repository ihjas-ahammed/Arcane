import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_icon.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';
import 'package:missions/src/screens/launcher/launcher_service.dart';
import 'package:missions/src/screens/launcher/launcher_theme.dart';
import 'package:missions/src/screens/launcher/views/launcher_items.dart';
import 'package:missions/src/screens/launcher/views/launcher_sheets.dart';

/// All-apps drawer with search on top. Pull down at the top of the list to close.
class LauncherDrawerView extends StatefulWidget {
  final ValueChanged<LauncherApp> onLaunch;
  final VoidCallback onClose;

  /// Finger moved down by `delta` px while closing by drag.
  final ValueChanged<double> onDragClose;

  /// Drag released with downward `velocity` (px/s).
  final ValueChanged<double> onDragCloseEnd;

  const LauncherDrawerView({
    super.key,
    required this.onLaunch,
    required this.onClose,
    required this.onDragClose,
    required this.onDragCloseEnd,
  });

  @override
  State<LauncherDrawerView> createState() => LauncherDrawerViewState();
}

class LauncherDrawerViewState extends State<LauncherDrawerView> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();
  bool _dragClosing = false;

  List<LauncherContact> _contacts = const [];
  bool _hasContactsPermission = true;
  bool _isSearchingContacts = false;
  Timer? _contactsDebounce;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQuery);
    _checkContactsPermission();
  }

  Future<void> _checkContactsPermission() async {
    final hasPerm = await LauncherNative.hasContactsPermission();
    if (mounted) setState(() => _hasContactsPermission = hasPerm);
  }

  @override
  void dispose() {
    _contactsDebounce?.cancel();
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _lastQuery = '';
  void _onQuery() {
    final text = _query.text;
    if (text == _lastQuery) return;
    _lastQuery = text;
    setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);

    _contactsDebounce?.cancel();
    final q = text.trim();
    if (q.isEmpty) {
      if (_contacts.isNotEmpty) {
        setState(() => _contacts = const []);
      }
      return;
    }

    _contactsDebounce = Timer(const Duration(milliseconds: 180), () {
      _performContactSearch(q);
    });
  }

  Future<void> _performContactSearch(String q) async {
    if (!_hasContactsPermission) return;
    setState(() => _isSearchingContacts = true);
    try {
      final results = await LauncherNative.searchContacts(q, limit: 12);
      if (mounted && _query.text.trim() == q) {
        setState(() {
          _contacts = results;
          _isSearchingContacts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingContacts = false);
    }
  }

  Future<void> _requestContactsAccess() async {
    final granted = await LauncherNative.requestContactsPermission();
    if (mounted) {
      setState(() => _hasContactsPermission = granted);
      final q = _query.text.trim();
      if (granted && q.isNotEmpty) {
        _performContactSearch(q);
      }
    }
  }

  bool _looksLikePhoneNumber(String q) {
    final digitsOnly = q.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.length >= 3 && RegExp(r'^[\d\s\+\-\(\)]+$').hasMatch(q);
  }

  void focusSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void reset() {
    _focus.unfocus();
    if (_query.text.isNotEmpty) _query.clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _submit(List<LauncherApp> results) {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    if (results.isNotEmpty) {
      widget.onLaunch(results.first);
    } else if (_contacts.isNotEmpty) {
      LauncherNative.callNumber(_contacts.first.primaryPhone);
    } else if (_looksLikePhoneNumber(q)) {
      LauncherNative.callNumber(q);
    } else {
      LauncherNative.openWebSearch(q);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
      if (!_dragClosing) {
        _dragClosing = true;
        _focus.unfocus();
      }
      widget.onDragClose(n.dragDetails!.delta.dy);
    } else if (_dragClosing && n is ScrollUpdateNotification && n.dragDetails != null) {
      widget.onDragClose(n.dragDetails!.delta.dy);
    } else if (_dragClosing && n is ScrollEndNotification) {
      _dragClosing = false;
      widget.onDragCloseEnd(n.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final columns = (media.size.width / 86).floor().clamp(4, 6);
    final service = LauncherService.instance;

    return Material(
      color: LauncherTheme.bg.withValues(alpha: 0.97),
      child: Padding(
        padding: EdgeInsets.only(top: media.padding.top, bottom: media.viewInsets.bottom),
        child: Column(
          children: [
            // Handle + search. Dragging here closes the drawer too.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (d) => widget.onDragClose(d.primaryDelta ?? 0),
              onVerticalDragEnd: (d) => widget.onDragCloseEnd(d.primaryVelocity ?? 0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: LauncherTheme.line, borderRadius: BorderRadius.circular(2)),
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildSearchField()),
                        IconButton(
                          tooltip: 'Launcher settings',
                          onPressed: () => showLauncherSettings(context),
                          icon: Icon(MdiIcons.tuneVariant, color: LauncherTheme.text, size: 22),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([service.apps, service.hidden, service.drawerFolders, service.folders]),
                builder: (context, _) {
                  final q = _query.text.trim();
                  final hidden = service.hidden.value;
                  final inFolders = service.appsInDrawerFolders;
                  final folderKeys = q.isEmpty ? service.drawerFolders.value.where(service.isValidKey).toList() : const <String>[];
                  final List<LauncherApp> apps = q.isEmpty
                      ? service.apps.value.where((a) => !hidden.contains(a.key) && !inFolders.contains(a.key)).toList()
                      : service.search(q);
                  final suggestions = q.isEmpty ? service.suggestions(limit: columns) : const <LauncherApp>[];

                  final isPhone = _looksLikePhoneNumber(q);
                  final digitsOnly = q.replaceAll(RegExp(r'[^\d]'), '');
                  final directMatchInContacts = digitsOnly.isNotEmpty &&
                      _contacts.any((c) => c.cleanNumber.endsWith(digitsOnly) || digitsOnly.endsWith(c.cleanNumber));

                  return NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: CustomScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (suggestions.isNotEmpty) ...[
                          _sectionLabel('SUGGESTED'),
                          _grid(suggestions, columns),
                          SliverToBoxAdapter(
                            child: Divider(color: LauncherTheme.line, height: 20, indent: 16, endIndent: 16),
                          ),
                        ],
                        if (folderKeys.isNotEmpty) _folderGrid(folderKeys, columns),
                        if (q.isNotEmpty) ...[
                          _sectionLabel(apps.isEmpty ? 'NO APPS FOUND' : 'APPS (${apps.length})'),
                          _grid(apps, columns),
                          if (_contacts.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Divider(color: LauncherTheme.line, height: 24, indent: 16, endIndent: 16),
                            ),
                            _sectionLabel('CONTACTS (${_contacts.length})'),
                            _contactsList(_contacts),
                          ] else if (!_hasContactsPermission && q.length >= 2) ...[
                            SliverToBoxAdapter(child: _contactsPermissionTile()),
                          ],
                          if (isPhone && !directMatchInContacts) ...[
                            SliverToBoxAdapter(child: _directNumberTile(q)),
                          ],
                          SliverToBoxAdapter(child: _webSearchTile(q)),
                        ],
                        if (q.isEmpty) ...[
                          _grid(apps, columns),
                        ],
                        SliverPadding(padding: EdgeInsets.only(bottom: media.padding.bottom + 16)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _query,
      focusNode: _focus,
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => _submit(LauncherService.instance.search(_query.text)),
      style: LauncherTheme.rajdhani(fontSize: 16, fontWeight: FontWeight.w600),
      cursorColor: LauncherTheme.red,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: LauncherTheme.panel2,
        hintText: 'Search apps & contacts',
        hintStyle: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600, color: LauncherTheme.muted),
        prefixIcon: Icon(MdiIcons.magnify, color: LauncherTheme.muted, size: 20),
        suffixIcon: _query.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(MdiIcons.close, size: 18, color: LauncherTheme.muted),
                onPressed: _query.clear,
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: LauncherTheme.line)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: LauncherTheme.line)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: LauncherTheme.redSoft)),
      ),
    );
  }

  Widget _sectionLabel(String text) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Text(text,
              style: LauncherTheme.rajdhani(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: LauncherTheme.muted)),
        ),
      );

  Widget _contactsList(List<LauncherContact> contacts) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _ContactCard(
            contact: contacts[i],
            onTap: () => _handleContactTap(context, contacts[i]),
          ),
          childCount: contacts.length,
        ),
      ),
    );
  }

  void _handleContactTap(BuildContext context, LauncherContact contact) {
    if (contact.phones.length > 1) {
      _showContactNumbersSheet(context, contact);
    } else {
      LauncherNative.openContact(contact.id);
    }
  }

  void _showContactNumbersSheet(BuildContext context, LauncherContact contact) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: LauncherTheme.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: LauncherTheme.rajdhani(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${contact.phones.length} phone numbers',
                          style: LauncherTheme.rajdhani(fontSize: 13, color: LauncherTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      LauncherNative.openContact(contact.id);
                    },
                    icon: Icon(MdiIcons.accountDetailsOutline, size: 16, color: LauncherTheme.red),
                    label: Text(
                      'DETAILS',
                      style: LauncherTheme.rajdhani(fontSize: 12, fontWeight: FontWeight.w700, color: LauncherTheme.red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...contact.phones.map((phone) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: LauncherTheme.panel2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LauncherTheme.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              phone.number,
                              style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              phone.type,
                              style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted),
                            ),
                          ],
                        ),
                      ),
                      _ContactActionButtons(number: phone.number),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactsPermissionTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: LauncherTheme.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LauncherTheme.redSoft.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(MdiIcons.accountSearchOutline, color: LauncherTheme.red, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CONTACT SEARCH ACCESS',
                    style: LauncherTheme.rajdhani(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  Text(
                    'Search contacts and message directly from launcher',
                    style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LauncherTheme.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: _requestContactsAccess,
              child: Text(
                'ENABLE',
                style: LauncherTheme.rajdhani(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directNumberTile(String number) {
    final isLight = LauncherTheme.isLight;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: LauncherTheme.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LauncherTheme.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFE5DFC9) : const Color(0xFF161A22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LauncherTheme.line),
              ),
              alignment: Alignment.center,
              child: Icon(MdiIcons.dialpad, size: 20, color: LauncherTheme.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DIRECT DIAL: $number',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Call, SMS or WhatsApp number directly',
                    style: LauncherTheme.rajdhani(fontSize: 12, color: LauncherTheme.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ContactActionButtons(number: number),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<LauncherApp> apps, int columns) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 92,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => LauncherDraggableItem(
            itemKey: apps[i].key,
            from: null,
            onTap: () => widget.onLaunch(apps[i]),
            onMenu: () {
              _focus.unfocus();
              showAppActionsSheet(context, apps[i]);
            },
            child: _AppTile(app: apps[i]),
          ),
          childCount: apps.length,
        ),
      ),
    );
  }

  Widget _folderGrid(List<String> keys, int columns) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 92),
        delegate: SliverChildBuilderDelegate(
          (context, i) => LauncherDropSlot(
            area: LauncherArea.drawer,
            itemKey: keys[i],
            child: LauncherDraggableItem(
              itemKey: keys[i],
              from: LauncherArea.drawer,
              onTap: () => LauncherActions.open(context, keys[i]),
              onMenu: () => showPlacedItemSheet(context, area: LauncherArea.drawer, itemKey: keys[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: LauncherItemTile(itemKey: keys[i], iconSize: 50),
              ),
            ),
          ),
          childCount: keys.length,
        ),
      ),
    );
  }

  Widget _webSearchTile(String q) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: LauncherTheme.line)),
        tileColor: LauncherTheme.panel,
        leading: Icon(MdiIcons.web, color: LauncherTheme.red),
        title: Text('Search the web for "$q"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LauncherTheme.rajdhani(fontSize: 15, fontWeight: FontWeight.w600)),
        onTap: () => LauncherNative.openWebSearch(q),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final LauncherApp app;

  const _AppTile({required this.app});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LauncherAppIcon(app: app, size: 50),
          const SizedBox(height: 6),
          Text(
            app.displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: LauncherTheme.rajdhani(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.2, height: 1.1),
          ),
        ],
      ),
    );
  }
}

/// Tactical Contact Card displaying contact initials, name, phone, and 3 actions: Call, SMS, WhatsApp.
class _ContactCard extends StatelessWidget {
  final LauncherContact contact;
  final VoidCallback onTap;

  const _ContactCard({
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;
    final primaryNumber = contact.primaryPhone;
    final hasMultiple = contact.phones.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: LauncherTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: LauncherTheme.line.withValues(alpha: isLight ? 0.7 : 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _buildAvatar(isLight),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LauncherTheme.rajdhani(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: LauncherTheme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              primaryNumber.isNotEmpty ? primaryNumber : 'No number',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LauncherTheme.rajdhani(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: LauncherTheme.muted,
                              ),
                            ),
                          ),
                          if (contact.type.isNotEmpty) ...[
                            Text(
                              ' • ${contact.type}',
                              style: LauncherTheme.rajdhani(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: LauncherTheme.redSoft,
                              ),
                            ),
                          ],
                          if (hasMultiple) ...[
                            Text(
                              ' (+${contact.phones.length - 1})',
                              style: LauncherTheme.rajdhani(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: LauncherTheme.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ContactActionButtons(number: primaryNumber),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isLight) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFE5DFC9) : const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LauncherTheme.line),
      ),
      alignment: Alignment.center,
      child: Text(
        contact.initials,
        style: LauncherTheme.rajdhani(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: LauncherTheme.red,
        ),
      ),
    );
  }
}

/// Three tactical action buttons: Call, SMS, WhatsApp.
class _ContactActionButtons extends StatelessWidget {
  final String number;

  const _ContactActionButtons({required this.number});

  @override
  Widget build(BuildContext context) {
    final isLight = LauncherTheme.isLight;
    final enabled = number.isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Call Button
        _ContactActionButton(
          icon: MdiIcons.phone,
          tooltip: 'Call',
          bgColor: const Color(0xFF10B981).withValues(alpha: isLight ? 0.12 : 0.16),
          borderColor: const Color(0xFF10B981).withValues(alpha: isLight ? 0.35 : 0.40),
          iconColor: isLight ? const Color(0xFF047857) : const Color(0xFF34D399),
          onTap: enabled ? () => LauncherNative.callNumber(number) : null,
        ),
        const SizedBox(width: 6),
        // 2. Message (SMS) Button
        _ContactActionButton(
          icon: MdiIcons.messageTextOutline,
          tooltip: 'SMS Message',
          bgColor: const Color(0xFF0EA5E9).withValues(alpha: isLight ? 0.12 : 0.16),
          borderColor: const Color(0xFF0EA5E9).withValues(alpha: isLight ? 0.35 : 0.40),
          iconColor: isLight ? const Color(0xFF0369A1) : const Color(0xFF38BDF8),
          onTap: enabled ? () => LauncherNative.messageNumber(number) : null,
        ),
        const SizedBox(width: 6),
        // 3. Message on WhatsApp Button
        _ContactActionButton(
          icon: MdiIcons.whatsapp,
          tooltip: 'WhatsApp Message',
          bgColor: const Color(0xFF25D366).withValues(alpha: isLight ? 0.14 : 0.18),
          borderColor: const Color(0xFF25D366).withValues(alpha: isLight ? 0.40 : 0.45),
          iconColor: isLight ? const Color(0xFF128C7E) : const Color(0xFF25D366),
          onTap: enabled
              ? () {
                  final code = LauncherService.instance.defaultCountryCode.value;
                  final formatted = LauncherContact.formatWhatsAppNumber(number, defaultCode: code);
                  LauncherNative.openWhatsApp(formatted, countryCode: code);
                }
              : null,
        ),
      ],
    );
  }
}

/// Tactical circular-chamfer icon button for contact actions.
class _ContactActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const _ContactActionButton({
    required this.icon,
    required this.tooltip,
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}

