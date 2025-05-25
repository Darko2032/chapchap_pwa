# CHAP-CHAP

Application mobile et web (PWA) de recharge pour les utilisateurs en Côte d'Ivoire. Permet aux utilisateurs d'acheter des unités et des forfaits pour les trois principaux opérateurs : Orange, MTN et Moov.

## Fonctionnalités

- Acheter des recharges d'unités pour Orange, MTN et Moov
- Acheter des forfaits internet, appels et SMS pour chaque opérateur
- Paiement via Orange Money, MTN Mobile Money, Moov Money ou Wave
- Historique des achats
- Interface utilisateur simple et intuitive

## Technologies utilisées

- Flutter pour le développement mobile et web (PWA)
- EmailJS pour l'envoi des commandes par email
- SharedPreferences pour le stockage local des données
- Service Worker pour le fonctionnement hors ligne de la PWA
- APIs web pour les notifications et l'installation sur l'écran d'accueil

## Structure du projet

```
CHAP-CHAP/
├── lib/
│   ├── data/                   # Modèles de données
│   │   └── forfait_model.dart
│   ├── database/
│   │   └── local_storage.dart  # Gestion du stockage local
│   ├── screens/
│   │   ├── home_screen.dart    # Écran principal (commandes)
│   │   ├── history_screen.dart # Historique des transactions
│   │   └── logs_screen.dart    # Interface de débogage (accès admin)
│   ├── email_test.dart         # Implémentation des fonctions EmailJS
│   └── main.dart               # Point d'entrée de l'application
├── assets/
│   └── images/                 # Images et ressources
├── forfaits.json               # Catalogue des forfaits disponibles
└── pubspec.yaml                # Configuration du projet Flutter
```

## Installation

1. Assurez-vous que Flutter est installé sur votre système
2. Clonez ce dépôt
3. Exécutez `flutter pub get` pour installer les dépendances
4. Remplacez les valeurs de `SERVICE_ID`, `TEMPLATE_ID` et `PUBLIC_KEY` dans le fichier `email_test.dart` par vos propres identifiants EmailJS
5. Exécutez l'application avec `flutter run`

## Déploiement

### Version Android

Pour créer le fichier APK :

```bash
flutter build apk --release
```

Le fichier APK sera disponible dans `build/app/outputs/flutter-apk/app-release.apk`

### Version PWA (Web)

Pour construire la version web :

```bash
flutter build web --release
```

#### Déploiement sur Render

1. Créez un compte sur [Render](https://render.com/)
2. Créez un nouveau service "Static Site"
3. Connectez votre dépôt GitHub
4. Configurez le service :
   - **Build Command**: `flutter build web --release`
   - **Publish Directory**: `build/web`
5. Cliquez sur "Create Static Site"

## Configuration EmailJS

L'application utilise EmailJS pour envoyer les commandes. Vous devez créer un compte sur [EmailJS](https://www.emailjs.com/) et configurer :

1. Un service (par exemple Gmail)
2. Un template d'email contenant les variables suivantes :
   - {{reseau}} - L'opérateur choisi
   - {{type}} - Le type de recharge (Unités ou Forfait)
   - {{numero}} - Le numéro à recharger
   - {{montant}} - Le montant pour les unités
   - {{forfait}} - Les détails du forfait
   - {{total}} - Le montant total
   - {{numero_transaction}} - Le numéro ayant effectué le paiement

## Accès administrateur

Un "easter egg" permet d'accéder à l'écran des logs pour les administrateurs :
- Tapez 10 fois rapidement sur le titre "CHAP-CHAP" dans la barre d'application

## Personnalisation

Pour ajouter ou modifier les forfaits disponibles, éditez le fichier `forfaits.json` en suivant la structure existante.

## Licence

© 2025 CHAP-CHAP. Tous droits réservés.
