import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'generated_app_localizations_ar.dart';
import 'generated_app_localizations_en.dart';
import 'generated_app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of GeneratedAppLocalizations
/// returned by `GeneratedAppLocalizations.of(context)`.
///
/// Applications need to include `GeneratedAppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/generated_app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: GeneratedAppLocalizations.localizationsDelegates,
///   supportedLocales: GeneratedAppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the GeneratedAppLocalizations.supportedLocales
/// property.
abstract class GeneratedAppLocalizations {
  GeneratedAppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static GeneratedAppLocalizations of(BuildContext context) {
    return Localizations.of<GeneratedAppLocalizations>(
      context,
      GeneratedAppLocalizations,
    )!;
  }

  static const LocalizationsDelegate<GeneratedAppLocalizations> delegate =
      _GeneratedAppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'Gestion Prévente'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get home;

  /// No description provided for @clients.
  ///
  /// In fr, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @orders.
  ///
  /// In fr, this message translates to:
  /// **'Commandes'**
  String get orders;

  /// No description provided for @activities.
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get activities;

  /// No description provided for @profile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @security.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get security;

  /// No description provided for @personalInformation.
  ///
  /// In fr, this message translates to:
  /// **'Informations personnelles'**
  String get personalInformation;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get appearance;

  /// No description provided for @myAccount.
  ///
  /// In fr, this message translates to:
  /// **'Mon compte'**
  String get myAccount;

  /// No description provided for @about.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get about;

  /// No description provided for @privacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get terms;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get logout;

  /// No description provided for @commercial.
  ///
  /// In fr, this message translates to:
  /// **'Commercial'**
  String get commercial;

  /// No description provided for @profileSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérez vos informations personnelles\net les paramètres de l\'application'**
  String get profileSubtitle;

  /// No description provided for @manageProfileInfo.
  ///
  /// In fr, this message translates to:
  /// **'Gérez vos informations de profil'**
  String get manageProfileInfo;

  /// No description provided for @securitySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe, empreinte, connexion'**
  String get securitySubtitle;

  /// No description provided for @notificationPreferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences de notifications'**
  String get notificationPreferences;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Thème Clair'**
  String get themeLight;

  /// No description provided for @aboutApp.
  ///
  /// In fr, this message translates to:
  /// **'À propos de l\'application'**
  String get aboutApp;

  /// No description provided for @version.
  ///
  /// In fr, this message translates to:
  /// **'Version 1.0.0'**
  String get version;

  /// No description provided for @privacyPolicy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get privacyPolicy;

  /// No description provided for @readTerms.
  ///
  /// In fr, this message translates to:
  /// **'Lire les conditions'**
  String get readTerms;

  /// No description provided for @languageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre langue préférée'**
  String get languageSubtitle;

  /// No description provided for @currentLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue actuelle'**
  String get currentLanguage;

  /// No description provided for @chooseLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une langue'**
  String get chooseLanguage;

  /// No description provided for @languageCurrentInfo.
  ///
  /// In fr, this message translates to:
  /// **'L\'interface de l\'application sera affichée dans la langue sélectionnée.'**
  String get languageCurrentInfo;

  /// No description provided for @current.
  ///
  /// In fr, this message translates to:
  /// **'Actuelle'**
  String get current;

  /// No description provided for @french.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get french;

  /// No description provided for @frenchNative.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get frenchNative;

  /// No description provided for @arabic.
  ///
  /// In fr, this message translates to:
  /// **'Arabe'**
  String get arabic;

  /// No description provided for @arabicNative.
  ///
  /// In fr, this message translates to:
  /// **'العربية'**
  String get arabicNative;

  /// No description provided for @english.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get english;

  /// No description provided for @englishNative.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get englishNative;

  /// No description provided for @preview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get preview;

  /// No description provided for @languagePreviewInfo.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez voir l\'interface de l\'application dans la langue sélectionnée.'**
  String get languagePreviewInfo;

  /// No description provided for @applyLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer la langue'**
  String get applyLanguage;

  /// No description provided for @languageSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Langue mise à jour avec succès'**
  String get languageSuccess;

