import 'package:flutter/material.dart';

import '../../auth/current_user_session.dart';
import '../../settings/app_appearance_controller.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final AppAppearanceController _appearanceController =
      AppAppearanceController.instance;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color surfaceBg = Color(0xFFF8FAFC);

  AppThemePreference get _currentTheme =>
      CurrentUserSession.currentUser?.theme ?? _appearanceController.theme;

  AppTextSizePreference get _currentTextSize =>
      CurrentUserSession.currentUser?.textSize ??
      _appearanceController.textSize;

  bool get _autoBrightness =>
      CurrentUserSession.currentUser?.autoBrightness ??
      _appearanceController.autoBrightness;

  bool get _powerSavingMode =>
      CurrentUserSession.currentUser?.powerSavingMode ??
      _appearanceController.powerSavingMode;

  String get _textSizeLabel {
    return switch (_currentTextSize) {
      AppTextSizePreference.small => 'Petite',
      AppTextSizePreference.medium => 'Moyenne',
      AppTextSizePreference.large => 'Grande',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appearanceController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _surfaceBg(context),
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
                        color: _surfaceBg(context),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  18,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  children: [
                                    _appearanceHeader(context),
                                    const SizedBox(height: 24),
                                    _themeSection(context),
                                    const SizedBox(height: 20),
                                    _textSizeSection(context),
                                    const SizedBox(height: 20),
                                    _displaySection(context),
                                    const SizedBox(height: 20),
                                    _infoSection(context),
                                  ],
                                ),
                              ),
                            ),
                            _bottomNav(context),
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
      },
    );
  }

  Widget _appearanceHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          color: primaryBlue,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apparence',
                style: TextStyle(
                  color: _primaryText(context),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Personnalisez l'interface de l'application",
                style: TextStyle(
                  color: _mutedText(context),
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

  Widget _themeSection(BuildContext context) {
    return _sectionCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context: context,
            icon: Icons.palette_outlined,
            title: 'Thème',
            subtitle: 'Choisissez le thème qui vous convient',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _themeCard(
                  context: context,
                  title: 'Clair',
                  icon: Icons.wb_sunny_outlined,
                  value: AppThemePreference.light,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _themeCard(
                  context: context,
                  title: 'Sombre',
                  icon: Icons.dark_mode_outlined,
                  value: AppThemePreference.dark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _themeCard(
                  context: context,
                  title: 'Système',
                  icon: Icons.settings_brightness_outlined,
                  value: AppThemePreference.system,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textSizeSection(BuildContext context) {
    return _sectionCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context: context,
            icon: Icons.text_fields_rounded,
            title: 'Taille du texte',
            subtitle: "Ajustez la taille du texte de l'interface",
            trailing: Text(
              _textSizeLabel,
              style: const TextStyle(
                color: primaryBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'A',
                style: TextStyle(
                  color: _primaryText(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _currentTextSize.index.toDouble(),
                  min: 0,
                  max: 2,
                  divisions: 2,
                  activeColor: primaryBlue,
                  inactiveColor: const Color(0xFFE2E8F0),
                  onChanged: (value) {
                    _updateTextSize(
                      AppTextSizePreference.values[value.round()],
                    );
                  },
                ),
              ),
              Text(
                'A',
                style: TextStyle(
                  color: _primaryText(context),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _displaySection(BuildContext context) {
    return _sectionCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context: context,
            icon: Icons.phone_android_rounded,
            title: 'Affichage',
            subtitle: "Options d'affichage supplémentaires",
          ),
          const SizedBox(height: 18),
          _switchRow(
            context: context,
            icon: Icons.wb_sunny_outlined,
            iconColor: const Color(0xFF22C55E),
            title: 'Luminosité automatique',
            subtitle:
                'Ajuster automatiquement la luminosité selon les paramètres du téléphone.',
            value: _autoBrightness,
            onChanged: _updateAutoBrightness,
          ),
          Divider(height: 26, color: _borderColor(context)),
          _switchRow(
            context: context,
            icon: Icons.battery_saver_outlined,
            iconColor: const Color(0xFF8B5CF6),
            title: "Mode économie d'énergie",
            subtitle:
                "Réduire certains effets visuels afin d'améliorer l'autonomie.",
            value: _powerSavingMode,
            onChanged: _updatePowerSavingMode,
          ),
        ],
      ),
    );
  }

  Widget _infoSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark(context)
            ? const Color(0xFF172554)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Vos préférences d'apparence sont enregistrées automatiquement.",
              style: TextStyle(
                color: _mutedText(context),
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required BuildContext context, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _isDark(context) ? 0.18 : 0.035,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _isDark(context)
              ? const Color(0xFF1E3A8A)
              : const Color(0xFFEFF6FF),
          child: Icon(icon, color: primaryBlue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _primaryText(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: _mutedText(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _themeCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required AppThemePreference value,
  }) {
    final selected = _currentTheme == value;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _updateTheme(value),
      child: Container(
        height: 165,
        decoration: BoxDecoration(
          color: _cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primaryBlue : _borderColor(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: primaryBlue),
            const SizedBox(height: 22),
            Text(
              title,
              style: TextStyle(
                color: _primaryText(context),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? primaryBlue : _mutedText(context),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _primaryText(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: _mutedText(context),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: primaryBlue,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _updateTheme(AppThemePreference value) async {
    await _appearanceController.setTheme(value);
  }

  Future<void> _updateTextSize(AppTextSizePreference value) async {
    await _appearanceController.setTextSize(value);
  }

  Future<void> _updateAutoBrightness(bool value) async {
    await _appearanceController.setAutoBrightness(value);
  }

  Future<void> _updatePowerSavingMode(bool value) async {
    await _appearanceController.setPowerSavingMode(value);
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _surfaceBg(BuildContext context) {
    return _isDark(context) ? Colors.black : surfaceBg;
  }

  Color _cardBg(BuildContext context) {
    return _isDark(context) ? const Color(0xFF111111) : Colors.white;
  }

  Color _borderColor(BuildContext context) {
    return _isDark(context) ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  }

  Color _primaryText(BuildContext context) {
    return _isDark(context) ? const Color(0xFFF8FAFC) : textDark;
  }

  Color _mutedText(BuildContext context) {
    return _isDark(context) ? const Color(0xFFCBD5E1) : textMuted;
  }

  Color _bottomNavBg(BuildContext context) {
    return _isDark(context) ? const Color(0xFF111111) : Colors.white;
  }

  Color _bottomNavInactive(BuildContext context) {
    return _isDark(context) ? const Color(0xFF94A3B8) : textMuted;
  }

  Color _bottomNavShadow(BuildContext context) {
    return Colors.black.withValues(alpha: _isDark(context) ? 0.22 : 0.06);
  }

  Widget _bottomNav(BuildContext context) {
    final items = [
      [Icons.home_outlined, 'Accueil'],
      [Icons.groups_outlined, 'Clients'],
      [Icons.receipt_long_outlined, 'Commandes'],
      [Icons.pie_chart_outline_rounded, 'Activités'],
      [Icons.person_outline_rounded, 'Profil'],
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _bottomNavBg(context),
        boxShadow: [
          BoxShadow(
            color: _bottomNavShadow(context),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: List.generate(items.length, (index) {
              final isActive = index == 4;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (index == 4) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home-commercial',
                        (route) => false,
                        arguments: {'initialIndex': index},
                      );
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index][0] as IconData,
                        color: isActive
                            ? primaryBlue
                            : _bottomNavInactive(context),
                        size: 27,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index][1] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isActive
                              ? primaryBlue
                              : _bottomNavInactive(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
