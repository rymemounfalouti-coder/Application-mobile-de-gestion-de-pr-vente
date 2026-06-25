import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/current_user_session.dart';
import '../../data/mock_presales_data.dart';
import '../../l10n/app_locale_controller.dart';
import '../../l10n/app_localizations.dart';
import 'language_preferences_screen.dart';
import 'notification_preferences_screen.dart';
import 'appearance_screen.dart';

Color primaryBlue = Color(0xFF2563EB);
Color textDark = Color(0xFF0F172A);
Color textMuted = Color(0xFF64748B);
Color surfaceBg = Color(0xFFF8FAFC);
Color cardBg = Color(0xFFFFFFFF);
Color errorRed = Color(0xFFEF4444);
double borderRadiusLarge = 20.0;

void syncProfileTheme(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  textDark = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  textMuted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
  surfaceBg = isDark ? Colors.black : const Color(0xFFF8FAFC);
  cardBg = isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
}

bool _isProfileDarkMode() => cardBg != Colors.white;

Color _profileBorderColor() {
  return _isProfileDarkMode()
      ? const Color(0xFF334155)
      : const Color(0xFFE8EEF7);
}

Color _profileShadowColor([double lightAlpha = .055]) {
  return _isProfileDarkMode()
      ? Colors.black.withValues(alpha: .22)
      : Colors.black.withValues(alpha: lightAlpha);
}

class ProfileCommercialScreen extends StatefulWidget {
  ProfileCommercialScreen({
    super.key,
    required this.user,
    required this.fallbackName,
    required this.fallbackEmail,
    required this.unreadNotificationCount,
    required this.onNotificationsTap,
    required this.onNavigate,
  });

  final MockUserProfile? user;
  final String fallbackName;
  final String fallbackEmail;
  final int unreadNotificationCount;
  final VoidCallback onNotificationsTap;
  final ValueChanged<int> onNavigate;

  @override
  State<ProfileCommercialScreen> createState() =>
      _ProfileCommercialScreenState();
}

class _ProfileCommercialScreenState extends State<ProfileCommercialScreen> {
  final String _selectedTheme = 'Clair';
  late MockUserProfile? userProfile;

  @override
  void initState() {
    super.initState();
    userProfile = widget.user;
  }

  String get _name {
    final value = userProfile?.name ?? widget.fallbackName;
    return value.trim().isEmpty ? 'Commercial PreSales' : value;
  }

  String get _email {
    final value = userProfile?.email ?? widget.fallbackEmail;
    return value.trim().isEmpty ? 'commercial@presales.ma' : value;
  }

  String get _phone => userProfile?.phone ?? 'Non renseigné';

  String get _company => 'Ryme Distribution';

  String _languageName(AppLocalizations l10n) {
    return switch (AppLocaleController.instance.languageCode) {
      'en' => l10n.englishNative,
      'ar' => l10n.arabicNative,
      _ => l10n.frenchNative,
    };
  }

  @override
  Widget build(BuildContext context) {
    syncProfileTheme(context);
    final l10n = context.l10n;
    return Container(
      color: surfaceBg,
      child: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          // Header avec titre et icône notifications
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.profile,
                            style: TextStyle(
                              color: textDark,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            l10n.profileSubtitle,
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: widget.onNotificationsTap,
                            icon: Icon(Icons.notifications_none_rounded),
                            color: textDark,
                          ),
                        ),
                        if (widget.unreadNotificationCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              constraints: BoxConstraints(minWidth: 12),
                              height: 12,
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: errorRed,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  widget.unreadNotificationCount > 9
                                      ? '9+'
                                      : '${widget.unreadNotificationCount}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ]),
            ),
          ),

