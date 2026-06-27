import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:provider/provider.dart';

/// Operator HUD header — AppBar with cap row in `bottom:` slot.
/// Title row uses Saira display + amber code prefix.
class HeaderWidget extends StatelessWidget implements PreferredSizeWidget {
  final String currentViewLabel;
  final VoidCallback? onOpenPersona;
  final Widget? customAction;

  static const double _stripH = 22;

  final Widget? leading;

  const HeaderWidget({
    super.key,
    required this.currentViewLabel,
    this.onOpenPersona,
    this.customAction,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 900;
    final now = TimeOfDay.now();
    final clock = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final callsign = (appProvider.currentUser?.displayName ?? '').trim().isEmpty
        ? 'OPERATIVE'
        : appProvider.currentUser!.displayName!.trim().toUpperCase();
    final maxLevel = appProvider.skills.isEmpty
        ? 1
        : appProvider.skills.map((s) => s.level).reduce((a, b) => a > b ? a : b);

    return AppBar(
      backgroundColor: JweTheme.bgCanvas,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      toolbarHeight: kToolbarHeight,
      leadingWidth: leading != null ? 48 : 38,
      leading: leading ?? Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: ArcaneAppIcon(
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
      title: Row(children: [
        Container(width: 4, height: 14, color: Theme.of(context).primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            currentViewLabel.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.saira(
              color: JweTheme.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ]),
      actions: [
        if (appProvider.loadingTaskName != null || appProvider.isSyncing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: JweTheme.cyanSoft,
                border: Border.all(color: JweTheme.accentCyan.withOpacity(0.4), width: 1),
              ),
              child: const SizedBox(
                width: 10, height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.4,
                  valueColor: AlwaysStoppedAnimation<Color>(JweTheme.accentCyan),
                ),
              ),
            ),
          ),
        if (customAction != null) customAction!,
        IconButton(
          icon: Icon(MdiIcons.shieldAccount, color: JweTheme.textMuted, size: 22),
          onPressed: onOpenPersona,
          tooltip: 'ARMORY',
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_stripH),
        child: Container(
          height: _stripH,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: JweTheme.bgCanvas,
            border: Border(bottom: BorderSide(color: JweTheme.lineSoft, width: 1)),
          ),
          child: Row(children: [
            const HudDot(tone: HudTone.teal, size: 5),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _editCallsign(context, appProvider, callsign),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(callsign,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5, color: JweTheme.textMid, letterSpacing: 1.4, fontWeight: FontWeight.w600,
                    )),
                const SizedBox(width: 4),
                Icon(MdiIcons.pencilOutline, size: 10, color: JweTheme.textMuted),
              ]),
            ),
            const SizedBox(width: 6),
            Container(width: 2, height: 2, color: JweTheme.lineSoft),
            const SizedBox(width: 6),
            Text('LVL $maxLevel',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5, color: JweTheme.accentCyan, letterSpacing: 1.2, fontWeight: FontWeight.w600,
                )),
            const Spacer(),
            Flexible(
              child: Text(_dateLabel(),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5, color: JweTheme.textMuted, letterSpacing: 1.2, fontWeight: FontWeight.w500,
                  )),
            ),
            const SizedBox(width: 6),
            Container(width: 2, height: 2, color: JweTheme.lineSoft),
            const SizedBox(width: 6),
            Text(clock,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5, color: Theme.of(context).primaryColor, letterSpacing: 1.4, fontWeight: FontWeight.w600,
                )),
          ]),
        ),
      ),
    );
  }

  static String _dateLabel() {
    final d = DateTime.now();
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${days[d.weekday - 1]} · ${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _editCallsign(BuildContext context, AppProvider provider, String current) async {
    final ctrl = TextEditingController(text: current);
    final primaryColor = Theme.of(context).primaryColor;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JweTheme.panel,
        shape: const BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
        title: Text(
          'EDIT CALLSIGN',
          style: GoogleFonts.saira(color: JweTheme.textWhite, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 24,
          style: GoogleFonts.jetBrainsMono(color: JweTheme.textWhite, fontSize: 14, letterSpacing: 1.2),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'OPERATOR',
            hintStyle: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, fontSize: 14),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: JweTheme.lineSoft)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: JweTheme.textMuted, letterSpacing: 1.4)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('CONFIRM', style: GoogleFonts.jetBrainsMono(color: primaryColor, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != current) {
      await provider.updateUserDisplayName(result);
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + _stripH);
}

class ArcaneAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const ArcaneAppIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArcaneAppIconPainter(color: color),
      ),
    );
  }
}

class _ArcaneAppIconPainter extends CustomPainter {
  final Color color;

  _ArcaneAppIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final S = size.width;

    final chevronPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = S * 0.12
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    // First (upper) chevron
    final chevron1 = Path()
      ..moveTo(S * 0.2, S * 0.5)
      ..lineTo(S * 0.5, S * 0.22)
      ..lineTo(S * 0.8, S * 0.5);
    canvas.drawPath(chevron1, chevronPaint);

    // Second (lower) chevron
    final chevron2 = Path()
      ..moveTo(S * 0.2, S * 0.78)
      ..lineTo(S * 0.5, S * 0.5)
      ..lineTo(S * 0.8, S * 0.78);
    canvas.drawPath(chevron2, chevronPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcaneAppIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
