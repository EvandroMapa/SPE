#!/bin/bash
echo "Baixando o Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "Habilitando Flutter Web..."
flutter config --enable-web

echo "Baixando dependências..."
flutter pub get

echo "Compilando o app para Web..."
flutter build web --release --web-renderer canvaskit
