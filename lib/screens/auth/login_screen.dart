import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../api_service.dart';
import '../../auth/current_user_session.dart';
import '../../data/mock_presales_data.dart';
import '../../database/database_helper.dart';
import '../../services/password_reset_service.dart';
import '../../settings/app_appearance_controller.dart';

enum UserRole { commercial, manager, admin }

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  List<_LocalSession> _rememberedSessions = const [];
  bool _isApplyingRememberedLogin = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  static const _primaryBlue = Color(0xFF2674F8);
  static const _violet = Color(0xFF8CCB2F);
  static const _premiumText = Color(0xFF24301F);
  static const _premiumMuted = Color(0xFF7D8677);
  static const _premiumBorder = Color(0xFFE2E6DC);
  static const _textDark = Color(0xFF18213A);
  static const _textMuted = Color(0xFF69758C);
  static const _fieldBorder = Color(0xFFE4E9F3);
  static const _danger = Color(0xFFE24444);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_autocompleteRememberedLogin);
    _restoreRememberedLogin();
  }

  @override
  void dispose() {
    _emailController.removeListener(_autocompleteRememberedLogin);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreRememberedLogin() async {
    final sessions = await _LocalSessionStore.loadAll();
    if (!mounted) return;

    setState(() => _rememberedSessions = sessions);
  }

  void _autocompleteRememberedLogin() {
    if (_isApplyingRememberedLogin) return;

    final typedEmail = _emailController.text.trim().toLowerCase();
    if (typedEmail.length < 4) return;

    final session = _rememberedSessions.cast<_LocalSession?>().firstWhere((
      session,
    ) {
      final savedEmail = session?.email.trim().toLowerCase() ?? '';
      return savedEmail.startsWith(typedEmail) && savedEmail != typedEmail;
    }, orElse: () => null);
    if (session == null) return;

    _isApplyingRememberedLogin = true;
    _emailController.value = TextEditingValue(
      text: session.email,
      selection: TextSelection.collapsed(offset: session.email.length),
    );
    if (session.password.isNotEmpty) {
      _passwordController.text = session.password;
    }
    if (_emailError != null || _passwordError != null) {
      setState(() {
        _emailError = null;
        _passwordError = null;
      });
    }
    _isApplyingRememberedLogin = false;
  }

  Future<void> _login() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Veuillez remplir tous les champs');
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Adresse email invalide');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authResult = await _authenticate(email, password);
      if (!mounted) return;

      if (authResult == null) {
        setState(() => _passwordError = 'Mot de passe incorrect');
        return;
      }

      if (_rememberMe) {
        await _LocalSessionStore.save(
          email: email,
          password: password,
          rememberMe: true,
        );
        if (mounted) {
          setState(() {
            _rememberedSessions = _LocalSessionStore.mergeSession(
              _rememberedSessions,
              _LocalSession(email: email, password: password, rememberMe: true),
            );
          });
        }
      }

      CurrentUserSession.signIn(authResult.user);
      await AppAppearanceController.instance.applyUser(authResult.user);

      if (!mounted) return;
      final route = switch (authResult.role) {
        UserRole.commercial => '/home-commercial',
        UserRole.manager => '/home-manager',
        UserRole.admin => '/dashboard-admin',
      };
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (route) => false,
        arguments: {
          'id': authResult.user.id,
          'email': authResult.email,
          'name': authResult.displayName,
          'role': authResult.user.role.name.toUpperCase(),
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Erreur de connexion: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage('Erreur de connexion. Réessayez plus tard.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<_AuthResult?> _authenticate(String email, String password) async {
    try {
      final apiUser = await ApiService.login(email, password);
      final roleValue = apiUser['role']?.toString().toUpperCase();
      final role = switch (roleValue) {
        'ADMIN' => UserRole.admin,
        'MANAGER' => UserRole.manager,
        _ => UserRole.commercial,
      };
      final displayName = [
        apiUser['prenom']?.toString().trim() ?? '',
        apiUser['nom']?.toString().trim() ?? '',
      ].where((part) => part.isNotEmpty).join(' ').trim();
      final fallbackName = apiUser['name']?.toString().trim() ?? '';
      return _AuthResult(
        user: AuthenticatedUser(
          id: apiUser['id'] is int ? apiUser['id'] as int : 0,
          fullName: displayName.isNotEmpty
              ? displayName
              : fallbackName.isNotEmpty
              ? fallbackName
              : email,
          email: apiUser['email']?.toString() ?? email,
          role: switch (role) {
            UserRole.commercial => MockUserRole.commercial,
            UserRole.manager => MockUserRole.manager,
            UserRole.admin => MockUserRole.admin,
          },
          phone: apiUser['phone']?.toString() ?? '',
        ),
        role: role,
        displayName: displayName.isNotEmpty
            ? displayName
            : fallbackName.isNotEmpty
            ? fallbackName
            : email,
        email: apiUser['email']?.toString() ?? email,
      );
    } catch (error) {
      debugPrint('Authentification API indisponible/echec: $error');
    }

    final mockUser = MockPreSalesData.userByEmail(email);
    if (mockUser != null) {
      if (PasswordResetService.passwordFor(email, mockUser.password) !=
          password) {
        return null;
      }
      return _AuthResult(
        user: AuthenticatedUser.fromMock(mockUser),
        role: switch (mockUser.role) {
          MockUserRole.commercial => UserRole.commercial,
          MockUserRole.manager => UserRole.manager,
          MockUserRole.admin => UserRole.admin,
        },
        displayName: mockUser.name,
        email: mockUser.email,
      );
    }

    final db = await DatabaseHelper.instance.database;
    final users = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );

    if (users.isEmpty) return null;

    final savedPassword = users.first['password']?.toString() ?? '';
    if (savedPassword != password) return null;

    final roleValue = users.first['role']?.toString().toUpperCase();
    final role = switch (roleValue) {
      'ADMIN' => UserRole.admin,
      'MANAGER' => UserRole.manager,
      _ => UserRole.commercial,
    };
    final firstName = users.first['prenom']?.toString().trim() ?? '';
    final lastName = users.first['nom']?.toString().trim() ?? '';
    final displayName = firstName.isNotEmpty
        ? firstName
        : lastName.isNotEmpty
        ? lastName
        : 'Commercial';
    return _AuthResult(
      user: AuthenticatedUser(
        id: users.first['id'] is int ? users.first['id'] as int : 0,
        fullName: displayName,
        email: email,
        role: switch (role) {
          UserRole.commercial => MockUserRole.commercial,
          UserRole.manager => MockUserRole.manager,
          UserRole.admin => MockUserRole.admin,
        },
      ),
      role: role,
      displayName: displayName,
      email: email,
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  void _openForgotPassword() {
    Navigator.pushNamed(context, '/forgot-password');
  }

  Future<void> _onRememberChanged(bool? value) async {
    final remember = value ?? false;
    setState(() => _rememberMe = remember);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _LoginScreenState._textDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeHeight = media.size.height - media.padding.vertical;
    final scale = (safeHeight / 1040).clamp(.5, 1.0).toDouble();
    final fieldGap = 22.0 * scale;

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F2),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF5F5F2),
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: .86,
                  colors: [Colors.white, Color(0xFFF5F5F2)],
                  stops: [.0, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _LoginLeavesPainter())),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24 * scale),
              child: DefaultTextStyle.merge(
                style: TextStyle(fontFamily: 'Roboto'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 50 * scale),
                        _TeaSudLogo(scale: scale),
                        SizedBox(height: 16 * scale),
                        Text(
                          AppLocalizations.globalText(
                            'QUALITÉ • CONFIANCE • PERFORMANCE',
                          ),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Color(0xFF163B1B),
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2 * scale,
                          ),
                        ),
                        SizedBox(height: 30 * scale),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(30 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(35 * scale),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .08),
                            blurRadius: 30 * scale,
                            offset: Offset(0, 10 * scale),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 100 * scale,
                            height: 100 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF1F6E8),
                            ),
                            child: Icon(
                              Icons.person_outline,
                              color: Color(0xFF1E7D1A),
                              size: 45 * scale,
                            ),
                          ),
                          SizedBox(height: 26 * scale),
                          Text(
                            AppLocalizations.globalText('Bienvenue !'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Color(0xFF0F1737),
                              fontSize: 34 * scale,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(height: 12 * scale),
                          Text(
                            AppLocalizations.globalText(
                              'Connectez-vous pour accéder à votre espace',
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Color(0xFF7B8398),
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 30 * scale),
                          _AuthField(
                            controller: _emailController,
                            label: AppLocalizations.globalText('Email'),
                            hintText: AppLocalizations.globalText(
                              'Entrez votre email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            errorText: _emailError,
                            prefixIcon: Icons.mail_outline,
                            darkMode: true,
                            scale: scale,
                          ),
                          SizedBox(height: fieldGap),
                          _AuthField(
                            controller: _passwordController,
                            label: AppLocalizations.globalText('Mot de passe'),
                            hintText: AppLocalizations.globalText(
                              'Entrez votre mot de passe',
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            errorText: _passwordError,
                            onSubmitted: (_) => _login(),
                            prefixIcon: Icons.lock_outline,
                            darkMode: true,
                            scale: scale,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 30 * scale,
                              ),
                              color: Color(0xFF8A8F84),
                              splashRadius: 20 * scale,
                              tooltip: _obscurePassword
                                  ? 'Afficher'
                                  : 'Masquer',
                            ),
                          ),
                          SizedBox(height: 24 * scale),
                          _PremiumRememberForgotRow(
                            rememberMe: _rememberMe,
                            onRememberChanged: _onRememberChanged,
                            onForgotPassword: _openForgotPassword,
                            scale: scale,
                          ),
                          SizedBox(height: 26 * scale),
                          _PremiumLoginButton(
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : _login,
                            scale: scale,
                          ),
                          SizedBox(height: 28 * scale),
                          _SecureLoginFooter(scale: scale),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: 24 * scale,
                        bottom: 18 * scale,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.globalText(
                              '© 2026 TeaSud. Tous droits réservés.',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Color(0xFF6E726B),
                              fontSize: 15 * scale,
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          Text(
                            AppLocalizations.globalText('Version 1.0.0'),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Color(0xFF4A5A4A),
                              fontSize: 15 * scale,
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
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
}

class _TeaSudLogo extends StatelessWidget {
  _TeaSudLogo({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220 * scale,
      height: 80 * scale,
      child: Image.asset(
        'assets/images/teasud_logo.png',
        width: 220 * scale,
        height: 80 * scale,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _LoginLeavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFDCE6D3).withValues(alpha: .25)
      ..style = PaintingStyle.fill;

    void leaf(Offset center, double width, double height, double angle) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, -height / 2)
        ..cubicTo(width / 2, -height / 5, width / 2, height / 4, 0, height / 2)
        ..cubicTo(
          -width / 2,
          height / 4,
          -width / 2,
          -height / 5,
          0,
          -height / 2,
        );
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    leaf(Offset(size.width - 42, 35), 44, 116, -.18);
    leaf(Offset(size.width - 82, 86), 35, 88, -1.05);
    leaf(Offset(size.width - 27, 151), 39, 108, .62);
    leaf(Offset(size.width - 71, 190), 32, 92, 1.1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PremiumLoginButton extends StatelessWidget {
  _PremiumLoginButton({
    required this.isLoading,
    required this.onPressed,
    this.scale = 1,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38 * scale),
        gradient: LinearGradient(
          colors: onPressed == null
              ? [
                  Color(0xFFA7DD1A).withValues(alpha: .55),
                  Color(0xFF0F8D14).withValues(alpha: .55),
                ]
              : [Color(0xFFA7DD1A), Color(0xFF0F8D14)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x400F8D14),
            blurRadius: 30 * scale,
            offset: Offset(0, 15 * scale),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(38 * scale),
          child: SizedBox(
            height: 74 * scale,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22 * scale,
                      height: 22 * scale,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Spacer(),
                        Text(
                          AppLocalizations.globalText('Se connecter'),
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontSize: 20 * scale,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Container(
                                width: 58 * scale,
                                height: 58 * scale,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(
                                    0xFF0B7A12,
                                  ).withValues(alpha: .4),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 34 * scale,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumRememberForgotRow extends StatelessWidget {
  _PremiumRememberForgotRow({
    required this.rememberMe,
    required this.onRememberChanged,
    required this.onForgotPassword,
    this.scale = 1,
  });

  final bool rememberMe;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onForgotPassword;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20 * scale,
          height: 20 * scale,
          child: Checkbox(
            value: rememberMe,
            onChanged: onRememberChanged,
            activeColor: Color(0xFF1E7D1A),
            checkColor: Colors.white,
            side: BorderSide(color: Color(0xFFD8D8D8), width: 1.6 * scale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5 * scale),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Text(
            AppLocalizations.globalText('Se souvenir de moi'),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Color(0xFF222222),
              fontSize: 15 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextButton(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size(0, 28 * scale),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: Color(0xFF7AC91F),
          ),
          child: Text(
            AppLocalizations.globalText('Mot de passe oubli\u00E9 ?'),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SecureLoginFooter extends StatelessWidget {
  _SecureLoginFooter({this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFE6E6E6), thickness: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18 * scale),
              child: Text(
                AppLocalizations.globalText('OU'),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Color(0xFF7A7A6A),
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFE6E6E6), thickness: 1)),
          ],
        ),
        SizedBox(height: 22 * scale),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              color: Color(0xFF1E7D1A),
              size: 26 * scale,
            ),
            SizedBox(width: 10 * scale),
            Text(
              AppLocalizations.globalText('Connexion sécurisée'),
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Color(0xFF4B664B),
                fontSize: 16 * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final email = _emailController.text.trim().toLowerCase();
    setState(() => _emailError = null);

    if (email.isEmpty) {
      setState(() => _emailError = 'Veuillez saisir votre adresse e-mail.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _emailError = 'Adresse e-mail invalide.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await PasswordResetService.forgotPassword(email);
      if (!mounted) return;
      _showMessage('Code envoyé avec succès.');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyResetCodeScreen(email: email)),
      );
    } on PasswordResetException catch (error) {
      if (mounted) setState(() => _emailError = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    return;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _LoginScreenState._textDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1A4C93).withValues(alpha: .10),
                      blurRadius: 28,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 24, 22, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded),
                        color: _LoginScreenState._textDark,
                        tooltip: 'Retour',
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppLocalizations.globalText(
                          'Mot de passe oubli\u00E9 ?',
                        ),
                        style: TextStyle(
                          color: _LoginScreenState._textDark,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        AppLocalizations.globalText(
                          'Nous enverrons un code de vérification à l’adresse de récupération configurée pour votre compte PreSales.',
                        ),
                        style: TextStyle(
                          color: _LoginScreenState._textMuted,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 24),
                      _AuthField(
                        controller: _emailController,
                        label: AppLocalizations.globalText(
                          'E-mail professionnel',
                        ),
                        hintText: AppLocalizations.globalText(
                          'exemple@presales.ma',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        errorText: _emailError,
                        onSubmitted: (_) => _continue(),
                      ),
                      SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _LoginScreenState._primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            textStyle: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(AppLocalizations.globalText('Suivant')),
                        ),
                      ),
                      SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(AppLocalizations.globalText('Retour')),
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

class ResetPasswordScreen extends StatelessWidget {
  ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return ForgotPasswordScreen();
  }
}

class VerifyResetCodeScreen extends StatefulWidget {
  VerifyResetCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final _codeController = TextEditingController();
  String? _codeError;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _verify() {
    final code = _codeController.text.trim();
    setState(() => _codeError = null);
    if (code.length != 6) {
      setState(() => _codeError = 'Code de vérification incorrect.');
      return;
    }

    try {
      PasswordResetService.verifyResetCode(email: widget.email, code: code);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewPasswordScreen(email: widget.email, code: code),
        ),
      );
    } on PasswordResetException catch (error) {
      setState(() => _codeError = error.message);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _codeError = null;
    });
    try {
      await PasswordResetService.forgotPassword(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.globalText('Code envoyé avec succès.'),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _LoginScreenState._textDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    } on PasswordResetException catch (error) {
      if (mounted) setState(() => _codeError = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RecoveryShell(
      title: AppLocalizations.globalText('Saisissez le code à 6 chiffres'),
      subtitle: AppLocalizations.globalText(
        'Un code de vérification a été envoyé à l’adresse email de récupération.',
      ),
      children: [
        Center(
          child: Text(
            _maskEmail(widget.email),
            style: TextStyle(
              color: _LoginScreenState._primaryBlue,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(height: 18),
        _AuthField(
          controller: _codeController,
          label: AppLocalizations.globalText('Code OTP'),
          hintText: '123456',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          errorText: _codeError,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _verify(),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          alignment: WrapAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.globalText('Changer l’adresse e-mail'),
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _resendCode,
              child: Text(AppLocalizations.globalText('Renvoyer le code')),
            ),
          ],
        ),
        SizedBox(height: 18),
        _PrimaryAuthButton(
          text: 'Vérifier',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verify,
        ),
      ],
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return email;
    return '${parts.first[0]}****@${parts.last}';
  }
}

class NewPasswordScreen extends StatefulWidget {
  NewPasswordScreen({super.key, required this.email, required this.code});

  final String email;
  final String code;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _passwordError;
  String? _confirmError;
  bool _obscurePassword = true;
  bool _disconnectDevices = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    setState(() {
      _passwordError = null;
      _confirmError = null;
    });

    if (password.length < 8) {
      setState(() => _passwordError = 'Mot de passe trop court.');
      return;
    }
    if (password != confirm) {
      setState(() => _confirmError = 'Les mots de passe ne correspondent pas.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      PasswordResetService.resetPassword(
        email: widget.email,
        code: widget.code,
        newPassword: password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.globalText('Mot de passe modifié avec succès.'),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _LoginScreenState._textDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } on PasswordResetException catch (error) {
      if (mounted) setState(() => _passwordError = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RecoveryShell(
      title: AppLocalizations.globalText('Choisissez un nouveau mot de passe'),
      subtitle: AppLocalizations.globalText(
        'Pour sécuriser votre compte, choisissez un mot de passe fort contenant au moins huit caractères.',
      ),
      children: [
        _AuthField(
          controller: _passwordController,
          label: AppLocalizations.globalText('Nouveau mot de passe'),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          errorText: _passwordError,
          suffixIcon: _PasswordVisibilityButton(
            obscurePassword: _obscurePassword,
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
        ),
        SizedBox(height: 14),
        _AuthField(
          controller: _confirmController,
          label: AppLocalizations.globalText(
            'Confirmer le nouveau mot de passe',
          ),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          errorText: _confirmError,
          suffixIcon: _PasswordVisibilityButton(
            obscurePassword: _obscurePassword,
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          onSubmitted: (_) => _save(),
        ),
        SizedBox(height: 14),
        CheckboxListTile(
          value: _disconnectDevices,
          onChanged: (value) {
            setState(() => _disconnectDevices = value ?? true);
          },
          activeColor: _LoginScreenState._primaryBlue,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            AppLocalizations.globalText(
              'Déconnecter tous les appareils après changement du mot de passe',
            ),
            style: TextStyle(
              color: _LoginScreenState._textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: 18),
        _PrimaryAuthButton(
          text: 'Enregistrer',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _save,
        ),
      ],
    );
  }
}

class _RecoveryShell extends StatelessWidget {
  _RecoveryShell({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1A4C93).withValues(alpha: .10),
                      blurRadius: 28,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 24, 22, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded),
                        color: _LoginScreenState._textDark,
                        tooltip: 'Retour',
                      ),
                      SizedBox(height: 16),
                      Text(
                        title,
                        style: TextStyle(
                          color: _LoginScreenState._textDark,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _LoginScreenState._textMuted,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 24),
                      ...children,
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

class _PrimaryAuthButton extends StatelessWidget {
  _PrimaryAuthButton({
    required this.text,
    required this.isLoading,
    required this.onPressed,
  });

  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _LoginScreenState._primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _LoginScreenState._primaryBlue.withValues(
            alpha: .65,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: TextStyle(fontWeight: FontWeight.w900),
        ),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(text),
      ),
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  _PasswordVisibilityButton({
    required this.obscurePassword,
    required this.onPressed,
  });

  final bool obscurePassword;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        size: 19,
      ),
      color: _LoginScreenState._textMuted,
      splashRadius: 18,
      tooltip: obscurePassword ? 'Afficher' : 'Masquer',
    );
  }
}

class _AuthField extends StatelessWidget {
  _AuthField({
    required this.controller,
    required this.label,
    required this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    this.hintText,
    this.maxLength,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.onSubmitted,
    this.darkMode = false,
    this.scale = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;
  final String? hintText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final bool darkMode;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final textColor = darkMode
        ? _LoginScreenState._premiumText
        : _LoginScreenState._textDark;
    final mutedColor = darkMode
        ? _LoginScreenState._premiumMuted
        : _LoginScreenState._textMuted;
    final fillColor = Colors.white;
    final borderColor = darkMode
        ? _LoginScreenState._premiumBorder
        : _LoginScreenState._fieldBorder;
    final focusedBorderColor = darkMode
        ? _LoginScreenState._violet
        : _LoginScreenState._primaryBlue;

    if (darkMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Color(0xFF1E7D1A),
              fontSize: 15 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12 * scale),
          Container(
            height: 72 * scale,
            decoration: BoxDecoration(
              color: Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(22 * scale),
              border: Border.all(
                color: errorText == null
                    ? Color(0xFFE5E7E1)
                    : _LoginScreenState._danger,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .025),
                  blurRadius: 10 * scale,
                  offset: Offset(0, 4 * scale),
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 0),
                  child: Container(
                    width: 56 * scale,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Color(0xFFF3F6EA),
                      borderRadius: BorderRadius.circular(18 * scale),
                    ),
                    child: Icon(
                      prefixIcon,
                      color: Color(0xFF1E7D1A),
                      size: 30 * scale,
                    ),
                  ),
                ),
                SizedBox(width: 22 * scale),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    obscureText: obscureText,
                    textInputAction: textInputAction,
                    onSubmitted: onSubmitted,
                    maxLength: maxLength,
                    inputFormatters: inputFormatters,
                    cursorColor: Color(0xFF1E7D1A),
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFF0F1737),
                      fontSize: 17 * scale,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        fontFamily: 'Roboto',
                        color: Color(0xFF8A8F84),
                        fontSize: 17 * scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ).copyWith(counterText: ''),
                  ),
                ),
                if (suffixIcon != null)
                  SizedBox(
                    width: 56 * scale,
                    child: Center(child: suffixIcon),
                  ),
              ],
            ),
          ),
          if (errorText != null) ...[
            SizedBox(height: 6 * scale),
            Text(
              errorText!,
              style: TextStyle(
                fontFamily: 'Roboto',
                color: _LoginScreenState._danger,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      );
    }
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        errorText: errorText,
        counterText: '',
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: _LoginScreenState._violet, size: 21),
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(
          color: mutedColor,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: TextStyle(
          color: mutedColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: focusedBorderColor, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: _LoginScreenState._danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: _LoginScreenState._danger),
        ),
      ),
    );
  }
}

class _AuthResult {
  _AuthResult({
    required this.user,
    required this.role,
    required this.displayName,
    required this.email,
  });

  final AuthenticatedUser user;
  final UserRole role;
  final String displayName;
  final String email;
}

class _LocalSession {
  _LocalSession({
    required this.email,
    required this.password,
    required this.rememberMe,
  });

  final String email;
  final String password;
  final bool rememberMe;
}

class _LocalSessionStore {
  static final _fileName = 'presales_session.json';

  static List<_LocalSession> mergeSession(
    List<_LocalSession> sessions,
    _LocalSession next,
  ) {
    final normalizedEmail = next.email.trim().toLowerCase();
    final merged = <_LocalSession>[
      next,
      for (final session in sessions)
        if (session.email.trim().toLowerCase() != normalizedEmail) session,
    ];
    return merged;
  }

  static Future<void> save({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final sessions = mergeSession(
      await loadAll(),
      _LocalSession(email: email, password: password, rememberMe: rememberMe),
    );
    final file = await _file();
    await file.writeAsString(
      jsonEncode({
        'sessions': [
          for (final session in sessions)
            {
              'email': session.email,
              'password': session.password,
              'rememberMe': session.rememberMe,
            },
        ],
      }),
    );
  }

  static Future<List<_LocalSession>> loadAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];

      final payload = jsonDecode(await file.readAsString());
      if (payload is! Map<String, dynamic>) return const [];

      final sessionsPayload = payload['sessions'];
      if (sessionsPayload is List) {
        return [
              for (final item in sessionsPayload)
                if (item is Map)
                  _LocalSession(
                    email: item['email']?.toString() ?? '',
                    password: item['password']?.toString() ?? '',
                    rememberMe: item['rememberMe'] == true,
                  ),
            ]
            .where((session) => session.rememberMe && session.email.isNotEmpty)
            .toList();
      }

      final legacySession = _LocalSession(
        email: payload['email']?.toString() ?? '',
        password: payload['password']?.toString() ?? '',
        rememberMe: payload['rememberMe'] == true,
      );
      if (!legacySession.rememberMe || legacySession.email.isEmpty) {
        return const [];
      }
      return [legacySession];
    } catch (_) {
      return const [];
    }
  }

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }
}
