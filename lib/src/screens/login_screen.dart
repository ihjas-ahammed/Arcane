import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/spidey_theme.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        if (e is FirebaseAuthException) {
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
      body: Container(
        decoration: const BoxDecoration(gradient: SpideyTheme.backdropGradient),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _WebGridPainter()),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: SpideyTheme.spideyRed,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: SpideyTheme.spideyRed.withOpacity(0.6),
                                    blurRadius: 24,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.shield_moon, size: 40, color: Colors.black),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'ARCANE',
                              style: GoogleFonts.rajdhani(
                                color: SpideyTheme.textWhite,
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6.0,
                                height: 0.9,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 24, height: 2, color: SpideyTheme.spideyRed),
                                const SizedBox(width: 10),
                                Text(
                                  'SYSTEM ACCESS',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: SpideyTheme.spideyCyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3.0,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(width: 24, height: 2, color: SpideyTheme.spideyRed),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ClipPath(
                        clipper: _LoginPanelClipper(),
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: SpideyTheme.bgPanel,
                            border: Border.all(color: SpideyTheme.border),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _spideyField(
                                  controller: _emailController,
                                  label: 'EMAIL IDENTIFIER',
                                  icon: MdiIcons.emailOutline,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => (v == null || !v.contains('@')) ? 'INVALID FORMAT' : null,
                                  onSaved: (v) => _email = v!,
                                ),
                                const SizedBox(height: 18),
                                _spideyField(
                                  controller: _passwordController,
                                  label: 'PASSCODE',
                                  icon: MdiIcons.lockOutline,
                                  obscureText: _obscurePassword,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? MdiIcons.eyeOutline : MdiIcons.eyeOffOutline,
                                      color: SpideyTheme.textGrey,
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
                                        color: SpideyTheme.spideyRed.withOpacity(0.1),
                                        border: const Border(
                                            left: BorderSide(color: SpideyTheme.spideyRed, width: 3)),
                                      ),
                                      child: Text(
                                        _error.toUpperCase(),
                                        style: const TextStyle(
                                            color: SpideyTheme.spideyRed,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'RobotoMono'),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 28),
                                if (_isLoading)
                                  const Center(child: CircularProgressIndicator(color: SpideyTheme.spideyRed))
                                else
                                  _spideyPrimaryButton(_isLogin ? 'AUTHENTICATE' : 'INITIATE', _submit),
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
                                      style: GoogleFonts.rajdhani(
                                        color: SpideyTheme.spideyCyan,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spideyField({
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
            Container(width: 3, height: 12, color: SpideyTheme.spideyRed),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                color: SpideyTheme.spideyCyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 11,
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
          style: const TextStyle(color: SpideyTheme.textWhite, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: SpideyTheme.bgElevated,
            contentPadding: const EdgeInsets.all(14),
            prefixIcon: icon != null ? Icon(icon, color: SpideyTheme.textGrey, size: 18) : null,
            suffixIcon: suffix,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: SpideyTheme.border),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: SpideyTheme.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: SpideyTheme.spideyRed, width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: SpideyTheme.spideyRed),
            ),
            errorStyle: const TextStyle(
              color: SpideyTheme.spideyRed,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _spideyPrimaryButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: SpideyTheme.spideyRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.rajdhani(
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _LoginPanelClipper extends CustomClipper<Path> {
  static const double _cut = 14.0;
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(_cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - _cut)
      ..lineTo(size.width - _cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, _cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _WebGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SpideyTheme.spideyRed.withOpacity(0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height * 0.25);
    for (double r = 40; r < size.width * 1.2; r += 60) {
      canvas.drawCircle(center, r, paint);
    }
    const segments = 12;
    final maxR = size.width * 1.4;
    for (int i = 0; i < segments; i++) {
      final angle = (i * 2 * math.pi) / segments;
      final dx = center.dx + maxR * math.cos(angle);
      final dy = center.dy + maxR * math.sin(angle);
      canvas.drawLine(center, Offset(dx, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
