// lib/src/widgets/middle_panel_widget.dart
import 'package:flutter/material.dart';

class MiddlePanelWidget extends StatelessWidget {
  final int selectedIndex;
  final List<Widget> views;

  const MiddlePanelWidget({
    super.key,
    required this.selectedIndex,
    required this.views,
  });

  @override
  Widget build(BuildContext context) {
    print("[MiddlePanelWidget] Building. SelectedIndex: $selectedIndex");

    // Define a maximum width for the content
    const double maxWidth = 600.0; // Slightly wider for better viewability

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Center( // Center the content horizontally
        child: ConstrainedBox( // Apply maxWidth
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: IndexedStack(
            index: selectedIndex,
            children: views.map((view) {
              // Wrap each view in a SingleChildScrollView and KeepAliveWrapper
              return KeepAliveWrapper(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: view,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// Helper widget to keep state in IndexedStack (similar to TabBarView's needs)
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context); // Important to call super.build
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}