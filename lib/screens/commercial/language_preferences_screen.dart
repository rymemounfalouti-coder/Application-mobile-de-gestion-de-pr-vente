import 'package:flutter/material.dart';

import '../../l10n/app_locale_controller.dart';
import '../../l10n/app_localizations.dart';

Color _primaryBlue = Color(0xFF2563EB);
Color _textDark = Color(0xFF0F172A);
Color _textMuted = Color(0xFF64748B);
Color _surfaceBg = Color(0xFFF8FAFC);
Color _cardBg = Colors.white;
Color _borderColor = Color(0xFFE2E8F0);

void _syncLanguageTheme(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  _textDark = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  _textMuted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
  _surfaceBg = isDark ? Colors.black : const Color(0xFFF8FAFC);
  _cardBg = isDark ? const Color(0xFF111111) : Colors.white;
  _borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
}

bool _isLanguageDarkMode() => _cardBg != Colors.white;

Color _languageShadowColor([double lightAlpha = .06]) {
  return _isLanguageDarkMode()
      ? Colors.black.withValues(alpha: .22)
      : _textDark.withValues(alpha: lightAlpha);
}

class LanguagePreferencesScreen extends StatefulWidget {
  LanguagePreferencesScreen({super.key});

  @override
  State<LanguagePreferencesScreen> createState() =>
      _LanguagePreferencesScreenState();
}

class _LanguagePreferencesScreenState extends State<LanguagePreferencesScreen> {
  late Locale _selectedLocale;

  bool get _hasChanges =>
      _selectedLocale.languageCode !=
      AppLocaleController.instance.locale.languageCode;

  @override
  void initState() {
    super.initState();
    _selectedLocale = AppLocaleController.instance.locale;
  }

