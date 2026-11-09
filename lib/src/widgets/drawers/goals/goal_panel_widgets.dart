import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/goal_model.dart';

/// Tappable dropdown row used for each panel inside a goal card.
class GoalDropdownHeader extends StatelessWidget {
  final String label;
  final String countText;
  final bool isOpen;
  final Color themeColor;
  final bool isLight;
  final VoidCallback onTap;

  const GoalDropdownHeader({
    super.key,
    required this.label,
    required this.countText,
    required this.isOpen,
    required this.themeColor,
    required this.isLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          children: [
            AnimatedRotation(
              turns: isOpen ? 0 : -0.25,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down, size: 16, color: themeColor),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isLight ? Colors.black87 : Colors.white70,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                countText,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain item list (no checkboxes) with an add row. Used for Key Results and Collaborators.
class GoalItemListPanel extends StatefulWidget {
  final List<GoalListItem> items;
  final Color themeColor;
  final bool isLight;
  final String hint;
  final String emptyText;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;

  const GoalItemListPanel({
    super.key,
    required this.items,
    required this.themeColor,
    required this.isLight,
    required this.hint,
    required this.emptyText,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<GoalItemListPanel> createState() => _GoalItemListPanelState();
}

class _GoalItemListPanelState extends State<GoalItemListPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.themeColor;
    final isLight = widget.isLight;
    final muted = isLight ? Colors.black45 : Colors.white38;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              widget.emptyText,
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: muted),
            ),
          ),
        for (final item in widget.items)
          Padding(
            key: ValueKey('li_${item.id}'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Text(
                    item.text,
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: textColor),
                  ),
                ),
                InkWell(
                  onTap: () => widget.onDelete(item.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: muted),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 34,
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: textColor),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    isDense: true,
                    filled: true,
                    fillColor: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF14151E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _submit,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: isLight ? 0.15 : 0.22),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: themeColor.withValues(alpha: 0.45), width: 0.8),
                ),
                child: Text(
                  'ADD',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
