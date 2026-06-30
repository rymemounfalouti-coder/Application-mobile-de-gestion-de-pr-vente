import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../database/database_helper.dart';
import '../legal/conditions_screen.dart';
import '../legal/privacy_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  static const _primaryBlue = Color(0xFF1B73F8);
  static const _textDark = Color(0xFF111B3D);
  static const _textMuted = Color(0xFF74809A);

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final nom = _nomController.text.trim();
    final prenom = _prenomController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (nom.isEmpty ||
        prenom.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage('Veuillez remplir tous les champs');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Email invalide');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Les mots de passe ne correspondent pas');
      return;
    }

    if (!_acceptedTerms) {
      _showMessage('Veuillez accepter les conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final existingUsers = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
        limit: 1,
      );

      if (!mounted) return;

      if (existingUsers.isNotEmpty) {
        _showMessage(
          'Ce compte existe déjà',
          backgroundColor: Color(0xFFE24444),
        );
        return;
      }

      await db.insert('users', {
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'password': password,
      });

      if (!mounted) return;

      _showMessage(
        'Compte créé avec succès',
        backgroundColor: Color(0xFF12805C),
      );
      await Future.delayed(Duration(milliseconds: 1200));

      if (!mounted) return;
      _goToLogin(replace: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor ?? _textDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  void _goToLogin({bool replace = false}) {
    if (Navigator.canPop(context) && !replace) {
      Navigator.pop(context);
      return;
    }

    final route = MaterialPageRoute(builder: (_) => LoginScreen());
    if (replace) {
      Navigator.pushAndRemoveUntil(context, route, (route) => false);
    } else {
      Navigator.pushReplacement(context, route);
    }
  }

  void _openConditions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ConditionsScreen()),
    );
  }

  void _openPrivacy() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F7FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 800),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF193A70).withValues(alpha: .13),
                      blurRadius: 28,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(top: 156, right: 28, child: _DotPattern()),
                    Padding(
                      padding: EdgeInsets.fromLTRB(46, 34, 46, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () => _goToLogin(),
                            icon: Icon(Icons.arrow_back, size: 21),
                            label: Text(
                              AppLocalizations.globalText(
                                'Retour à la connexion',
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: _textDark,
                              padding: EdgeInsets.zero,
                              textStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Center(
                            child: Column(
                              children: [
                                _AvatarHeader(),
                                SizedBox(height: 20),
                                Text(
                                  AppLocalizations.globalText(
                                    'Créer un compte',
                                  ),
                                  style: TextStyle(
                                    color: _textDark,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  AppLocalizations.globalText(
                                    'Remplissez les informations ci-dessous\npour créer votre compte',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 16,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 32),
                          _RegisterCard(
                            formKey: _formKey,
                            nomController: _nomController,
                            prenomController: _prenomController,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            confirmPasswordController:
                                _confirmPasswordController,
                            obscurePassword: _obscurePassword,
                            obscureConfirmPassword: _obscureConfirmPassword,
                            acceptedTerms: _acceptedTerms,
                            isLoading: _isLoading,
                            onTogglePassword: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            onToggleConfirmPassword: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            onTermsChanged: (value) {
                              setState(() => _acceptedTerms = value ?? false);
                            },
                            onConditionsTap: _openConditions,
                            onPrivacyTap: _openPrivacy,
                            onRegister: _register,
                            onLoginTap: () => _goToLogin(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  _RegisterCard({
    required this.formKey,
    required this.nomController,
    required this.prenomController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.acceptedTerms,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onTermsChanged,
    required this.onConditionsTap,
    required this.onPrivacyTap,
    required this.onRegister,
    required this.onLoginTap,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nomController;
  final TextEditingController prenomController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool acceptedTerms;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final ValueChanged<bool?> onTermsChanged;
  final VoidCallback onConditionsTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onRegister;
  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(34, 30, 34, 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF193A70).withValues(alpha: .08),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final fields = [
                  _NameField(
                    label: AppLocalizations.globalText('Nom'),
                    hint: AppLocalizations.globalText('Votre nom'),
                    controller: nomController,
                    action: TextInputAction.next,
                  ),
                  _NameField(
                    label: AppLocalizations.globalText('Prénom'),
                    hint: AppLocalizations.globalText('Votre prénom'),
                    controller: prenomController,
                    action: TextInputAction.next,
                  ),
                ];

                if (compact) {
                  return Column(
                    children: [fields[0], SizedBox(height: 22), fields[1]],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    SizedBox(width: 24),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            ),
            SizedBox(height: 22),
            _FieldLabel('Email'),
            SizedBox(height: 10),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                hint: AppLocalizations.globalText('exemple@email.com'),
                prefixIcon: Icons.email_outlined,
              ),
            ),
            SizedBox(height: 22),
            _FieldLabel('Mot de passe'),
            SizedBox(height: 10),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                hint: '••••••••',
                prefixIcon: Icons.lock_outline,
                suffix: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  color: Color(0xFF8A96AA),
                  splashRadius: 18,
                ),
              ),
            ),
            SizedBox(height: 22),
            _FieldLabel('Confirmer le mot de passe'),
            SizedBox(height: 10),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onRegister(),
              decoration: _inputDecoration(
                hint: '••••••••',
                prefixIcon: Icons.lock_outline,
                suffix: IconButton(
                  onPressed: onToggleConfirmPassword,
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  color: Color(0xFF8A96AA),
                  splashRadius: 18,
                ),
              ),
            ),
            SizedBox(height: 24),
            _TermsRow(
              acceptedTerms: acceptedTerms,
              onChanged: onTermsChanged,
              onConditionsTap: onConditionsTap,
              onPrivacyTap: onPrivacyTap,
            ),
            SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onRegister,
                icon: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.person_add_alt_1_outlined, size: 20),
                label: Text(isLoading ? 'Création...' : 'Créer mon compte'),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _RegisterScreenState._primaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _RegisterScreenState._primaryBlue
                      .withValues(alpha: .7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(height: 32),
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: _RegisterScreenState._textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(text: 'Vous avez déjà un compte ?  '),
                    TextSpan(
                      text: 'Se connecter',
                      style: TextStyle(
                        color: _RegisterScreenState._primaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = onLoginTap,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Color(0xFF9AA4B7),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(prefixIcon, color: Color(0xFF6F7C91), size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: Color(0xFFD8DEE9), width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(
          color: _RegisterScreenState._primaryBlue,
          width: 1.5,
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  _NameField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.action,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputAction action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        SizedBox(height: 10),
        TextFormField(
          controller: controller,
          textInputAction: action,
          decoration: _registerInputDecoration(
            hint: hint,
            prefixIcon: Icons.person_outline,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _RegisterScreenState._textDark,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

InputDecoration _registerInputDecoration({
  required String hint,
  required IconData prefixIcon,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: Color(0xFF9AA4B7),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    prefixIcon: Icon(prefixIcon, color: Color(0xFF6F7C91), size: 21),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(color: Color(0xFFD8DEE9), width: 1.4),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: BorderSide(
        color: _RegisterScreenState._primaryBlue,
        width: 1.5,
      ),
    ),
  );
}

class _TermsRow extends StatelessWidget {
  _TermsRow({
    required this.acceptedTerms,
    required this.onChanged,
    required this.onConditionsTap,
    required this.onPrivacyTap,
  });

  final bool acceptedTerms;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onConditionsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: acceptedTerms,
            onChanged: onChanged,
            side: BorderSide(color: Color(0xFFB8C2D4), width: 1.6),
            activeColor: _RegisterScreenState._primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: _RegisterScreenState._textMuted,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(text: "J'accepte les "),
                TextSpan(
                  text: "conditions d'utilisation",
                  style: TextStyle(
                    color: _RegisterScreenState._primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onConditionsTap,
                ),
                TextSpan(text: ' et la '),
                TextSpan(
                  text: 'politique de confidentialité',
                  style: TextStyle(
                    color: _RegisterScreenState._primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onPrivacyTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  _AvatarHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF193A70).withValues(alpha: .12),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.person,
                color: _RegisterScreenState._primaryBlue,
                size: 48,
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 10,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _RegisterScreenState._primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPattern extends StatelessWidget {
  _DotPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(128, 100), painter: _DotPatternPainter());
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB7C7DE).withValues(alpha: .38)
      ..isAntiAlias = true;

    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 12; col++) {
        canvas.drawCircle(Offset(col * 11.0, row * 11.0), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
