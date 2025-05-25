#!/usr/bin/env bash
# exit on error
set -e

# Installer Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"
flutter doctor -v
flutter channel stable
flutter upgrade

# Installer les dépendances du projet
flutter pub get

# Construire la version web
flutter build web --release

# Copier le contenu du build dans le dossier public
cp -R build/web/. public/

echo "Build completed"