  /// No description provided for @languageDeviceInfo.
  ///
  /// In fr, this message translates to:
  /// **'Ce paramètre sera appliqué sur tous vos appareils connectés.'**
  String get languageDeviceInfo;

  /// No description provided for @stayInformed.
  ///
  /// In fr, this message translates to:
  /// **'Restez informé'**
  String get stayInformed;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérez vos préférences de notifications'**
  String get notificationsSubtitle;

  /// No description provided for @notificationsIntro.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez comment et quand vous souhaitez recevoir vos notifications.'**
  String get notificationsIntro;

  /// No description provided for @orderNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications commandes'**
  String get orderNotifications;

  /// No description provided for @orderNotificationsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des alertes de commandes'**
  String get orderNotificationsSubtitle;

  /// No description provided for @clientNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications clients'**
  String get clientNotifications;

  /// No description provided for @clientNotificationsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des alertes clients'**
  String get clientNotificationsSubtitle;

  /// No description provided for @systemNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications système'**
  String get systemNotifications;

  /// No description provided for @systemNotificationsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des alertes système'**
  String get systemNotificationsSubtitle;

  /// No description provided for @audioSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres audio'**
  String get audioSettings;

  /// No description provided for @sounds.
  ///
  /// In fr, this message translates to:
  /// **'Sons'**
  String get sounds;

  /// No description provided for @soundsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer les sons de notification'**
  String get soundsSubtitle;

  /// No description provided for @vibration.
  ///
  /// In fr, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @vibrationSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer la vibration'**
  String get vibrationSubtitle;

  /// No description provided for @receiptsAndReminders.
  ///
  /// In fr, this message translates to:
  /// **'Reçus et rappels'**
  String get receiptsAndReminders;

  /// No description provided for @quietHours.
  ///
  /// In fr, this message translates to:
  /// **'Heures de silence'**
  String get quietHours;

  /// No description provided for @quietHoursSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Définir les heures pendant lesquelles vous ne souhaitez pas recevoir de notifications'**
  String get quietHoursSubtitle;

  /// No description provided for @activityReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels d\'activité'**
  String get activityReminders;

  /// No description provided for @activityRemindersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir des rappels pour vos activités planifiées'**
  String get activityRemindersSubtitle;

  /// No description provided for @notificationChannels.
  ///
  /// In fr, this message translates to:
  /// **'Canaux de notification'**
  String get notificationChannels;

  /// No description provided for @push.
  ///
  /// In fr, this message translates to:
  /// **'Push'**
  String get push;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @sms.
  ///
  /// In fr, this message translates to:
  /// **'SMS'**
  String get sms;

  /// No description provided for @enabled.
  ///
  /// In fr, this message translates to:
  /// **'Activé'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get disabled;

  /// No description provided for @preferencesUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Préférences mises à jour'**
  String get preferencesUpdated;

  /// No description provided for @startTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure début'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure fin'**
  String get endTime;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @apply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get apply;

  /// No description provided for @channel.
  ///
  /// In fr, this message translates to:
  /// **'Canal'**
  String get channel;

  /// No description provided for @receiveNotificationsBy.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir les notifications par'**
  String get receiveNotificationsBy;

  /// No description provided for @doNotReceiveNotificationsBy.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas recevoir les notifications par'**
  String get doNotReceiveNotificationsBy;

  /// No description provided for @newClient.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau client'**
  String get newClient;

  /// No description provided for @newOrder.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle commande'**
  String get newOrder;

  /// No description provided for @orderDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails commande'**
  String get orderDetails;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @notProvided.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get notProvided;
}

class _GeneratedAppLocalizationsDelegate
    extends LocalizationsDelegate<GeneratedAppLocalizations> {
  const _GeneratedAppLocalizationsDelegate();

  @override
  Future<GeneratedAppLocalizations> load(Locale locale) {
    return SynchronousFuture<GeneratedAppLocalizations>(
      lookupGeneratedAppLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_GeneratedAppLocalizationsDelegate old) => false;
}

GeneratedAppLocalizations lookupGeneratedAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return GeneratedAppLocalizationsAr();
    case 'en':
      return GeneratedAppLocalizationsEn();
    case 'fr':
      return GeneratedAppLocalizationsFr();
  }

  throw FlutterError(
    'GeneratedAppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
