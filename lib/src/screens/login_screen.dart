import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/valorant/valorant_form_field.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Logo Area
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(MdiIcons.triangleOutline, size: 64, color: AppTheme.fhAccentRed),
                      const SizedBox(height: 16),
                      const Text(
                        'PRIMUS',
                        style: TextStyle(
                          color: AppTheme.fhTextPrimary,
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                          height: 0.9,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 20, height: 2, color: AppTheme.fhAccentRed),
                          const SizedBox(width: 12),
                          const Text(
                            'OPERATIVE ACCESS',
                            style: TextStyle(
                              color: AppTheme.fhTextSecondary,
                              fontFamily: 'RobotoMono',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(width: 20, height: 2, color: AppTheme.fhAccentRed),
                        ],
                      ),
                    ],
                  ),
                ),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppTheme.fhBgDark.withOpacity(0.8),
                    border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        ValorantFormField(
                          controller: _emailController,
                          label: 'EMAIL IDENTIFIER',
                          prefixIcon: MdiIcons.emailOutline,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || !value.contains('@')) return 'INVALID FORMAT';
                            return null;
                          },
                          onSaved: (value) => _email = value!,
                        ),
                        const SizedBox(height: 20),
                        ValorantFormField(
                          controller: _passwordController,
                          label: 'PASSCODE',
                          prefixIcon: MdiIcons.lockOutline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? MdiIcons.eyeOutline : MdiIcons.eyeOffOutline,
                              color: AppTheme.fhTextSecondary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) return 'MIN 6 CHARS';
                            return null;
                          },
                          onSaved: (value) => _password = value!,
                        ),
                        
                        if (_error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.fhAccentRed.withOpacity(0.1),
                                border: Border(left: BorderSide(color: AppTheme.fhAccentRed, width: 3))
                              ),
                              child: Text(
                                _error.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.fhAccentRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'RobotoMono'
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),

                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(color: AppTheme.fhAccentRed),
                          )
                        else
                          ValorantButton(
                            label: _isLogin ? 'AUTHENTICATE' : 'INITIATE',
                            onPressed: _submit,
                            isPrimary: true,
                          ),

                        const SizedBox(height: 16),

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
                              _isLogin
                                  ? 'REQUEST ACCESS ID'
                                  : 'RETURN TO LOGIN',
                              style: const TextStyle(
                                color: AppTheme.fhTextSecondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                fontSize: 12
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}