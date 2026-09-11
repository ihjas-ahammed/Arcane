import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:provider/provider.dart';

class AddSubCheckItemRow extends StatefulWidget {
  final String goalId;
  final Color themeColor;
  final bool isLight;

  const AddSubCheckItemRow({
    super.key,
    required this.goalId,
    required this.themeColor,
    required this.isLight,
  });

  @override
  State<AddSubCheckItemRow> createState() => _AddSubCheckItemRowState();
}

class _AddSubCheckItemRowState extends State<AddSubCheckItemRow> {
  final _subController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _scrollToVisible();
    }
  }

  void _scrollToVisible() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _focusNode.hasFocus) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _subController.dispose();
    super.dispose();
  }

  void _submit(AppProvider provider) {
    final text = _subController.text.trim();
    if (text.isNotEmpty) {
      provider.addGoalSubCheckItem(widget.goalId, text);
      _subController.clear();
      _scrollToVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _subController,
            focusNode: _focusNode,
            scrollPadding: const EdgeInsets.only(bottom: 120),
            onTap: _scrollToVisible,
            onSubmitted: (_) => _submit(provider),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              color: widget.isLight ? Colors.black87 : Colors.white,
            ),
            decoration: InputDecoration(
              hintText: '+ Add subchecklist task...',
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: widget.isLight ? Colors.black38 : Colors.white38,
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: widget.themeColor.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => _submit(provider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: widget.themeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ADD',
              style: GoogleFonts.orbitron(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: widget.isLight ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
