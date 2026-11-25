#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="/tmp/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Clonando Flutter SDK (branch stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi

git config --global --add safe.directory "$FLUTTER_DIR" || true
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release