          // Section Profil Card
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProfileCard(),
                SizedBox(height: 28),
              ]),
            ),
          ),

          // Section Mon Compte
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    l10n.myAccount,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildMenuSection([
                  _MenuItem(
                    icon: Icons.person_outline_rounded,
                    title: l10n.personalInformation,
                    subtitle: l10n.manageProfileInfo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PremiumPersonalInfoScreen(
                            user: userProfile,
                            fallbackName: _name,
                            fallbackEmail: _email,
                            fallbackPhone: _phone,
                          ),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.lock_outline_rounded,
                    title: l10n.security,
                    subtitle: l10n.securitySubtitle,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PremiumSecurityScreen(user: userProfile),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.notifications_outlined,
                    title: l10n.notifications,
                    subtitle: l10n.notificationPreferences,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationPreferencesScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.language_rounded,
                    title: l10n.language,
                    subtitle: _languageName(l10n),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LanguagePreferencesScreen(),
                        ),
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  _MenuItem(
                    icon: Icons.palette_outlined,
                    title: l10n.appearance,
                    subtitle: _selectedTheme == 'Clair'
                        ? l10n.themeLight
                        : 'Thème $_selectedTheme',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AppearanceScreen(),
                        ),
                      );
                    },
                  ),
                ]),
                SizedBox(height: 28),
              ]),
            ),
          ),

          // Section À Propos
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    AppLocalizations.globalText('À propos'),
                    style: TextStyle(
                      color: textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildMenuSection([
                  _MenuItem(
                    icon: Icons.info_outline_rounded,
                    title: AppLocalizations.globalText(
                      'À propos de l\'application',
                    ),
                    subtitle: AppLocalizations.globalText('Version 1.0.0'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfessionalAboutAppScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.security_rounded,
                    title: AppLocalizations.globalText('Confidentialité'),
                    subtitle: AppLocalizations.globalText(
                      'Politique de confidentialité',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfessionalPrivacyScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    icon: Icons.description_outlined,
                    title: AppLocalizations.globalText(
                      'Conditions d\'utilisation',
                    ),
                    subtitle: AppLocalizations.globalText(
                      'Lire les conditions',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfessionalTermsScreen(),
                        ),
                      );
                    },
                  ),
                ]),
                SizedBox(height: 24),
              ]),
            ),
          ),

          // Bouton Déconnexion
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                GestureDetector(
                  onTap: () => _confirmLogout(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(borderRadiusLarge),
                      border: Border.all(
                        color: errorRed.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: errorRed, size: 20),
                        SizedBox(width: 12),
                        Text(
                          AppLocalizations.globalText('Se déconnecter'),
                          style: TextStyle(
                            color: errorRed,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryBlue, primaryBlue.withValues(alpha: 0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _name
                        .split(' ')
                        .map((word) => word.isNotEmpty ? word[0] : '')
                        .join()
                        .toUpperCase()
                        .substring(0, 2),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () {
                    _showSnackbar(context, 'Changement de photo à venir');
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 20),
          // Informations
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  AppLocalizations.globalText('Commercial'),
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  _email,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  _company,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textMuted, size: 24),
        ],
      ),
    );
  }

  Widget _buildMenuSection(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(
          items.length,
          (index) => Column(
            children: [
              _buildMenuItem(items[index]),
              if (index < items.length - 1)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: Colors.grey.withValues(alpha: 0.1),
                    height: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(item.icon, color: primaryBlue, size: 24),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusLarge),
          ),
          title: Text(
            AppLocalizations.globalText('Déconnexion'),
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            AppLocalizations.globalText(
              'Voulez-vous vraiment vous déconnecter ?',
            ),
            style: TextStyle(color: textMuted, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                AppLocalizations.globalText('Annuler'),
                style: TextStyle(color: textDark, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                AppLocalizations.globalText('Confirmer'),
                style: TextStyle(color: errorRed, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      CurrentUserSession.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class PremiumPersonalInfoScreen extends StatefulWidget {
  PremiumPersonalInfoScreen({
    super.key,
    required this.user,
    required this.fallbackName,
    required this.fallbackEmail,
    required this.fallbackPhone,
  });

  final MockUserProfile? user;
  final String fallbackName;
  final String fallbackEmail;
  final String fallbackPhone;

  @override
  State<PremiumPersonalInfoScreen> createState() =>
      _PremiumPersonalInfoScreenState();
}

class _PremiumPersonalInfoScreenState extends State<PremiumPersonalInfoScreen> {
  late String _fullName;
  late String _email;
  late String _phone;
  late DateTime _birthDate;
  late String _address;
  late String _cin;
  late String _nationality;
  late String _language;
  late String _company;
  String? _avatarLabel;

  @override
  void initState() {
    super.initState();
    _fullName = (widget.user?.name ?? widget.fallbackName).trim();
    if (_fullName.isEmpty) _fullName = 'Commercial PreSales';
    _email = (widget.user?.email ?? widget.fallbackEmail).trim();
    _phone = (widget.user?.phone ?? widget.fallbackPhone).trim();
    _birthDate = DateTime(1992, 4, 15);
    _address = 'Casablanca, Maroc';
    _cin = 'AB123456';
    _nationality = 'Marocaine';
    _language = 'Fran\u00E7ais';
    _company = 'Ryme Distribution';
  }

  String get _role => switch (widget.user?.role) {
    MockUserRole.manager => 'Manager',
    MockUserRole.admin => 'Administrateur',
    _ => 'Commercial',
  };

  String get _initials {
    final parts = _fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'PS';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get _formattedBirthDate {
    final day = _birthDate.day.toString().padLeft(2, '0');
    final month = _birthDate.month.toString().padLeft(2, '0');
    return '$day/$month/${_birthDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    syncProfileTheme(context);
    return Scaffold(
      backgroundColor: surfaceBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 430
                ? 430.0
                : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _profileShadowColor(.05),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(24, 18, 24, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _PremiumInfoHeader(
                                  onBack: () => Navigator.pop(context),
                                ),
                                SizedBox(height: 22),
                                _PremiumInfoUserCard(
                                  initials: _avatarLabel ?? _initials,
                                  fullName: _fullName,
                                  role: _role,
                                  email: _email,
                                  company: _company,
                                  onCameraTap: _showAvatarOptions,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  AppLocalizations.globalText(
                                    'Ces informations seront utilis\u00E9es dans votre profil\net vos documents.',
                                  ),
                                  style: TextStyle(
                                    color: textMuted,
                                    fontSize: 15,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 22),
                                Text(
                                  AppLocalizations.globalText(
                                    'Informations personnelles',
                                  ),
                                  style: TextStyle(
                                    color: textDark,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 12),
                                _PremiumInfoCard(
                                  rows: [
                                    _PremiumInfoRowData(
                                      icon: Icons.person_rounded,
                                      label: AppLocalizations.globalText(
                                        'Nom complet',
                                      ),
                                      value: _fullName,
                                      trailingIcon: Icons.edit_rounded,
                                      onTap: () => _editText(
                                        title: AppLocalizations.globalText(
                                          'Nom complet',
                                        ),
                                        initialValue: _fullName,
                                        icon: Icons.person_outline_rounded,
                                        validator: _requiredValidator,
                                        onSaved: (value) =>
                                            setState(() => _fullName = value),
                                      ),
                                    ),
                                    _PremiumInfoRowData(
                                      icon: Icons.mail_rounded,
                                      label: AppLocalizations.globalText(
                                        'Email',
                                      ),
                                      value: _email,
                                      trailingIcon: Icons.edit_rounded,
                                      onTap: () => _editText(
                                        title: AppLocalizations.globalText(
                                          'Email',
                                        ),
                                        initialValue: _email,
                                        icon: Icons.mail_outline_rounded,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: _emailValidator,
                                        onSaved: (value) =>
                                            setState(() => _email = value),
                                      ),
                                    ),
                                    _PremiumInfoRowData(
                                      icon: Icons.phone_rounded,
                                      label: AppLocalizations.globalText(
                                        'T\u00E9l\u00E9phone',
                                      ),
                                      value: _phone,
                                      trailingIcon: Icons.edit_rounded,
                                      onTap: () => _editText(
                                        title: AppLocalizations.globalText(
                                          'T\u00E9l\u00E9phone',
                                        ),
                                        initialValue: _phone,
                                        icon: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                        validator: _phoneValidator,
                                        onSaved: (value) =>
                                            setState(() => _phone = value),
                                      ),
                                    ),
                                    _PremiumInfoRowData(
                                      icon: Icons.calendar_month_rounded,
                                      label: AppLocalizations.globalText(
                                        'Date de naissance',
                                      ),
                                      value: _formattedBirthDate,
                                      trailingIcon: Icons.edit_rounded,
                                      onTap: _pickBirthDate,
                                    ),
                                    _PremiumInfoRowData(
                                      icon: Icons.location_on_rounded,
                                      label: AppLocalizations.globalText(
                                        'Adresse',
                                      ),
                                      value: _address,
                                      trailingIcon: Icons.edit_rounded,
                                      onTap: () => _editText(
                                        title: AppLocalizations.globalText(
                                          'Adresse',
                                        ),
                                        initialValue: _address,
                                        icon: Icons.location_on_outlined,
                                        validator: _requiredValidator,
                                        onSaved: (value) =>
                                            setState(() => _address = value),
                                      ),
                                    ),
                                    _PremiumInfoRowData(
                                      icon: Icons.badge_rounded,
                                      label: AppLocalizations.globalText('CIN'),
                                      value: _cin,
                                      trailingIcon: Icons.edit_rounded,
                                      onTap: () => _editText(
                                        title: AppLocalizations.globalText(
                                          'CIN',
                                        ),
                                        initialValue: _cin,
                                        icon: Icons.badge_outlined,
                                        validator: _cinValidator,
                                        onSaved: (value) =>
                                            setState(() => _cin = value),
                                      ),
                                    ),
                                    _PremiumInfoRowData(
                                      icon: Icons.flag_rounded,
                                      label: AppLocalizations.globalText(
                                        'Nationalit\u00E9',
                                      ),
                                      value: _nationality,
                                      trailingIcon: Icons.chevron_right_rounded,
                                      onTap: () => _selectValue(
                                        title: AppLocalizations.globalText(
                                          'Nationalit\u00E9',
                                        ),
                                        values: [
                                          'Marocaine',
                                          'Fran\u00E7aise',
                                          'Espagnole',
                                          'Autre',
                                        ],
                                        currentValue: _nationality,
                                        onSelected: (value) => setState(
                                          () => _nationality = value,
                                        ),
                                      ),
                                    ),
                                    _PremiumInfoRowData(
                                      icon: Icons.language_rounded,
                                      label: AppLocalizations.globalText(
                                        'Langue',
                                      ),
                                      value: _language,
                                      trailingIcon: Icons.chevron_right_rounded,
                                      onTap: () => _selectValue(
                                        title: AppLocalizations.globalText(
                                          'Langue',
                                        ),
                                        values: [
                                          'Fran\u00E7ais',
                                          '\u0627\u0644\u0639\u0631\u0628\u064A\u0629',
                                          'English',
                                        ],
                                        currentValue: _language,
                                        onSelected: (value) =>
                                            setState(() => _language = value),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24),
                                _PremiumInfoSaveButton(onPressed: _saveChanges),
                              ],
                            ),
                          ),
                        ),
                        _PremiumProfileBottomNav(onChanged: _handleBottomNav),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Champ obligatoire';
    return null;
  }

  String? _emailValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())) {
      return 'Email invalide';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final compact = text.replaceAll(RegExp(r'[\s.-]+'), '');
    if (!RegExp(r'^(0[5-7]\d{8}|\+212[5-7]\d{8})$').hasMatch(compact)) {
      return 'Num\u00E9ro marocain invalide';
    }
    return null;
  }

  String? _cinValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    if (value!.trim().length > 12) return 'CIN trop long';
    return null;
  }

  Future<void> _editText({
    required String title,
    required String initialValue,
    required IconData icon,
    required ValueChanged<String> onSaved,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: keyboardType,
                  validator: validator,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _premiumInfoInputDecoration(title, icon),
                ),
                SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(context, controller.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.globalText('Valider'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (value == null || value == initialValue.trim()) return;
    onSaved(value);
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _selectValue({
    required String title,
    required List<String> values,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12),
                for (final item in values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item,
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: item == currentValue
                        ? Icon(Icons.check_rounded, color: primaryBlue)
                        : null,
                    onTap: () => Navigator.pop(context, item),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (value == null || value == currentValue) return;
    onSelected(value);
  }

  Future<void> _showAvatarOptions() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_camera_rounded, color: textMuted),
                  title: Text(
                    AppLocalizations.globalText('Prendre une photo'),
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, 'photo'),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_rounded, color: textMuted),
                  title: Text(
                    AppLocalizations.globalText('Choisir depuis la galerie'),
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                ListTile(
                  leading: Icon(Icons.close_rounded, color: textMuted),
                  title: Text(
                    AppLocalizations.globalText('Annuler'),
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (option == null) return;
    setState(() => _avatarLabel = _initials);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.globalText('Photo de profil mise \u00E0 jour'),
        ),
      ),
    );
  }

  void _saveChanges() {
    final validators = [
      _requiredValidator(_fullName),
      _emailValidator(_email),
      _phoneValidator(_phone),
      _cinValidator(_cin),
    ].whereType<String>().toList();
    if (validators.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validators.first)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.globalText(
            'Informations mises \u00E0 jour avec succ\u00E8s',
          ),
        ),
      ),
    );
  }

  void _handleBottomNav(int index) {
    if (index == 4) return Navigator.pop(context);
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home-commercial',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }
}

class _PremiumInfoHeader extends StatelessWidget {
  _PremiumInfoHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, size: 30),
          color: primaryBlue,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 42, height: 42),
        ),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText('Informations personnelles'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textDark,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 4),
              Text(
                AppLocalizations.globalText(
                  'G\u00E9rez vos informations de profil',
                ),
                style: TextStyle(
                  color: textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumInfoUserCard extends StatelessWidget {
  _PremiumInfoUserCard({
    required this.initials,
    required this.fullName,
    required this.role,
    required this.email,
    required this.company,
    required this.onCameraTap,
  });

  final String initials;
  final String fullName;
  final String role;
  final String email;
  final String company;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: _premiumInfoCardDecoration(),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryBlue, Color(0xFF1D4ED8)],
                  ),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -3,
                bottom: 6,
                child: Material(
                  color: cardBg,
                  shape: CircleBorder(),
                  elevation: 8,
                  child: IconButton(
                    onPressed: onCameraTap,
                    icon: Icon(Icons.photo_camera_rounded, size: 18),
                    color: primaryBlue,
                    constraints: BoxConstraints.tightFor(width: 40, height: 40),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  role,
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12),
                _PremiumUserMeta(icon: Icons.mail_outline_rounded, text: email),
                SizedBox(height: 8),
                _PremiumUserMeta(icon: Icons.business_rounded, text: company),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumUserMeta extends StatelessWidget {
  _PremiumUserMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: textMuted, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumInfoCard extends StatelessWidget {
  _PremiumInfoCard({required this.rows});

  final List<_PremiumInfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _premiumInfoCardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _PremiumInfoRow(data: rows[i]),
            if (i != rows.length - 1)
              Padding(
                padding: EdgeInsets.only(left: 74),
                child: Divider(height: 1, color: _profileBorderColor()),
              ),
          ],
        ],
      ),
    );
  }
}

class _PremiumInfoRowData {
  _PremiumInfoRowData({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailingIcon,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData trailingIcon;
  final VoidCallback onTap;
}

class _PremiumInfoRow extends StatelessWidget {
  _PremiumInfoRow({required this.data});

  final _PremiumInfoRowData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 18, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: primaryBlue, size: 23),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    data.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Icon(data.trailingIcon, color: primaryBlue, size: 22),
          ],
        ),
      ),
    );
  }
}

