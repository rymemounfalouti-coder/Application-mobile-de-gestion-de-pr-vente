# Guide d'Utilisation - Page Profil

## Accès à la Page Profil

### Par Bottom Navigation
1. Ouvrez l'application
2. Connectez-vous avec un utilisateur commercial
3. Naviguez vers l'onglet "Profil" (5e icône en bas)

### Par Code de Navigation
```dart
// Naviguer directement vers la page profil (index 4)
onNavigate(4);
```

## Structure de la Page Profil

### 1. En-tête (Header)
- **Titre**: "Profil"
- **Sous-titre**: "Gérez vos informations personnelles et les paramètres de l'application"
- **Icône Notifications**: Badge rouge affichant le nombre de notifications (actuellement 3)

### 2. Section Profil
Grande carte affichant:
- Avatar circulaire avec initiales
- Nom complet
- Rôle (Commercial)
- Email professionnel
- Société (Ryme Distribution)
- Icône caméra pour changer la photo

**Actions**:
- Cliquer sur la photo: Action disponible pour changer l'image
- Cliquer sur la carte: Ouvre les informations personnelles

### 3. Section "Mon Compte"

#### Informations Personnelles
- **Icône**: Person
- **Fonction**: Modifier prénom, nom, téléphone, email, adresse
- **Bouton**: Enregistrer les modifications

#### Sécurité
- **Icône**: Lock
- **Options**:
  - Changer mot de passe
  - Authentification biométrique
  - Historique des connexions

#### Notifications
- **Icône**: Bell
- **Toggles**:
  - Notifications commandes
  - Notifications clients
  - Notifications système
  - Sons
  - Vibration

#### Langue
- **Icône**: Globe
- **Options**: 
  - Français (défaut)
  - العربية (Arabe)
  - English (Anglais)
- **Affichage**: Langue sélectionnée comme sous-titre

#### Apparence
- **Icône**: Palette
- **Options**:
  - Clair (défaut)
  - Sombre
  - Automatique
- **Affichage**: Thème sélectionné comme sous-titre

### 4. Section "À Propos"

#### À propos de l'application
- Version: 1.0.0

#### Confidentialité
- Affiche la politique de confidentialité

#### Conditions d'utilisation
- Affiche les conditions d'utilisation

### 5. Bouton Déconnexion
- Bouton rouge avec icône logout
- **Action**: Affiche une confirmation
  - "Voulez-vous vraiment vous déconnecter?"
  - Boutons: "Annuler" / "Confirmer"
- **Résultat**: Déconnecte l'utilisateur et retourne à la page Login

## Données Affichées

Toutes les données proviennent de l'utilisateur connecté:
```dart
// Données dynamiques du commercial
- Nom: user.name
- Email: user.email
- Téléphone: user.phone
- Rôle: 'Commercial'
- Société: 'Ryme Distribution' (actuellement mockée)
```

**Aucune valeur n'est codée en dur** - Les données changent en fonction de l'utilisateur connecté.

## Personnalisation et Extension

### Ajouter un nouveau paramètre
1. Ouvrir `profile_screen.dart`
2. Créer une nouvelle page (ex: `class MySettingScreen extends StatefulWidget`)
3. Ajouter un `_MenuItem` dans la section appropriée:
```dart
_MenuItem(
  icon: Icons.my_icon,
  title: 'Mon Titre',
  subtitle: 'Mon Sous-titre',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MySettingScreen()),
    );
  },
),
```

### Intégrer la persistance
- Remplacer les `ScaffoldMessenger.showSnackBar()` par des appels API
- Utiliser une base de données locale (SQLite/Hive) pour stocker les préférences
- Synchroniser avec un backend API

### Changer les couleurs
Tous les couleurs sont définies en haut du fichier:
```dart
const Color primaryBlue = Color(0xFF2563EB);
const Color textDark = Color(0xFF0F172A);
const Color textMuted = Color(0xFF64748B);
const Color surfaceBg = Color(0xFFF8FAFC);
const Color cardBg = Color(0xFFFFFFFF);
const Color errorRed = Color(0xFFEF4444);
```

## States Gérés

### ProfileCommercialScreen
- `_selectedLanguage`: Langue actuelle
- `_selectedTheme`: Thème actuel
- `userProfile`: Profil de l'utilisateur

### PersonalInfoScreen
- `_nameController`: Nom
- `_firstNameController`: Prénom
- `_phoneController`: Téléphone
- `_emailController`: Email (désactivé)
- `_addressController`: Adresse

### NotificationsScreen
- `_ordersNotifications`: Toggle commandes
- `_clientsNotifications`: Toggle clients
- `_systemNotifications`: Toggle système
- `_soundEnabled`: Toggle sons
- `_vibrationEnabled`: Toggle vibration

### LanguageScreen
- `_selectedLanguage`: Langue sélectionnée

### AppearanceScreen
- `_selectedTheme`: Thème sélectionné

## Comportements Attendus

✅ **Connexion dynamique**: Les données affichées correspondent à l'utilisateur connecté
✅ **Navigation**: Tous les liens ouvrent les sous-pages correspondantes
✅ **Déconnexion**: Le bouton déconnexion propose une confirmation avant de procéder
✅ **Paramètres**: Les préférences (langue, thème) peuvent être changées
✅ **Design**: Interface professionnelle, moderne, responsive
✅ **Accessibilité**: Navigation claire, textes lisibles, icônes explicites

## Dépannage

### Les données utilisateur n'apparaissent pas
- Vérifier que `CurrentUserSession.currentUser` est défini
- Vérifier que l'utilisateur existe dans `MockPreSalesData.users`

### La page de profil ne s'affiche pas
- Vérifier l'index de navigation (doit être 4)
- Vérifier l'import: `import 'profile_screen.dart';`
- Vérifier que `ProfileCommercialScreen` est utilisée dans `IndexedStack`

### Les modifications ne sont pas sauvegardées
- Les modifications sont actuellement affichées en tant que messages
- Pour la persistance réelle, intégrer une base de données ou une API backend
