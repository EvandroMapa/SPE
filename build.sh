#!/bin/bash
set -e
FLUTTER_VERSION="3.41.5"

# Reutiliza o cache do Flutter se a versao instalada ja for a correta.
# So clona novamente se a versao for diferente ou se a pasta nao existir.
INSTALLED_VERSION=""
if [ -f "flutter/bin/flutter" ]; then
  INSTALLED_VERSION=$(flutter/bin/flutter --version --machine 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('frameworkVersion',''))" 2>/dev/null || echo "")
fi

if [ "$INSTALLED_VERSION" != "$FLUTTER_VERSION" ]; then
  echo "Flutter ${INSTALLED_VERSION:-nao encontrado} != ${FLUTTER_VERSION}. Clonando..."
  rm -rf flutter
  git clone https://github.com/flutter/flutter.git --branch ${FLUTTER_VERSION} --depth 1
else
  echo "Flutter ${FLUTTER_VERSION} ja em cache. Pulando clone."
fi

export PATH="$PATH:$(pwd)/flutter/bin"
echo "Building Flutter Web com Flutter ${FLUTTER_VERSION}..."
flutter pub get
BUILD_HASH=${VERCEL_GIT_COMMIT_SHA:0:7}
flutter build web --release --dart-define=APP_ENV=${APP_ENV:-dev} --dart-define=BUILD_HASH=${BUILD_HASH:-local}
