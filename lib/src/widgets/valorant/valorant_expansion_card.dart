import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ValorantExpansionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final bool initiallyExpanded;
  final Color? accentColor;

  const ValorantExpansionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.initiallyExpanded = false,
    this.accentColor,
  });

  @override
  State<ValorantExpansionCard> createState() => _ValorantExpansionCardState();
}

class _ValorantExpansionCardState extends State<ValorantExpansionCard>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeIn));
    _iconTurns =
        _controller.drive(Tween<double>(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeIn)));

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? AppTheme.fhAccentTeal;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark,
        border: Border.all(
            color: _isExpanded
                ? color.withValues(alpha: 0.5)
                : AppTheme.fhBorderColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4), // Beveled/Sharp look
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _handleTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isExpanded ? color.withValues(alpha: 0.1) : null,
                border: _isExpanded
                    ? Border(bottom: BorderSide(color: color.withValues(alpha: 0.2)))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(widget.icon,
                      size: 18,
                      color: _isExpanded ? color : AppTheme.fhTextSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontWeight: FontWeight.bold,
                        fontSize: 16, // Compact header
                        letterSpacing: 1.2,
                        color: _isExpanded
                            ? AppTheme.fhTextPrimary
                            : AppTheme.fhTextSecondary,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    widget.trailing!,
                    const SizedBox(width: 8),
                  ],
                  RotationTransition(
                    turns: _iconTurns,
                    child: Icon(MdiIcons.chevronDown,
                        color: AppTheme.fhTextSecondary, size: 20),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedBuilder(
              animation: _controller.view,
              builder: (BuildContext context, Widget? child) {
                return Align(
                  heightFactor: _heightFactor.value,
                  child: child,
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}