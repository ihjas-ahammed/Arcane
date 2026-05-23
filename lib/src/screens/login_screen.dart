import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/services/app_user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isLogin = true;
  bool _isLoading = false;
  String _error = '';
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (_isLogin) {
        await appProvider.loginUser(_email, _password);
      } else {
        await appProvider.signupUser(_email, _password);
      }
    } catch (e) {
      setState(() {
        if (e is AuthFailure) {
          _error = e.message ?? "Authentication failed.";
        } else {
          _error = "Connection error. Retrying...";
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JweTheme.bgBase,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _TacticalGridPainter()),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    HudPanel(
                      clip: HudClip.both,
                      accent: JweTheme.accentAmber,
                      allBrackets: true,
                      background: JweTheme.panel,
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _hudField(
                              controller: _emailController,
                              label: 'EMAIL IDENTIFIER',
                              icon: MdiIcons.emailOutline,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || !v.contains('@')) ? 'INVALID FORMAT' : null,
                              onSaved: (v) => _email = v!,
                            ),
                            const SizedBox(height: 18),
                            _hudField(
                              controller: _passwordController,
                              label: 'PASSCODE',
                              icon: MdiIcons.lockOutline,
                              obscureText: _obscurePassword,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword ? MdiIcons.eyeOutline : MdiIcons.eyeOffOutline,
                                  color: JweTheme.textMuted,
                                  size: 18,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? 'MIN 6 CHARS' : null,
                              onSaved: (v) => _password = v!,
                            ),
                            if (_error.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 18.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: JweTheme.accentRed.withOpacity(0.08),
                                    border: const Border(
                                      left: BorderSide(color: JweTheme.accentRed, width: 3),
                                    ),
                                  ),
                                  child: Text(
                                    _error.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      color: JweTheme.accentRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 28),
                            if (_isLoading)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: JweTheme.accentAmber,
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              _hudPrimaryButton(
                                _isLogin ? 'AUTHENTICATE' : 'INITIATE',
                                _submit,
                              ),
                            const SizedBox(height: 14),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _error = '';
                                    _formKey.currentState?.reset();
                                    _emailController.clear();
                                    _passwordController.clear();
                                  });
                                },
                                child: Text(
                                  _isLogin ? 'REQUEST ACCESS ID' : 'RETURN TO LOGIN',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: JweTheme.accentCyan,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HudDot(tone: HudTone.amber, size: 5),
                        const SizedBox(width: 8),
                        Text(
                          'SECURE CHANNEL ESTABLISHED',
                          style: GoogleFonts.jetBrainsMono(
                            color: JweTheme.textMuted,
                            fontSize: 10,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            HudReticle(size: 64, color: JweTheme.accentAmber),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: JweTheme.amberSoft,
                shape: BoxShape.circle,
                border: Border.all(color: JweTheme.accentAmber.withOpacity(0.6), width: 1),
              ),
              child: const Icon(Icons.shield_moon, size: 18, color: JweTheme.accentAmber),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'MISSIONS',
          style: GoogleFonts.saira(
            color: JweTheme.textWhite,
            fontSize: 52,
            fontWeight: FontWeight.w800,
            letterSpacing: 8.0,
            height: 0.9,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 24, height: 1, color: JweTheme.lineAmber),
            const SizedBox(width: 10),
            Text(
              'OPERATOR SYSTEM',
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentAmber,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 24, height: 1, color: JweTheme.lineAmber),
          ],
        ),
      ],
    );
  }

  Widget _hudField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    Widget? suffix,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 10, color: JweTheme.accentAmber),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                color: JweTheme.accentCyan,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onSaved: onSaved,
          style: GoogleFonts.inter(color: JweTheme.textWhite, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: JweTheme.elev,
            contentPadding: const EdgeInsets.all(14),
            prefixIcon: icon != null ? Icon(icon, color: JweTheme.textMuted, size: 18) : null,
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: JweTheme.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: JweTheme.line),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: JweTheme.accentAmber, width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: JweTheme.accentRed),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: JweTheme.accentRed, width: 1.5),
            ),
            errorStyle: GoogleFonts.jetBrainsMono(
              color: JweTheme.accentRed,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _hudPrimaryButton(String label, VoidCallback onPressed) {
    return ClipPath(
      clipper: HudCutClipper(clip: HudClip.both, cut: 10),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: JweTheme.accentAmber,
          foregroundColor: JweTheme.bgBase,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.saira(
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            fontSize: 15,
            color: JweTheme.bgBase,
          ),
        ),
      ),
    );
  }
}

class _TacticalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = JweTheme.accentAmber.withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final scanPaint = Paint()
      ..color = JweTheme.accentCyan.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += spacing * 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    final cornerPaint = Paint()
      ..color = JweTheme.accentAmber.withOpacity(0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const cs = 20.0;
    const mg = 32.0;
    for (final pos in [
      const Offset(mg, mg),
      Offset(size.width - mg, mg),
      Offset(mg, size.height - mg),
      Offset(size.width - mg, size.height - mg),
    ]) {
      canvas.drawLine(Offset(pos.dx - cs / 2, pos.dy), Offset(pos.dx + cs / 2, pos.dy), cornerPaint);
      canvas.drawLine(Offset(pos.dx, pos.dy - cs / 2), Offset(pos.dx, pos.dy + cs / 2), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
