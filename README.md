# Guilmin

Application Flutter mobile pour le suivi des opérations de stock dans Odoo.
Guilmin permet aux équipes logistiques de consulter et traiter les transferts,
scanner des produits et des emplacements, gérer les colis et imprimer des
étiquettes ou des rapports.

## Fonctionnalités

- Connexion à Odoo par URL, base de données, e-mail et mot de passe.
- Connexion assistée par QR code Odoo.
- Tableau de bord personnalisable et accès aux types d’opérations.
- Consultation des opérations par état et création de transferts.
- Scan caméra ou saisie PDA d’un code-barres ou d’une référence interne.
- Recherche de produits, consultation du stock et des emplacements.
- Ajout de produits aux brouillons, mise en colis et validation.
- Impression de rapports Odoo et d’étiquettes ZPL vers une imprimante réseau.

## Prérequis

- Flutter avec un SDK Dart compatible avec `sdk: ^3.11.0`.
- Une instance Odoo accessible depuis l’appareil, avec les droits nécessaires
  sur les modules Stock et, si utilisé, Fabrication.
- Pour l’impression ZPL directe : une imprimante réseau accessible en TCP,
  généralement sur le port `9100`.

Les plateformes présentes dans le dépôt sont Android, iOS, Web, Windows,
Linux et macOS. Le scan caméra et l’impression réseau dépendent de la
configuration native de la plateforme.

## Installation

```bash
git clone <url-du-depot>
cd guilmins
flutter pub get
flutter doctor
```

## Lancer l’application

```bash
flutter devices
flutter run
```

Pour cibler une plateforme précise :

```bash
flutter run -d android
flutter run -d chrome
flutter run -d windows
```

Au premier démarrage, renseignez l’URL Odoo sans slash final, le nom de la
base, votre e-mail et votre mot de passe. L’option « Se souvenir de moi »
enregistre ces informations localement ; laissez-la désactivée sur un appareil
partagé.

## Configuration ZPL

Depuis le tableau de bord, ouvrez les paramètres d’impression et renseignez
l’adresse IP, le port TCP (`9100` par défaut), le modèle d’étiquette, la taille
personnalisée si nécessaire, la résolution (`203` ou `300` DPI), la rotation et
l’affichage éventuel du prix.

Les paramètres sont conservés localement avec `shared_preferences`. Les
rapports Odoo nécessitent une session Odoo valide.

## Développement

```bash
flutter analyze
flutter test
flutter build apk --release
```

La version est définie dans `pubspec.yaml` (`1.0.8` actuellement). Elle peut
être surchargée avec `--build-name` et `--build-number`.

## Organisation du code

```text
lib/
  controllers/  Logique d’état et orchestration
  models/       Modèles métier Odoo
  services/     Client Odoo, préférences, PDF et impression ZPL
  views/        Écrans et composants Flutter
assets/images/  Logo et icône de l’application
```

Le client communique avec Odoo via JSON-RPC (`/web/session/authenticate` et
`/web/dataset/call_kw`). Les préférences et réglages sont stockés localement.
Aucun fichier de configuration contenant des secrets ne doit être ajouté au
dépôt.

## Licence

Aucune licence open source n’est actuellement déclarée dans ce dépôt.
