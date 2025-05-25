#!/bin/bash
# Script simplifié pour Render

# Nous ne pouvons pas exécuter Flutter directement sur un site statique Render
# Au lieu de cela, nous copions simplement notre dossier build/web précompilé

# Créer le dossier public s'il n'existe pas
mkdir -p public

# Copier tous les fichiers statiques nécessaires
cp -R web/* public/

# S'assurer que l'index.html est présent
if [ ! -f "public/index.html" ]; then
  echo "<!DOCTYPE html>
<html>
<head>
  <title>CHAP-CHAP</title>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <style>
    body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
  </style>
</head>
<body>
  <h1>CHAP-CHAP</h1>
  <p>Application en cours de déploiement...</p>
</body>
</html>" > public/index.html
fi

echo "Static files prepared"