class _PremiumInfoSaveButton extends StatelessWidget {
  _PremiumInfoSaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.save_outlined, color: Colors.white),
        label: Text(
          AppLocalizations.globalText('Enregistrer les modifications'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          elevation: 10,
          shadowColor: primaryBlue.withValues(alpha: .24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _PremiumProfileBottomNav extends StatelessWidget {
  _PremiumProfileBottomNav({required this.onChanged});

  final ValueChanged<int> onChanged;

  static final _items = [
    (Icons.home_outlined, 'Accueil'),
    (Icons.groups_outlined, 'Clients'),
    (Icons.receipt_long_outlined, 'Commandes'),
    (Icons.pie_chart_outline_rounded, 'Activit\u00E9s'),
    (Icons.person_outline_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: _profileBorderColor())),
        boxShadow: [
          BoxShadow(
            color: _profileShadowColor(.06),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items[i].$1,
                          color: i == 4 ? primaryBlue : textMuted,
                          size: 27,
                        ),
                        SizedBox(height: 4),
                        Text(
                          _items[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i == 4 ? primaryBlue : textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
    );
  }
}

InputDecoration _premiumInfoInputDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: textMuted),
    filled: true,
    fillColor: cardBg,
    hintStyle: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _profileBorderColor()),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: primaryBlue, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: errorRed),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: errorRed, width: 1.6),
    ),
  );
}

BoxDecoration _premiumInfoCardDecoration() {
  return BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: _profileBorderColor()),
    boxShadow: [
      BoxShadow(
        color: _profileShadowColor(.045),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
    ],
  );
}

// PAGE INFORMATIONS PERSONNELLES
class PersonalInfoScreen extends StatefulWidget {
  PersonalInfoScreen({
    super.key,
    required this.user,
    required this.fallbackName,
    required this.fallbackEmail,
    required this.fallbackPhone,
  });

