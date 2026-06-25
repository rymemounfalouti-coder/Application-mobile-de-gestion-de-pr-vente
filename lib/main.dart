import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/auth/login_screen.dart';
import 'package:gestion_prevente/screens/commercial/home_commercial_entry.dart';
import 'screens/home_screen.dart';
import 'screens/manager/home_manager_screen.dart';
import 'l10n/app_locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'settings/app_appearance_controller.dart';

const String _appFontFamily = 'Roboto';
const Color _primaryBlue = Color(0xFF2563EB);
const Color _textDark = Color(0xFF0F172A);
const Color _textMuted = Color(0xFF64748B);
const Color _surfaceBg = Color(0xFFF8FAFC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await AppLocaleController.instance.load();
  await AppAppearanceController.instance.load();

  runApp(
    MyApp(
      localeController: AppLocaleController.instance,
      appearanceController: AppAppearanceController.instance,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.localeController,
    required this.appearanceController,
  });

  final AppLocaleController localeController;
  final AppAppearanceController appearanceController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, appearanceController]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: localeController.locale,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                disableAnimations: appearanceController.powerSavingMode,
                textScaler: TextScaler.linear(
                  appearanceController.textScaleFactor,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: false,
            fontFamily: _appFontFamily,
            primaryColor: _primaryBlue,
            scaffoldBackgroundColor: _surfaceBg,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: _textDark,
              elevation: 0,
              iconTheme: IconThemeData(color: _textDark),
              titleTextStyle: TextStyle(
                fontFamily: _appFontFamily,
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                fontFamily: _appFontFamily,
                color: _textDark,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
              headlineLarge: TextStyle(
                fontFamily: _appFontFamily,
                color: _textDark,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
              headlineMedium: TextStyle(
                fontFamily: _appFontFamily,
                color: _textDark,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              titleLarge: TextStyle(
                fontFamily: _appFontFamily,
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              titleMedium: TextStyle(
                fontFamily: _appFontFamily,
                color: _textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              bodyLarge: TextStyle(
                fontFamily: _appFontFamily,
                color: _textDark,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              bodyMedium: TextStyle(
                fontFamily: _appFontFamily,
                color: _textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              bodySmall: TextStyle(
                fontFamily: _appFontFamily,
                color: _textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            primaryTextTheme: const TextTheme(
              titleLarge: TextStyle(
                fontFamily: _appFontFamily,
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              bodyMedium: TextStyle(
                fontFamily: _appFontFamily,
                color: _textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(
                fontFamily: _appFontFamily,
                color: _textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              hintStyle: TextStyle(
                fontFamily: _appFontFamily,
                color: _textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              helperStyle: TextStyle(
                fontFamily: _appFontFamily,
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              errorStyle: TextStyle(
                fontFamily: _appFontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(
                  fontFamily: _appFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                textStyle: const TextStyle(
                  fontFamily: _appFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(
                  fontFamily: _appFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              selectedLabelStyle: TextStyle(
                fontFamily: _appFontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontFamily: _appFontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            tabBarTheme: const TabBarThemeData(
              labelStyle: TextStyle(
                fontFamily: _appFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontFamily: _appFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            listTileTheme: const ListTileThemeData(
              titleTextStyle: TextStyle(
                fontFamily: _appFontFamily,
                color: _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              subtitleTextStyle: TextStyle(
                fontFamily: _appFontFamily,
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            snackBarTheme: const SnackBarThemeData(
              contentTextStyle: TextStyle(
                fontFamily: _appFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: false,
            fontFamily: _appFontFamily,
            primaryColor: _primaryBlue,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF111111),
              foregroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                fontFamily: _appFontFamily,
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            colorScheme: const ColorScheme.dark(
              primary: _primaryBlue,
              surface: Color(0xFF111111),
            ),
          ),
          themeMode: appearanceController.themeMode,
          initialRoute: '/login',
          routes: {
            '/login': (_) => LoginScreen(),
            '/forgot-password': (_) => ForgotPasswordScreen(),
            '/reset-password': (context) {
              final token =
                  ModalRoute.of(context)?.settings.arguments as String?;
              return ResetPasswordScreen(token: token ?? '');
            },
            '/home': (_) => HomeScreen(),
            '/home-commercial': (_) => HomeCommercial(),
            '/home-manager': (_) => DashboardManager(),
            '/manager-commerciaux': (_) => CommerciauxManager(),
            '/manager-commandes': (_) => OrdersManagerScreen(),
            '/manager-objectifs': (_) => ObjectifsManagerScreen(),
            '/manager-rapports': (_) => ReportsManagerScreen(),
            '/manager-profil': (_) => ProfileManagerScreen(),
            '/dashboard-admin': (_) => DashboardAdmin(),
          },
        );
      },
    );
  }
}