  @override
  Widget build(BuildContext context) {
    _syncLanguageTheme(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: _surfaceBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 428
                ? 428.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _surfaceBg,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _languageShadowColor(0.08),
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
                          child: CustomScrollView(
                            physics: BouncingScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(20, 18, 20, 22),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _header(l10n),
                                    SizedBox(height: 24),
                                    _currentLanguageCard(l10n),
                                    SizedBox(height: 26),
                                    _sectionTitle(l10n.chooseLanguage),
                                    SizedBox(height: 14),
                                    _languageOptions(l10n),
                                    SizedBox(height: 24),
                                    _previewCard(l10n),
                                    SizedBox(height: 22),
                                    _applyButton(l10n),
                                    SizedBox(height: 18),
                                    _deviceInfo(l10n),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _LanguageBottomNav(onChanged: _navigateHome),
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

  Widget _header(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded),
          color: _primaryBlue,
          style: IconButton.styleFrom(backgroundColor: _cardBg),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.language,
                style: TextStyle(
                  color: _textDark,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              SizedBox(height: 7),
              Text(
                l10n.languageSubtitle,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _currentLanguageCard(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: _cardDecoration(24),
      child: Row(
        children: [
          _circleIcon(Icons.language_rounded),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.currentLanguage,
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 9),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _languageName(l10n, AppLocaleController.instance.locale),
                    style: TextStyle(
                      color: _primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  l10n.languageCurrentInfo,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 78,
            height: 72,
            child: Stack(
              children: [
                Positioned(top: 8, left: 4, child: _translationBubble('A')),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: _translationBubble('æ–‡'),
                ),
                Positioned(
                  right: 0,
                  bottom: 1,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _translationBubble(String label) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryBlue.withValues(alpha: 0.18)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: _primaryBlue.withValues(alpha: 0.65),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Text(
      label,
      style: TextStyle(
        color: _textDark,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _languageOptions(AppLocalizations l10n) {
    final options = [
      _LanguageOption(
        locale: Locale('fr'),
        flag: 'ðŸ‡«ðŸ‡·',
        nativeName: l10n.frenchNative,
        displayName: l10n.french,
      ),
      _LanguageOption(
        locale: Locale('ar'),
        flag: 'ðŸ‡¸ðŸ‡¦',
        nativeName: l10n.arabicNative,
        displayName: l10n.arabic,
      ),
      _LanguageOption(
        locale: Locale('en'),
        flag: 'ðŸ‡ºðŸ‡¸',
        nativeName: l10n.englishNative,
        displayName: l10n.english,
      ),
    ];

    return Container(
      decoration: _cardDecoration(18),
      child: Column(
        children: List.generate(options.length, (index) {
          final option = options[index];
          final selected =
              option.locale.languageCode == _selectedLocale.languageCode;
          final current =
              option.locale.languageCode ==
              AppLocaleController.instance.locale.languageCode;

          return Column(
            children: [
              InkWell(
                onTap: () => setState(() => _selectedLocale = option.locale),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 16, 18),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected ? _primaryBlue : _textMuted,
                        size: 30,
                      ),
                      SizedBox(width: 16),
                      Text(option.flag, style: TextStyle(fontSize: 42)),
                      SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.nativeName,
                              style: TextStyle(
                                color: _textDark,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              option.displayName,
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (current)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF22C55E).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.current,
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _textDark,
                          size: 26,
                        ),
                    ],
                  ),
                ),
              ),
              if (index != options.length - 1)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(
                    color: _borderColor.withValues(alpha: 0.9),
                    height: 1,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _previewCard(AppLocalizations l10n) {
    final preview = _previewLabels(_selectedLocale);
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primaryBlue.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _primaryBlue, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.preview,
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  l10n.languagePreviewInfo,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  preview.join(' · '),
                  style: TextStyle(
                    color: _primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          _circleIcon(Icons.phone_iphone_rounded, size: 52, iconSize: 26),
        ],
      ),
    );
  }

  Widget _applyButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: _hasChanges ? () => _applyLanguage(l10n) : null,
        icon: Icon(Icons.language_rounded),
        label: Text(l10n.applyLanguage),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          disabledBackgroundColor: _primaryBlue.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: _primaryBlue.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _deviceInfo(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, color: _textMuted, size: 18),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            l10n.languageDeviceInfo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _applyLanguage(AppLocalizations l10n) async {
    await AppLocaleController.instance.setLocale(_selectedLocale);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.languageSuccess),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1400),
        ),
      );
    setState(() {});
  }

  String _languageName(AppLocalizations l10n, Locale locale) {
    return switch (locale.languageCode) {
      'en' => l10n.englishNative,
      'ar' => l10n.arabicNative,
      _ => l10n.frenchNative,
    };
  }

  List<String> _previewLabels(Locale locale) {
    return switch (locale.languageCode) {
      'en' => ['Home', 'Clients', 'Orders', 'Activities', 'Profile'],
      'ar' => [
        'Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ©',
        'Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡',
        'Ø§Ù„Ø·Ù„Ø¨Ø§Øª',
        'Ø§Ù„Ø£Ù†Ø´Ø·Ø©',
        'Ø§Ù„Ù…Ù„Ù Ø§Ù„Ø´Ø®ØµÙŠ',
      ],
      _ => ['Accueil', 'Clients', 'Commandes', 'Activités', 'Profil'],
    };
  }

  void _navigateHome(int index) {
    if (index == 4) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home-commercial',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }
}

class _LanguageOption {
  _LanguageOption({
    required this.locale,
    required this.flag,
    required this.nativeName,
    required this.displayName,
  });

  final Locale locale;
  final String flag;
  final String nativeName;
  final String displayName;
}

class _LanguageBottomNav extends StatelessWidget {
  _LanguageBottomNav({required this.onChanged});

  final ValueChanged<int> onChanged;

  static final _icons = [
    Icons.home_outlined,
    Icons.groups_outlined,
    Icons.receipt_long_outlined,
    Icons.pie_chart_outline_rounded,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      l10n.home,
      l10n.clients,
      l10n.orders,
      l10n.activities,
      l10n.profile,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: _borderColor)),
        boxShadow: [
          BoxShadow(
            color: _languageShadowColor(0.09),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: EdgeInsets.only(top: 9),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icons[i],
                            color: i == 4 ? _primaryBlue : _textMuted,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: i == 4 ? _primaryBlue : _textMuted,
                              fontSize: 10,
                              fontWeight: i == 4
                                  ? FontWeight.w900
                                  : FontWeight.w700,
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
    );
  }
}

BoxDecoration _cardDecoration(double radius) {
  return BoxDecoration(
    color: _cardBg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _borderColor.withValues(alpha: 0.55)),
    boxShadow: [
      BoxShadow(
        color: _languageShadowColor(0.06),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}

Widget _circleIcon(IconData icon, {double size = 62, double iconSize = 30}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _primaryBlue.withValues(alpha: 0.09),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: _primaryBlue, size: iconSize),
  );
}