  final MockUserProfile? user;
  final String fallbackName;
  final String fallbackEmail;
  final String fallbackPhone;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late TextEditingController _nameController;
  late TextEditingController _firstNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final names = widget.fallbackName.split(' ');
    _nameController = TextEditingController(
      text: names.length > 1 ? names.sublist(1).join(' ') : '',
    );
    _firstNameController = TextEditingController(
      text: names.isNotEmpty ? names[0] : '',
    );
    _phoneController = TextEditingController(text: widget.fallbackPhone);
    _emailController = TextEditingController(text: widget.fallbackEmail);
    _addressController = TextEditingController(text: 'Casablanca, Maroc');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firstNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.globalText('Informations personnelles'),
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField('Prénom', _firstNameController),
            SizedBox(height: 16),
            _buildTextField('Nom', _nameController),
            SizedBox(height: 16),
            _buildTextField('Téléphone', _phoneController),
            SizedBox(height: 16),
            _buildTextField('Email', _emailController, enabled: false),
            SizedBox(height: 16),
            _buildTextField('Adresse', _addressController),
            SizedBox(height: 32),
            _buildSaveButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryBlue, width: 2),
            ),
            filled: true,
            fillColor: enabled ? cardBg : Colors.grey.withValues(alpha: 0.05),
          ),
          style: TextStyle(color: textDark, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusLarge),
          ),
          elevation: 2,
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.globalText('Informations enregistrées'),
              ),
            ),
          );
          Navigator.pop(context);
        },
        child: Text(
          AppLocalizations.globalText('Enregistrer'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// PAGE SECURITE PREMIUM
class PremiumSecurityScreen extends StatefulWidget {
  PremiumSecurityScreen({super.key, required this.user});

  final MockUserProfile? user;

  @override
  State<PremiumSecurityScreen> createState() => _PremiumSecurityScreenState();
}

class _PremiumSecurityScreenState extends State<PremiumSecurityScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final _PremiumSecurityAccount _account;
  late final List<_PremiumSecurityDevice> _devices;
  late final List<_PremiumSecurityLogin> _history;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _twoFactorEnabled = true;

  @override
  void initState() {
    super.initState();
    _account = _PremiumSecurityAccount.fromUser(widget.user);
    _devices = _buildDevices();
    _history = _buildHistory();
    _newPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  _PremiumPasswordStrength get _strength {
    return _PremiumPasswordStrength.fromPassword(_newPasswordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumSecurityShell(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PremiumSecurityHeader(
                    title: AppLocalizations.globalText('S\u00E9curit\u00E9'),
                    subtitle: AppLocalizations.globalText(
                      'Prot\u00E9gez votre compte et vos donn\u00E9es',
                    ),
                    onBack: () => Navigator.pop(context),
                  ),
                  SizedBox(height: 24),
                  _PremiumSecurityStatusCard(account: _account),
                  SizedBox(height: 24),
                  _PremiumSecurityTitle('Changer le mot de passe'),
                  SizedBox(height: 12),
                  _PremiumPasswordCard(
                    currentController: _currentPasswordController,
                    newController: _newPasswordController,
                    confirmController: _confirmPasswordController,
                    hideCurrent: _hideCurrent,
                    hideNew: _hideNew,
                    hideConfirm: _hideConfirm,
                    strength: _strength,
                    onToggleCurrent: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                    onToggleNew: () => setState(() => _hideNew = !_hideNew),
                    onToggleConfirm: () =>
                        setState(() => _hideConfirm = !_hideConfirm),
                    onSubmit: _updatePassword,
                  ),
                  SizedBox(height: 24),
                  _PremiumSecurityTitle('S\u00E9curit\u00E9 du compte'),
                  SizedBox(height: 12),
                  _PremiumSecurityMenuCard(
                    rows: [
                      _PremiumSecurityMenuData(
                        icon: Icons.phone_iphone_rounded,
                        title: AppLocalizations.globalText(
                          'Appareils connect\u00E9s',
                        ),
                        subtitle: AppLocalizations.globalText(
                          'G\u00E9rez les appareils connect\u00E9s \u00E0 votre compte',
                        ),
                        onTap: _openDevices,
                      ),
                      _PremiumSecurityMenuData(
                        icon: Icons.verified_user_rounded,
                        title: AppLocalizations.globalText(
                          'Authentification \u00E0 deux facteurs',
                        ),
                        subtitle: AppLocalizations.globalText(
                          'Renforcez la s\u00E9curit\u00E9 de votre compte',
                        ),
                        status: _twoFactorEnabled
                            ? 'Activ\u00E9e'
                            : 'D\u00E9sactiv\u00E9e',
                        statusColor: _twoFactorEnabled
                            ? Color(0xFF22C55E)
                            : errorRed,
                        onTap: _openTwoFactor,
                      ),
                      _PremiumSecurityMenuData(
                        icon: Icons.history_rounded,
                        title: AppLocalizations.globalText(
                          'Historique des connexions',
                        ),
                        subtitle: AppLocalizations.globalText(
                          'Consultez vos derni\u00E8res connexions',
                        ),
                        onTap: _openHistory,
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  _PremiumSecurityTitle('Sessions'),
                  SizedBox(height: 12),
                  _PremiumSecurityMenuCard(
                    rows: [
                      _PremiumSecurityMenuData(
                        icon: Icons.logout_rounded,
                        iconColor: errorRed,
                        iconBackground: errorRed.withValues(alpha: .10),
                        title: AppLocalizations.globalText(
                          'Se d\u00E9connecter de tous les appareils',
                        ),
                        subtitle: AppLocalizations.globalText(
                          'D\u00E9connectez-vous de toutes les sessions actives',
                        ),
                        onTap: _confirmDisconnectAll,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _PremiumProfileBottomNav(onChanged: _handleBottomNav),
        ],
      ),
    );
  }

  void _handleBottomNav(int index) {
    if (index == 4) return Navigator.pop(context);
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home-commercial',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }

  void _updatePassword() {
    final current = _currentPasswordController.text.trim();
    final next = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    final currentPassword = widget.user?.password ?? '123456';

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _showMessage('Tous les champs sont obligatoires');
      return;
    }
    if (current != currentPassword) {
      _showMessage('Mot de passe actuel incorrect');
      return;
    }
    if (_strength.level < 2) {
      _showMessage('Le nouveau mot de passe est trop faible');
      return;
    }
    if (next != confirm) {
      _showMessage('Les mots de passe ne correspondent pas');
      return;
    }

    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _showMessage('Mot de passe mis \u00E0 jour avec succ\u00E8s');
  }

  void _openDevices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PremiumConnectedDevicesScreen(
          devices: _devices,
          onDisconnect: (device) {
            setState(() => _devices.remove(device));
            _showMessage('Appareil d\u00E9connect\u00E9');
          },
        ),
      ),
    );
  }

  void _openTwoFactor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PremiumTwoFactorScreen(
          enabled: _twoFactorEnabled,
          onChanged: (value) => setState(() => _twoFactorEnabled = value),
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PremiumLoginHistoryScreen(history: _history),
      ),
    );
  }

  Future<void> _confirmDisconnectAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.globalText('D\u00E9connexion globale')),
        content: Text(
          AppLocalizations.globalText(
            'Voulez-vous vraiment d\u00E9connecter tous les appareils connect\u00E9s \u00E0 votre compte ?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.globalText('Annuler')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: errorRed),
            child: Text(
              AppLocalizations.globalText('Confirmer'),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(_devices.clear);
    _showMessage(
      'Toutes les sessions ont \u00E9t\u00E9 d\u00E9connect\u00E9es',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<_PremiumSecurityDevice> _buildDevices() {
    return [
      _PremiumSecurityDevice(
        name: 'Samsung Galaxy S24',
        system: 'Android',
        location: _account.city,
        lastActivity: 'Actif maintenant',
        isCurrent: true,
      ),
      _PremiumSecurityDevice(
        name: 'Windows PC',
        system: 'Windows',
        location: _account.city,
        lastActivity: 'Hier',
      ),
      _PremiumSecurityDevice(
        name: 'Tablette Android',
        system: 'Android',
        location: _account.city,
        lastActivity: 'Il y a 3 jours',
      ),
    ];
  }

  List<_PremiumSecurityLogin> _buildHistory() {
    return [
      _PremiumSecurityLogin(
        date: '08/06/2026',
        time: '',
        device: 'Android',
        location: _account.city,
        successful: true,
      ),
      _PremiumSecurityLogin(
        date: '07/06/2026',
        time: '',
        device: 'Windows',
        location: _account.city,
        successful: true,
      ),
      _PremiumSecurityLogin(
        date: '06/06/2026',
        time: '',
        device: 'Android',
        location: _account.city,
        successful: false,
      ),
    ];
  }
}

class _PremiumSecurityShell extends StatelessWidget {
  _PremiumSecurityShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 430
                ? 430.0
                : constraints.maxWidth;
            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PremiumSecurityHeader extends StatelessWidget {
  _PremiumSecurityHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, size: 30),
          color: primaryBlue,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 42, height: 42),
        ),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textDark,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumSecurityStatusCard extends StatelessWidget {
  _PremiumSecurityStatusCard({required this.account});

  final _PremiumSecurityAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: _premiumInfoCardDecoration(),
      child: Row(
        children: [
          _PremiumSecurityIcon(icon: Icons.shield_rounded, size: 58),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.globalText(
                    'Votre compte est s\u00E9curis\u00E9',
                  ),
                  style: TextStyle(
                    color: textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  AppLocalizations.globalText('Derni\u00E8re connexion :'),
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${account.lastLoginLabel} \u2022 ${account.location}',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Color(0xFF22C55E).withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF22C55E),
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPasswordCard extends StatelessWidget {
  _PremiumPasswordCard({
    required this.currentController,
    required this.newController,
    required this.confirmController,
    required this.hideCurrent,
    required this.hideNew,
    required this.hideConfirm,
    required this.strength,
    required this.onToggleCurrent,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  final TextEditingController currentController;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool hideCurrent;
  final bool hideNew;
  final bool hideConfirm;
  final _PremiumPasswordStrength strength;
  final VoidCallback onToggleCurrent;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _premiumInfoCardDecoration(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PremiumPasswordField(
            controller: currentController,
            title: AppLocalizations.globalText('Mot de passe actuel'),
            hint: AppLocalizations.globalText(
              'Entrez votre mot de passe actuel',
            ),
            obscureText: hideCurrent,
            onToggleVisibility: onToggleCurrent,
          ),
          SizedBox(height: 14),
          _PremiumPasswordField(
            controller: newController,
            title: AppLocalizations.globalText('Nouveau mot de passe'),
            hint: AppLocalizations.globalText(
              'Entrez votre nouveau mot de passe',
            ),
            obscureText: hideNew,
            onToggleVisibility: onToggleNew,
          ),
          SizedBox(height: 12),
          _PremiumPasswordMeter(strength: strength),
          SizedBox(height: 14),
          _PremiumPasswordField(
            controller: confirmController,
            title: AppLocalizations.globalText(
              'Confirmer le nouveau mot de passe',
            ),
            hint: AppLocalizations.globalText(
              'Confirmez votre nouveau mot de passe',
            ),
            obscureText: hideConfirm,
            onToggleVisibility: onToggleConfirm,
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: Icon(Icons.lock_outline_rounded, color: Colors.white),
              label: Text(
                AppLocalizations.globalText(
                  'Mettre \u00E0 jour le mot de passe',
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                elevation: 8,
                shadowColor: primaryBlue.withValues(alpha: .20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPasswordField extends StatelessWidget {
  _PremiumPasswordField({
    required this.controller,
    required this.title,
    required this.hint,
    required this.obscureText,
    required this.onToggleVisibility,
  });

  final TextEditingController controller;
  final String title;
  final String hint;
  final bool obscureText;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(
            color: textDark,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: primaryBlue,
              size: 21,
            ),
            suffixIcon: IconButton(
              onPressed: onToggleVisibility,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 21,
              ),
              color: textMuted,
            ),
            filled: true,
            fillColor: cardBg,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumPasswordMeter extends StatelessWidget {
  _PremiumPasswordMeter({required this.strength});

  final _PremiumPasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.globalText('Force du mot de passe :'),
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                strength.label,
                style: TextStyle(
                  color: strength.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 4; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= strength.level
                          ? strength.color
                          : Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (i != 4) SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumSecurityMenuCard extends StatelessWidget {
  _PremiumSecurityMenuCard({required this.rows});

  final List<_PremiumSecurityMenuData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _premiumInfoCardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _PremiumSecurityMenuRow(data: rows[i]),
            if (i != rows.length - 1)
              Padding(
                padding: EdgeInsets.only(left: 74),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
          ],
        ],
      ),
    );
  }
}

class _PremiumSecurityMenuData {
  _PremiumSecurityMenuData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.status,
    this.statusColor,
    this.iconColor = const Color(0xFF2563EB),
    this.iconBackground,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final Color? statusColor;
  final Color iconColor;
  final Color? iconBackground;
  final VoidCallback onTap;
}

class _PremiumSecurityMenuRow extends StatelessWidget {
  _PremiumSecurityMenuRow({required this.data});

  final _PremiumSecurityMenuData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            _PremiumSecurityIcon(
              icon: data.icon,
              color: data.iconColor,
              background: data.iconBackground,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (data.status != null) ...[
              SizedBox(width: 8),
              Text(
                data.status!,
                style: TextStyle(
                  color: data.statusColor ?? textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: textMuted, size: 24),
          ],
        ),
      ),
    );
  }
}

class _PremiumSecurityIcon extends StatelessWidget {
  _PremiumSecurityIcon({
    required this.icon,
    this.color = const Color(0xFF2563EB),
    this.background,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: size * .5),
    );
  }
}

class _PremiumSecurityTitle extends StatelessWidget {
  _PremiumSecurityTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: textDark,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PremiumConnectedDevicesScreen extends StatefulWidget {
  _PremiumConnectedDevicesScreen({
    required this.devices,
    required this.onDisconnect,
  });

  final List<_PremiumSecurityDevice> devices;
  final ValueChanged<_PremiumSecurityDevice> onDisconnect;

  @override
  State<_PremiumConnectedDevicesScreen> createState() =>
      _PremiumConnectedDevicesScreenState();
}

class _PremiumConnectedDevicesScreenState
    extends State<_PremiumConnectedDevicesScreen> {
  late final List<_PremiumSecurityDevice> _devices;

  @override
  void initState() {
    super.initState();
    _devices = List.of(widget.devices);
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumSecuritySubPage(
      title: AppLocalizations.globalText('Appareils connect\u00E9s'),
      subtitle: AppLocalizations.globalText(
        'G\u00E9rez les acc\u00E8s \u00E0 votre compte',
      ),
      child: Column(
        children: [
          for (final device in _devices)
            _PremiumSecurityDetailCard(
              icon: Icons.devices_rounded,
              title: device.name,
              lines: [device.location, device.lastActivity],
              trailing: TextButton(
                onPressed: () {
                  widget.onDisconnect(device);
                  setState(() => _devices.remove(device));
                },
                child: Text(
                  AppLocalizations.globalText('D\u00E9connecter'),
                  style: TextStyle(color: errorRed),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumTwoFactorScreen extends StatefulWidget {
  _PremiumTwoFactorScreen({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  State<_PremiumTwoFactorScreen> createState() =>
      _PremiumTwoFactorScreenState();
}

class _PremiumTwoFactorScreenState extends State<_PremiumTwoFactorScreen> {
  late bool _enabled;
  String _method = 'SMS';

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return _PremiumSecuritySubPage(
      title: AppLocalizations.globalText('Double authentification'),
      subtitle: AppLocalizations.globalText(
        'Renforcez la s\u00E9curit\u00E9 de votre compte',
      ),
      child: Column(
        children: [
          _PremiumSecurityDetailCard(
            icon: Icons.verified_user_rounded,
            title: _enabled
                ? 'Authentification activ\u00E9e'
                : 'Authentification d\u00E9sactiv\u00E9e',
            lines: [
              _enabled
                  ? 'Votre compte demande une validation suppl\u00E9mentaire.'
                  : 'Choisissez une m\u00E9thode pour prot\u00E9ger vos connexions.',
            ],
            trailing: Switch(
              value: _enabled,
              activeThumbColor: primaryBlue,
              onChanged: _toggle,
            ),
          ),
          if (!_enabled) ...[
            SizedBox(height: 12),
            _PremiumSecurityChoice(
              title: AppLocalizations.globalText('Validation par SMS'),
              selected: _method == 'SMS',
              onTap: () => setState(() => _method = 'SMS'),
            ),
            SizedBox(height: 10),
            _PremiumSecurityChoice(
              title: AppLocalizations.globalText('Validation par email'),
              selected: _method == 'Email',
              onTap: () => setState(() => _method = 'Email'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggle(bool value) async {
    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(AppLocalizations.globalText('D\u00E9sactiver la 2FA')),
          content: Text(
            AppLocalizations.globalText(
              'Voulez-vous d\u00E9sactiver l\u2019authentification \u00E0 deux facteurs ?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.globalText('Annuler')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.globalText('Confirmer')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _enabled = value);
    widget.onChanged(value);
  }
}

class _PremiumLoginHistoryScreen extends StatelessWidget {
  _PremiumLoginHistoryScreen({required this.history});

  final List<_PremiumSecurityLogin> history;

  @override
  Widget build(BuildContext context) {
    return _PremiumSecuritySubPage(
      title: AppLocalizations.globalText('Historique des connexions'),
      subtitle: AppLocalizations.globalText(
        'Consultez les derni\u00E8res tentatives',
      ),
      child: Column(
        children: [
          for (final item in history)
            _PremiumSecurityDetailCard(
              icon: item.successful
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              iconColor: item.successful ? Color(0xFF22C55E) : errorRed,
              title: item.date,
              lines: [item.device, item.location],
              trailing: _PremiumSecurityStatusPill(
                label: item.successful
                    ? 'Connexion r\u00E9ussie'
                    : 'Tentative \u00E9chou\u00E9e',
                color: item.successful ? Color(0xFF22C55E) : errorRed,
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumSecuritySubPage extends StatelessWidget {
  _PremiumSecuritySubPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PremiumSecurityShell(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PremiumSecurityHeader(
                    title: title,
                    subtitle: subtitle,
                    onBack: () => Navigator.pop(context),
                  ),
                  SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
          _PremiumProfileBottomNav(
            onChanged: (index) {
              if (index == 4) return Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home-commercial',
                (route) => false,
                arguments: {'initialIndex': index},
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PremiumSecurityDetailCard extends StatelessWidget {
  _PremiumSecurityDetailCard({
    required this.icon,
    required this.title,
    required this.lines,
    this.iconColor = const Color(0xFF2563EB),
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: _premiumInfoCardDecoration(),
      child: Row(
        children: [
          _PremiumSecurityIcon(icon: icon, color: iconColor),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                for (final line in lines)
                  Text(
                    line,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _PremiumSecurityChoice extends StatelessWidget {
  _PremiumSecurityChoice({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: _premiumInfoCardDecoration(),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? primaryBlue : textMuted,
            ),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: textDark,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSecurityStatusPill extends StatelessWidget {
  _PremiumSecurityStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 96),
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _PremiumSecurityAccount {
  _PremiumSecurityAccount({
    required this.lastLoginTime,
    required this.city,
    required this.country,
  });

  factory _PremiumSecurityAccount.fromUser(MockUserProfile? user) {
    final sessionUser = CurrentUserSession.currentUser;
    final id = user?.id ?? sessionUser?.id ?? 1;
    final hour = 8 + (id % 3);
    final minute = (35 + id * 7) % 60;
    final city = id % 2 == 0 ? 'Rabat' : 'Casablanca';
    return _PremiumSecurityAccount(
      lastLoginTime:
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      city: city,
      country: 'Maroc',
    );
  }

  final String lastLoginTime;
  final String city;
  final String country;

  String get lastLoginLabel => 'Aujourd\u2019hui \u00E0 $lastLoginTime';
  String get location => '$city, $country';
}

class _PremiumPasswordStrength {
  _PremiumPasswordStrength({
    required this.label,
    required this.color,
    required this.level,
  });

  factory _PremiumPasswordStrength.fromPassword(String password) {
    if (password.isEmpty || password.length < 8) {
      return _PremiumPasswordStrength(
        label: AppLocalizations.globalText('Faible'),
        color: errorRed,
        level: 1,
      );
    }
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    if (hasUpper && hasLower && hasNumber && hasSpecial) {
      return _PremiumPasswordStrength(
        label: AppLocalizations.globalText('Tr\u00E8s fort'),
        color: Color(0xFF22C55E),
        level: 4,
      );
    }
    if (hasUpper && hasLower && hasNumber) {
      return _PremiumPasswordStrength(
        label: AppLocalizations.globalText('Fort'),
        color: primaryBlue,
        level: 3,
      );
    }
    return _PremiumPasswordStrength(
      label: AppLocalizations.globalText('Moyen'),
      color: Color(0xFFF59E0B),
      level: 2,
    );
  }

  final String label;
  final Color color;
  final int level;
}

class _PremiumSecurityDevice {
  _PremiumSecurityDevice({
    required this.name,
    required this.system,
    required this.location,
    required this.lastActivity,
    this.isCurrent = false,
  });

  final String name;
  final String system;
  final String location;
  final String lastActivity;
  final bool isCurrent;
}

class _PremiumSecurityLogin {
  _PremiumSecurityLogin({
    required this.date,
    required this.time,
    required this.device,
    required this.location,
    required this.successful,
  });

  final String date;
  final String time;
  final String device;
  final String location;
  final bool successful;
}

// PAGE SÉCURITÉ
class SecurityScreen extends StatelessWidget {
  SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.globalText('Sécurité'),
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            _buildSecurityItem(
              context,
              Icons.lock_rounded,
              'Changer mot de passe',
              'Mettre à jour votre mot de passe',
              () => _showChangePasswordDialog(context),
            ),
            SizedBox(height: 16),
            _buildSecurityItem(
              context,
              Icons.fingerprint_rounded,
              'Authentification biométrique',
              'Activer empreinte digitale',
              () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.globalText('Biométrie à configurer'),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildSecurityItem(
              context,
              Icons.history_rounded,
              'Historique des connexions',
              'Voir vos connexions récentes',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LoginHistoryScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(borderRadiusLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryBlue),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
        title: Text(AppLocalizations.globalText('Changer mot de passe')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: AppLocalizations.globalText('Ancien mot de passe'),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: AppLocalizations.globalText('Nouveau mot de passe'),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: AppLocalizations.globalText(
                    'Confirmer mot de passe',
                  ),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.globalText('Annuler')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.globalText('Mot de passe mis à jour'),
                  ),
                ),
              );
            },
            child: Text(AppLocalizations.globalText('Enregistrer')),
          ),
        ],
      ),
    );
  }
}

// PAGE HISTORIQUE DES CONNEXIONS
class LoginHistoryScreen extends StatelessWidget {
  LoginHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loginHistory = [
      {
        'date': '04/06/2026',
        'time': '09:30',
        'device': 'iPhone 14',
        'location': 'Casablanca',
      },
      {
        'date': '03/06/2026',
        'time': '14:15',
        'device': 'iPhone 14',
        'location': 'Casablanca',
      },
      {
        'date': '02/06/2026',
        'time': '08:45',
        'device': 'iPad Air',
        'location': 'Rabat',
      },
    ];

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.globalText('Historique des connexions'),
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: loginHistory.length,
        itemBuilder: (context, index) {
          final item = loginHistory[index];
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.devices_rounded,
                    color: primaryBlue,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['device']!,
                        style: TextStyle(
                          color: textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item['location']!,
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item['date']!,
                      style: TextStyle(
                        color: textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      item['time']!,
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// PAGE NOTIFICATIONS
class NotificationsScreen extends StatefulWidget {
  NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _ordersNotifications = true;
  bool _clientsNotifications = true;
  bool _systemNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.globalText('Notifications'),
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                AppLocalizations.globalText('Préférences'),
                style: TextStyle(
                  color: textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _buildNotificationToggle(
              'Notifications commandes',
              'Recevoir des alertes de commandes',
              _ordersNotifications,
              (value) => setState(() => _ordersNotifications = value),
            ),
            SizedBox(height: 12),
            _buildNotificationToggle(
              'Notifications clients',
              'Recevoir des alertes clients',
              _clientsNotifications,
              (value) => setState(() => _clientsNotifications = value),
            ),
            SizedBox(height: 12),
            _buildNotificationToggle(
              'Notifications système',
              'Recevoir des alertes système',
              _systemNotifications,
              (value) => setState(() => _systemNotifications = value),
            ),
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                AppLocalizations.globalText('Paramètres audio'),
                style: TextStyle(
                  color: textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _buildNotificationToggle(
              'Sons',
              'Activer les sons de notification',
              _soundEnabled,
              (value) => setState(() => _soundEnabled = value),
            ),
            SizedBox(height: 12),
            _buildNotificationToggle(
              'Vibration',
              'Activer la vibration',
              _vibrationEnabled,
              (value) => setState(() => _vibrationEnabled = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primaryBlue,
          ),
        ],
      ),
    );
  }
}

// PAGE LANGUE
class LanguageScreen extends StatefulWidget {
  LanguageScreen({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.selectedLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.globalText('Langue'),
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          _buildLanguageOption('Français', 'French', 'FR'),
          SizedBox(height: 12),
          _buildLanguageOption('Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©', 'Arabic', 'AR'),
          SizedBox(height: 12),
          _buildLanguageOption('English', 'English', 'EN'),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(String name, String englishName, String code) {
    final isSelected = _selectedLanguage == name;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLanguage = name);
        widget.onLanguageChanged(name);
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) Navigator.pop(context);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue.withValues(alpha: 0.1) : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  englishName,
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
              ],
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primaryBlue, size: 24),
          ],
        ),
      ),
    );
  }
}

// PAGE À PROPOS
class AboutAppScreen extends StatelessWidget {
  AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.globalText('À propos de l\'application'),
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.apps_rounded, color: primaryBlue, size: 50),
            ),
            SizedBox(height: 24),
            Text(
              AppLocalizations.globalText('Gestion Prévente'),
              style: TextStyle(
                color: textDark,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.globalText('Version 1.0.0'),
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
            SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.globalText('À propos'),
                    style: TextStyle(
                      color: textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppLocalizations.globalText(
                      'Gestion Prévente est une application mobile complète dédiée aux commerciaux pour gérer efficacement leurs clients, commandes et activités.',
                    ),
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// PAGE CONFIDENTIALITÉ
class ProfessionalAboutAppScreen extends StatelessWidget {
  ProfessionalAboutAppScreen({super.key});

  final _AboutAppInfo _info = _AboutAppInfo.current;

  @override
  Widget build(BuildContext context) {
    syncProfileTheme(context);

    return Scaffold(
      backgroundColor: surfaceBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 430
                ? 430.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(24, 18, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AboutHeader(
                                  onBack: () => Navigator.pop(context),
                                ),
                                SizedBox(height: 26),
                                _AboutHeroCard(info: _info),
                                SizedBox(height: 20),
                                _AboutDescriptionCard(info: _info),
                                SizedBox(height: 20),
                                _AboutInfoCard(info: _info),
                                SizedBox(height: 20),
                                _AboutSupportCard(info: _info),
                                SizedBox(height: 20),
                                _AboutRateCard(
                                  onTap: () => _showRatingDialog(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _PremiumProfileBottomNav(
                          onChanged: (index) =>
                              _handleBottomNav(context, index),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleBottomNav(BuildContext context, int index) {
    if (index == 4) return Navigator.pop(context);
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home-commercial',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }

  Future<void> openMail(BuildContext context, String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Impossible d'ouvrir l'application mail.")),
    );
  }

  Future<void> _showRatingDialog(BuildContext context) async {
    int rating = 0;
    final commentController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                'Évaluez notre application',
                style: TextStyle(color: textDark, fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final selected = index < rating;
                      return IconButton(
                        onPressed: () =>
                            setDialogState(() => rating = index + 1),
                        icon: Icon(
                          selected
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Color(0xFFF59E0B),
                          size: 34,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 14),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    style: TextStyle(color: textDark),
                    decoration: InputDecoration(
                      hintText: 'Partagez votre expérience',
                      hintStyle: TextStyle(color: textMuted),
                      filled: true,
                      fillColor: surfaceBg,
                      border: _aboutInputBorder(),
                      enabledBorder: _aboutInputBorder(),
                      focusedBorder: _aboutInputBorder(primaryBlue, 1.6),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: rating == 0
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Envoyer'),
                ),
              ],
            );
          },
        );
      },
    );

    commentController.dispose();
    if (submitted != true || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Merci pour votre évaluation.')));
  }
}

class _AboutAppInfo {
  const _AboutAppInfo({
    required this.name,
    required this.shortDescription,
    required this.description,
    required this.version,
    required this.releaseDate,
    required this.developer,
    required this.contactEmail,
    required this.supportEmail,
  });

  final String name;
  final String shortDescription;
  final String description;
  final String version;
  final String releaseDate;
  final String developer;
  final String contactEmail;
  final String supportEmail;

  static const current = _AboutAppInfo(
    name: 'PreSales',
    shortDescription: 'Application de gestion de prévente',
    description:
        'PreSales est une application professionnelle permettant aux commerciaux de gérer efficacement leurs clients, commandes, visites et activités quotidiennes.',
    version: '1.0.0',
    releaseDate: '15 mai 2026',
    developer: 'Ryme Mounfalouti',
    contactEmail: 'contact@presales.com',
    supportEmail: 'support@presales.com',
  );
}

class _AboutHeader extends StatelessWidget {
  _AboutHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, size: 30),
          color: primaryBlue,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 42, height: 42),
        ),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "À propos de l'application",
                style: TextStyle(
                  color: textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Informations sur l'application",
                style: TextStyle(
                  color: textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutHeroCard extends StatelessWidget {
  _AboutHeroCard({required this.info});

  final _AboutAppInfo info;

  @override
  Widget build(BuildContext context) {
    return _AboutCard(
      padding: EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withValues(alpha: .25),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              Icons.shopping_cart_checkout_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          SizedBox(height: 22),
          Text(
            info.name,
            style: TextStyle(
              color: textDark,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            info.shortDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 18),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Version ${info.version}',
              style: TextStyle(
                color: primaryBlue,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutDescriptionCard extends StatelessWidget {
  _AboutDescriptionCard({required this.info});

  final _AboutAppInfo info;

  @override
  Widget build(BuildContext context) {
    return _AboutCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AboutIcon(icon: Icons.info_outline_rounded),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AboutSectionTitle('Description'),
                SizedBox(height: 14),
                Text(
                  info.description,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 15,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutInfoCard extends StatelessWidget {
  _AboutInfoCard({required this.info});

  final _AboutAppInfo info;

  @override
  Widget build(BuildContext context) {
    final mailer = ProfessionalAboutAppScreen();
    return _AboutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AboutIcon(icon: Icons.article_outlined),
              SizedBox(width: 18),
              _AboutSectionTitle('Informations'),
            ],
          ),
          SizedBox(height: 18),
          _AboutInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Version',
            value: info.version,
          ),
          _AboutDivider(),
          _AboutInfoRow(
            icon: Icons.schedule_rounded,
            label: 'Date de publication',
            value: info.releaseDate,
          ),
          _AboutDivider(),
          _AboutInfoRow(
            icon: Icons.people_outline_rounded,
            label: 'Développé par',
            value: info.developer,
          ),
          _AboutDivider(),
          _AboutInfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'Contact',
            value: info.contactEmail,
            isLink: true,
            onTap: () => mailer.openMail(context, info.contactEmail),
          ),
        ],
      ),
    );
  }
}

class _AboutSupportCard extends StatelessWidget {
  _AboutSupportCard({required this.info});

  final _AboutAppInfo info;

  @override
  Widget build(BuildContext context) {
    final mailer = ProfessionalAboutAppScreen();
    return _AboutActionCard(
      icon: Icons.mail_outline_rounded,
      iconColor: primaryBlue,
      title: 'Support',
      subtitle: info.supportEmail,
      subtitleColor: primaryBlue,
      onTap: () => mailer.openMail(context, info.supportEmail),
    );
  }
}

class _AboutRateCard extends StatelessWidget {
  _AboutRateCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _AboutActionCard(
      icon: Icons.star_border_rounded,
      iconColor: Color(0xFFF59E0B),
      iconBackground: Color(0xFFFFFBEB),
      title: 'Évaluez notre application',
      subtitle:
          "Votre avis nous aide à améliorer continuellement l'application.",
      onTap: onTap,
    );
  }
}

class _AboutActionCard extends StatelessWidget {
  _AboutActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleColor,
    this.iconBackground,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? subtitleColor;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    return _AboutCard(
      onTap: onTap,
      child: Row(
        children: [
          _AboutIcon(icon: icon, color: iconColor, background: iconBackground),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AboutSectionTitle(title),
                SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor ?? textMuted,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textDark, size: 28),
        ],
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  _AboutInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLink = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: textMuted, size: 23),
            SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLink ? primaryBlue : textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (isLink) ...[
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: textDark, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  _AboutCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _aboutBorderColor()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: content,
    );
  }
}

class _AboutIcon extends StatelessWidget {
  _AboutIcon({required this.icon, this.color, this.background});

  final IconData icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: background ?? primaryBlue.withValues(alpha: .09),
      child: Icon(icon, color: color ?? primaryBlue, size: 25),
    );
  }
}

class _AboutSectionTitle extends StatelessWidget {
  _AboutSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: textDark,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AboutDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: _aboutBorderColor());
  }
}

OutlineInputBorder _aboutInputBorder([Color? color, double width = 1]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color ?? _aboutBorderColor(), width: width),
  );
}

Color _aboutBorderColor() {
  return ThemeData.estimateBrightnessForColor(cardBg) == Brightness.dark
      ? const Color(0xFF334155)
      : const Color(0xFFE8EDF5);
}

class ProfessionalPrivacyScreen extends StatelessWidget {
  ProfessionalPrivacyScreen({super.key});

  final _PrivacyContent _content = _PrivacyContent.current;

  @override
  Widget build(BuildContext context) {
    syncProfileTheme(context);

    return Scaffold(
      backgroundColor: surfaceBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 430
                ? 430.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(24, 18, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _PrivacyHeader(
                                  onBack: () => Navigator.pop(context),
                                ),
                                SizedBox(height: 26),
                                _PrivacyHeroCard(content: _content),
                                SizedBox(height: 20),
                                _CollectedDataCard(content: _content),
                                SizedBox(height: 20),
                                _DataUsageCard(content: _content),
                                SizedBox(height: 20),
                                _SecurityDataCard(content: _content),
                                SizedBox(height: 20),
                                _RightsCard(content: _content),
                              ],
                            ),
                          ),
                        ),
                        _PremiumProfileBottomNav(
                          onChanged: (index) =>
                              _handleBottomNav(context, index),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleBottomNav(BuildContext context, int index) {
    if (index == 4) return Navigator.pop(context);
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home-commercial',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }
}

class _PrivacyContent {
  const _PrivacyContent({
    required this.heroTitle,
    required this.heroDescription,
    required this.collectionDescription,
    required this.collectedItems,
    required this.usageIntro,
    required this.usageItems,
    required this.securityDescription,
    required this.rightsDescription,
    required this.rightsDetails,
  });

  final String heroTitle;
  final String heroDescription;
  final String collectionDescription;
  final List<_PrivacyCollectedItem> collectedItems;
  final String usageIntro;
  final List<String> usageItems;
  final String securityDescription;
  final String rightsDescription;
  final String rightsDetails;

  static const current = _PrivacyContent(
    heroTitle: 'Votre confidentialité est notre priorité',
    heroDescription:
        'Nous nous engageons à protéger vos données personnelles et à garantir leur confidentialité.',
    collectionDescription:
        "Nous collectons uniquement les données nécessaires au fonctionnement de l'application.",
    collectedItems: [
      _PrivacyCollectedItem(
        icon: Icons.person_outline_rounded,
        title: 'Informations du compte',
        description: 'Nom, prénom, email, numéro de téléphone.',
        details:
            'Ces informations permettent d’identifier votre compte, de sécuriser votre accès et de personnaliser votre profil commercial.',
      ),
      _PrivacyCollectedItem(
        icon: Icons.assignment_outlined,
        title: "Données d’activité",
        description: 'Clients, commandes, visites et activités sur le terrain.',
        details:
            'Ces données servent à suivre votre activité de prévente, organiser vos visites et synchroniser les commandes avec votre équipe.',
      ),
      _PrivacyCollectedItem(
        icon: Icons.phone_android_rounded,
        title: 'Données techniques',
        description: 'Type d’appareil, version, logs et performances.',
        details:
            'Ces informations nous aident à diagnostiquer les incidents, améliorer la stabilité et assurer la compatibilité de l’application.',
      ),
      _PrivacyCollectedItem(
        icon: Icons.verified_user_outlined,
        title: "Données d’utilisation",
        description: "Statistiques d’usage pour améliorer l’expérience.",
        details:
            'Ces statistiques sont utilisées pour comprendre les fonctionnalités les plus utiles et améliorer l’expérience utilisateur.',
      ),
    ],
    usageIntro: 'Vos données sont utilisées uniquement pour :',
    usageItems: [
      'Fournir et améliorer nos services',
      "Assurer la sécurité et la fiabilité de l’application",
      'Personnaliser votre expérience utilisateur',
      'Vous accompagner dans votre activité',
    ],
    securityDescription:
        'Nous mettons en œuvre des mesures techniques et organisationnelles pour protéger vos données contre tout accès non autorisé, modification ou divulgation.',
    rightsDescription:
        'Vous avez le droit d’accéder, de modifier ou de supprimer vos données personnelles à tout moment en nous contactant.',
    rightsDetails:
        'Pour exercer vos droits, contactez le support PreSales depuis la section Support ou envoyez une demande écrite avec votre email de compte. Notre équipe vous accompagnera dans les meilleurs délais.',
  );
}

class _PrivacyCollectedItem {
  const _PrivacyCollectedItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.details,
  });

  final IconData icon;
  final String title;
  final String description;
  final String details;
}

class _PrivacyHeader extends StatelessWidget {
  _PrivacyHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, size: 30),
          color: primaryBlue,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 42, height: 42),
        ),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confidentialité',
                style: TextStyle(
                  color: textDark,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Notre engagement envers vos données',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyHeroCard extends StatelessWidget {
  _PrivacyHeroCard({required this.content});

  final _PrivacyContent content;

  @override
  Widget build(BuildContext context) {
    return _PrivacyCard(
      padding: EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 128,
            height: 118,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.shield_rounded, color: primaryBlue, size: 82),
                Icon(Icons.lock_rounded, color: Colors.white, size: 34),
                Positioned(
                  right: 18,
                  bottom: 20,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFF60A5FA),
                    child: Icon(Icons.check_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.heroTitle,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  content.heroDescription,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectedDataCard extends StatelessWidget {
  _CollectedDataCard({required this.content});

  final _PrivacyContent content;

  @override
  Widget build(BuildContext context) {
    return _PrivacyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrivacyIcon(icon: Icons.shield_outlined),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PrivacyTitle('Données collectées'),
                    SizedBox(height: 8),
                    Text(
                      '${content.collectionDescription} :',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          for (var i = 0; i < content.collectedItems.length; i++) ...[
            _PrivacyCollectedRow(item: content.collectedItems[i]),
            if (i != content.collectedItems.length - 1) _PrivacyDivider(),
          ],
        ],
      ),
    );
  }
}

class _PrivacyCollectedRow extends StatelessWidget {
  _PrivacyCollectedRow({required this.item});

  final _PrivacyCollectedItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showPrivacyDetails(context, item.title, item.details),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _PrivacyIcon(icon: item.icon, radius: 22),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textDark, size: 26),
          ],
        ),
      ),
    );
  }
}

class _DataUsageCard extends StatelessWidget {
  _DataUsageCard({required this.content});

  final _PrivacyContent content;

  @override
  Widget build(BuildContext context) {
    return _PrivacyCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PrivacyIcon(
            icon: Icons.lock_outline_rounded,
            color: Color(0xFF22C55E),
            background: Color(0xFFEFFDF5),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrivacyTitle('Utilisation de vos données'),
                SizedBox(height: 8),
                Text(
                  content.usageIntro,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 14),
                for (final item in content.usageItems)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Color(0xFF22C55E),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityDataCard extends StatelessWidget {
  _SecurityDataCard({required this.content});

  final _PrivacyContent content;

  @override
  Widget build(BuildContext context) {
    return _PrivacyInfoCard(
      icon: Icons.storage_rounded,
      iconColor: Color(0xFFF59E0B),
      iconBackground: Color(0xFFFFFBEB),
      title: 'Sécurité des données',
      description: content.securityDescription,
    );
  }
}

class _RightsCard extends StatelessWidget {
  _RightsCard({required this.content});

  final _PrivacyContent content;

  @override
  Widget build(BuildContext context) {
    return _PrivacyInfoCard(
      icon: Icons.visibility_off_outlined,
      iconColor: Color(0xFF8B5CF6),
      iconBackground: Color(0xFFF5F3FF),
      title: 'Vos droits',
      description: content.rightsDescription,
      onTap: () =>
          _showPrivacyDetails(context, 'Vos droits', content.rightsDetails),
    );
  }
}

class _PrivacyInfoCard extends StatelessWidget {
  _PrivacyInfoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _PrivacyCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PrivacyIcon(
            icon: icon,
            color: iconColor,
            background: iconBackground,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrivacyTitle(title),
                SizedBox(height: 10),
                Text(
                  description,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: textDark, size: 26),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  _PrivacyCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _privacyBorderColor()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: content,
    );
  }
}

class _PrivacyIcon extends StatelessWidget {
  _PrivacyIcon({
    required this.icon,
    this.color,
    this.background,
    this.radius = 24,
  });

  final IconData icon;
  final Color? color;
  final Color? background;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: background ?? primaryBlue.withValues(alpha: .09),
      child: Icon(icon, color: color ?? primaryBlue, size: radius),
    );
  }
}

class _PrivacyTitle extends StatelessWidget {
  _PrivacyTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: textDark,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PrivacyDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: _privacyBorderColor());
  }
}

void _showPrivacyDetails(BuildContext context, String title, String details) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          title,
          style: TextStyle(color: textDark, fontWeight: FontWeight.w900),
        ),
        content: Text(details, style: TextStyle(color: textMuted, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Compris'),
          ),
        ],
      );
    },
  );
}

Color _privacyBorderColor() {
  return ThemeData.estimateBrightnessForColor(cardBg) == Brightness.dark
      ? const Color(0xFF334155)
      : const Color(0xFFE8EDF5);
}

class PrivacyScreen extends StatelessWidget {
  PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.globalText('Confidentialité'),
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
              ),
            ],
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText('Politique de confidentialité'),
                style: TextStyle(
                  color: textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.globalText(
                  'Votre vie privée est importante pour nous. Cette politique explique nos pratiques en matière de collecte, d\'utilisation et de protection de vos données.',
                ),
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.6),
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.globalText('1. Collecte de données'),
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'Nous collectons uniquement les données nécessaires pour fournir nos services.',
                ),
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.6),
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.globalText('2. Protection des données'),
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'Vos données sont protégées par des mesures de sécurité strictes.',
                ),
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfessionalTermsScreen extends StatelessWidget {
  ProfessionalTermsScreen({super.key});

  final _TermsContent _content = _TermsContent.current;

  @override
  Widget build(BuildContext context) {
    syncProfileTheme(context);

    return Scaffold(
      backgroundColor: surfaceBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 430
                ? 430.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(24, 18, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TermsHeader(
                                  onBack: () => Navigator.pop(context),
                                ),
                                SizedBox(height: 26),
                                _TermsHeroCard(content: _content),
                                SizedBox(height: 20),
                                _TermsRulesCard(content: _content),
                                SizedBox(height: 20),
                                _TermsContactCard(content: _content),
                              ],
                            ),
                          ),
                        ),
                        _PremiumProfileBottomNav(
                          onChanged: (index) =>
                              _handleBottomNav(context, index),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleBottomNav(BuildContext context, int index) {
    if (index == 4) return Navigator.pop(context);
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home-commercial',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }

  Future<void> openMail(BuildContext context, String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Impossible d'ouvrir l'application mail.")),
    );
  }
}

class _TermsContent {
  const _TermsContent({
    required this.heroTitle,
    required this.heroDescription,
    required this.rules,
    required this.contactDescription,
    required this.legalEmail,
  });

  final String heroTitle;
  final String heroDescription;
  final List<_TermsRule> rules;
  final String contactDescription;
  final String legalEmail;

  static const current = _TermsContent(
    heroTitle: 'Utilisez PreSales en toute confiance',
    heroDescription:
        "En utilisant PreSales, vous acceptez de respecter les conditions d'utilisation ci-dessous.",
    contactDescription:
        'Pour toute question concernant ces conditions, contactez-nous à :',
    legalEmail: 'legal@presales.com',
    rules: [
      _TermsRule(
        icon: Icons.check_circle_outline_rounded,
        title: 'Acceptation des conditions',
        text:
            "En utilisant l’application PreSales, vous acceptez d’être lié par les présentes conditions d’utilisation. Si vous n’acceptez pas ces conditions, veuillez ne pas utiliser l’application.",
      ),
      _TermsRule(
        icon: Icons.person_outline_rounded,
        title: "Utilisation de l’application",
        text:
            'PreSales est une application professionnelle destinée à aider les commerciaux dans la gestion de leurs clients, commandes, visites et activités.',
      ),
      _TermsRule(
        icon: Icons.lock_outline_rounded,
        title: "Responsabilités de l’utilisateur",
        text:
            "Vous vous engagez à utiliser l’application de manière licite et à ne pas porter atteinte à son bon fonctionnement. Vous êtes responsable de la confidentialité de vos identifiants de connexion.",
      ),
      _TermsRule(
        icon: Icons.block_rounded,
        title: 'Données et confidentialité',
        text:
            'L’utilisation de vos données personnelles est régie par notre Politique de confidentialité. En utilisant PreSales, vous acceptez ces pratiques.',
      ),
      _TermsRule(
        icon: Icons.info_outline_rounded,
        title: 'Modifications des conditions',
        text:
            "Nous nous réservons le droit de modifier ces conditions d’utilisation à tout moment. Les modifications seront publiées dans l’application et entreront en vigueur immédiatement.",
      ),
      _TermsRule(
        icon: Icons.shield_outlined,
        title: 'Résiliation',
        text:
            "Nous pouvons suspendre ou résilier votre accès à PreSales en cas de violation des présentes conditions ou d’utilisation inappropriée de l’application.",
      ),
    ],
  );
}

class _TermsRule {
  const _TermsRule({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;
}

class _TermsHeader extends StatelessWidget {
  _TermsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, size: 30),
          color: primaryBlue,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 42, height: 42),
        ),
        SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Conditions d’utilisation",
                style: TextStyle(
                  color: textDark,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Règles d’utilisation de l'application PreSales",
                style: TextStyle(
                  color: textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TermsHeroCard extends StatelessWidget {
  _TermsHeroCard({required this.content});

  final _TermsContent content;

  @override
  Widget build(BuildContext context) {
    return _TermsCard(
      padding: EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 128,
            height: 118,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.assignment_rounded, color: primaryBlue, size: 82),
                Positioned(
                  right: 22,
                  bottom: 24,
                  child: Icon(
                    Icons.verified_rounded,
                    color: primaryBlue,
                    size: 48,
                  ),
                ),
                Positioned(
                  right: 34,
                  bottom: 36,
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.heroTitle,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  content.heroDescription,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsRulesCard extends StatelessWidget {
  _TermsRulesCard({required this.content});

  final _TermsContent content;

  @override
  Widget build(BuildContext context) {
    return _TermsCard(
      child: Column(
        children: [
          for (var i = 0; i < content.rules.length; i++) ...[
            _TermsRuleRow(index: i + 1, rule: content.rules[i]),
            if (i != content.rules.length - 1) _TermsDivider(),
          ],
        ],
      ),
    );
  }
}

class _TermsRuleRow extends StatelessWidget {
  _TermsRuleRow({required this.index, required this.rule});

  final int index;
  final _TermsRule rule;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TermsIcon(icon: rule.icon),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${rule.title}',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  rule.text,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    height: 1.48,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsContactCard extends StatelessWidget {
  _TermsContactCard({required this.content});

  final _TermsContent content;

  @override
  Widget build(BuildContext context) {
    final mailer = ProfessionalTermsScreen();
    return _TermsCard(
      onTap: () => mailer.openMail(context, content.legalEmail),
      child: Row(
        children: [
          _TermsIcon(icon: Icons.mail_outline_rounded),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  content.contactDescription,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  content.legalEmail,
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textDark, size: 28),
        ],
      ),
    );
  }
}

class _TermsCard extends StatelessWidget {
  _TermsCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _termsBorderColor()),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: content,
    );
  }
}

class _TermsIcon extends StatelessWidget {
  _TermsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: primaryBlue.withValues(alpha: .09),
      child: Icon(icon, color: primaryBlue, size: 24),
    );
  }
}

class _TermsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: _termsBorderColor(), indent: 74);
  }
}

Color _termsBorderColor() {
  return ThemeData.estimateBrightnessForColor(cardBg) == Brightness.dark
      ? const Color(0xFF334155)
      : const Color(0xFFE2E8F0);
}

// PAGE CONDITIONS D'UTILISATION
class TermsScreen extends StatelessWidget {
  TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.globalText('Conditions d\'utilisation'),
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
              ),
            ],
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText('Conditions d\'utilisation'),
                style: TextStyle(
                  color: textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.globalText(
                  'En utilisant cette application, vous acceptez de respecter ces conditions.',
                ),
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.6),
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.globalText('1. Acceptation des conditions'),
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'L\'utilisation de l\'application signifie que vous acceptez les conditions établies.',
                ),
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.6),
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.globalText(
                  '2. Responsabilité de l\'utilisateur',
                ),
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText(
                  'Vous êtes responsable de maintenir la confidentialité de vos identifiants.',
                ),
                style: TextStyle(color: textMuted, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
