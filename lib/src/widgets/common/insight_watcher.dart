import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/widgets/dialogs/xp_gain_dialog.dart';

/// Listens to [AppProvider.insightReady] and pops the "INSIGHT ACQUIRED" dialog
/// once analysis completes. Wrap below the home screen so the dialog renders
/// over the home (rather than over the reflection editor that triggered it).
class InsightWatcher extends StatefulWidget {
  final Widget child;
  const InsightWatcher({super.key, required this.child});

  @override
  State<InsightWatcher> createState() => _InsightWatcherState();
}

class _InsightWatcherState extends State<InsightWatcher> {
  ValueListenable<InsightReadyEvent?>? _listenable;
  bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<AppProvider>(context, listen: false);
    final l = provider.insightReady;
    if (!identical(l, _listenable)) {
      _listenable?.removeListener(_onInsight);
      _listenable = l;
      _listenable!.addListener(_onInsight);
    }
  }

  @override
  void dispose() {
    _listenable?.removeListener(_onInsight);
    super.dispose();
  }

  void _onInsight() {
    final event = _listenable?.value;
    if (event == null || _showing || !mounted) return;
    _showing = true;
    // Defer to next frame so we're not inside a notifyListeners cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _showing = false;
        return;
      }
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        builder: (_) => XpGainDialog(
          xpGained: event.xpGained,
          insightText: event.feedback,
        ),
      );
      _showing = false;
      // Clear so a subsequent identical event still fires the dialog.
      if (_listenable?.value == event) {
        (_listenable as ValueNotifier<InsightReadyEvent?>?)?.value = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
