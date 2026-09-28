import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';

/// Crashes caught by the native crash guard. Android forgets the default home app whenever a
/// home app crashes, so Arcane catches crashes, logs them here and restarts quietly instead.
/// Copy the log to track down what's crashing.
class LauncherCrashLogTile extends StatefulWidget {
  const LauncherCrashLogTile({super.key});

  @override
  State<LauncherCrashLogTile> createState() => _LauncherCrashLogTileState();
}

class _LauncherCrashLogTileState extends State<LauncherCrashLogTile> {
  List<String> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await LauncherNative.getCrashLog();
    if (mounted) setState(() => _entries = entries);
  }

  /// First line of an entry: "yyyy-MM-dd HH:mm:ss · vX · thread …".
  String _when(String entry) => entry.split('\n').first.split(' · ').first;

  Future<void> _open() async {
    final newestFirst = _entries.reversed.toList();
    final all = newestFirst.join('\n\n──────────\n\n');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Crash log (${_entries.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(all, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await LauncherNative.clearCrashLog();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('CLEAR'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: all));
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Crash log copied')));
            },
            child: const Text('COPY'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
        ],
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!LauncherNative.isSupported) return const SizedBox.shrink();
    final count = _entries.length;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(MdiIcons.bugOutline, size: 20),
      title: const Text('Crash log', style: TextStyle(fontSize: 14)),
      subtitle: Text(
        count == 0
            ? 'No crashes caught. Crashes are logged here and Arcane stays your home app.'
            : '$count caught · last ${_when(_entries.last)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: count == 0 ? null : const Icon(Icons.chevron_right, size: 20),
      onTap: count == 0 ? null : _open,
    );
  }
}
