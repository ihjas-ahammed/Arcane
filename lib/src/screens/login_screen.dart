import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuthException

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _username = '';
  bool _isLogin = true;
  bool _isLoading = false;
  String _error = '';
  bool _obscurePassword = true;
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
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
        await appProvider.signupUser(_email, _password, _username);
      }
    } catch (e) {
      setState(() {
        if (e is FirebaseAuthException) {
          _error =
              e.message ?? "An unknown Firebase authentication error occurred.";
        } else {
          _error = "An unexpected error occurred. Please try again.";
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              color: AppTheme.fhBgDark,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: const BorderSide(
                    color: AppTheme.fhBorderColor, width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32.0, vertical: 40.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                       Icon(MdiIcons.shieldCrownOutline,
                          size: 64, color: AppTheme.fhAccentTealFixed),
                      const SizedBox(height: 24),
                      Text(
                        'ARCANE',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: AppTheme.fhAccentTealFixed,
                          fontFamily: AppTheme.fontDisplay,
                          letterSpacing: 2.0
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'Enter the Void' : 'Ascend',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.fhTextSecondary,
                          fontStyle: FontStyle.italic
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      if (!_isLogin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child:  TextFormField(
                            controller: _usernameController,
                            decoration:  InputDecoration(
                              labelText: 'Callsign',
                              prefixIcon:  Icon(MdiIcons.accountOutline),
                            ),
                            style: const TextStyle(
                                color: AppTheme.fhTextPrimary,
                                fontFamily: AppTheme.fontBody),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a username.';
                              }
                              if (value.trim().length < 3) {
                                return 'Username must be at least 3 characters.';
                              }
                              return null;
                            },
                            onSaved: (value) => _username = value!.trim(),
                          ),
                        ),
                      TextFormField(
                        controller: _emailController,
                        decoration:  InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(MdiIcons.emailOutline),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                            color: AppTheme.fhTextPrimary,
                            fontFamily: AppTheme.fontBody),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !value.contains('@')) {
                            return 'Please enter a valid email.';
                          }
                          return null;
                        },
                        onSaved: (value) => _email = value!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Passcode',
                          prefixIcon:  Icon(MdiIcons.lockOutline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? MdiIcons.eyeOutline
                                  : MdiIcons.eyeOffOutline,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                            color: AppTheme.fhTextPrimary,
                            fontFamily: AppTheme.fontBody),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              value.length < 6) {
                            return 'Password must be at least 6 characters long.';
                          }
                          return null;
                        },
                        onSaved: (value) => _password = value!,
                      ),
                      if (_error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            _error,
                            style: const TextStyle(
                                color: AppTheme.fhAccentRed,
                                fontSize: 12,
                                fontFamily: AppTheme.fontBody),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (_isLoading)
                        const CircularProgressIndicator(
                            color: AppTheme.fhAccentTealFixed)
                      else
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: AppTheme.fhAccentTealFixed,
                            foregroundColor: AppTheme.fhBgDeepDark,
                          ),
                          child: Text(_isLogin ? 'LOGIN' : 'SIGN UP'),
                        ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _error = '';
                            _formKey.currentState?.reset();
                            _usernameController.clear();
                            _emailController.clear();
                            _passwordController.clear();
                          });
                        },
                        child: Text(
                          _isLogin
                              ? 'Need an account? Sign Up'
                              : 'Already have an account? Login',
                          style: const TextStyle(color: AppTheme.fhTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}