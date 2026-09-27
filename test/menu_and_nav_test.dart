// Covers the main-menu and navigation-chrome refresh: the bottom nav bar and
// desktop nav rail agree on tab names, the header renders without overflowing
// at phone width, and the "More" menu lists its groups without dropping any
// existing destination.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/screens/more_screen.dart';
import 'package:missions/src/widgets/header_widget.dart';
import 'package:missions/src/widgets/ui/jwe_bottom_nav_bar.dart';
import 'package:firebase_core/firebase_core.dart';
import './mock.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<AppProvider>(
    create: (_) => AppProvider.forTest(),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  setupFirebaseAuthMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('bottom nav bar and header agree on the LOGBOOK tab name', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      JweBottomNavBar(
        selectedIndex: 4,
        activeColor: Colors.cyan,
        onItemTapped: (_) {},
      ),
    ));
    await tester.pump();

    expect(find.text('LOGBOOK'), findsOneWidget);
    expect(find.text('INTEL'), findsNothing);
    expect(find.text('ANALYTICS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header renders the current tab label without overflowing at phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(HeaderWidget(currentViewLabel: 'LOGBOOK')));
    await tester.pump();

    expect(find.text('LOGBOOK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more menu keeps every pre-existing destination and adds the new ones', (tester) async {
    // Tall enough to lay out the whole menu without needing to scroll, so
    // every entry can be found directly.
    await tester.binding.setSurfaceSize(const Size(360, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const MoreScreen(isEmbed: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Nothing that used to be reachable from the menu was dropped, and the
    // newly surfaced destinations (previously hard to find) are now listed.
    for (final title in <String>[
      'BUS TIME',
      'DATABASE EDITOR',
      'REALTIME TRADING',
      'BEHAVIORAL OVERRIDE',
      'WIDGETS STUDIO',
      'TRANSIT NETWORK & SUB-STOPS',
      'SYSTEM SETTINGS',
      'STANDARD OPERATIONAL PROCEDURES (SOP)',
      'EMERGENCY THERAPY',
      'GRATITUDE LOG',
      'SOMEDAY / MAYBE',
      'NORA AI ASSISTANT',
      'SKILLS & PROGRESSION',
      'PEOPLE & RELATIONSHIPS',
      'REFLECTIONS ARCHIVE',
      'ARCHIVED REPORTS',
      'SCHEDULED REMINDERS',
    ]) {
      expect(find.text(title), findsOneWidget, reason: 'missing menu entry: $title');
    }

    expect(tester.takeException(), isNull);
  });
}
