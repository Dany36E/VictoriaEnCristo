#!/bin/bash
# Instala Flutter en las sesiones de Claude Code en la nube para que
# `flutter analyze` y `flutter test` funcionen (y el hook de Stop pueda verificar).
set -euo pipefail

# Solo en la nube; en local se usa el Flutter del usuario.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Misma versión que codemagic.yaml: con "stable" más nuevo `pub get` reescribe pubspec.lock.
FLUTTER_VERSION="3.41.1"
FLUTTER_DIR="$HOME/flutter"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ] || ! grep -qx "$FLUTTER_VERSION" "$FLUTTER_DIR/version" 2>/dev/null; then
  rm -rf "$FLUTTER_DIR"
  base="https://storage.googleapis.com/flutter_infra_release/releases"
  archive="stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  curl -fsSL "$base/$archive" | tar -xJ -C "$HOME"
fi

git config --global --add safe.directory "$FLUTTER_DIR" || true

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics >/dev/null 2>&1 || true
cd "$CLAUDE_PROJECT_DIR"
flutter pub get

# Archivos secretos gitignored: se usan los stubs .example (igual que ci.yml)
# para que el análisis no reporte errores falsos por imports faltantes.
[ -f lib/firebase_options.dart ] || cp lib/firebase_options.dart.example lib/firebase_options.dart
[ -f lib/config/api_config.dart ] || cp lib/config/api_config.dart.example lib/config/api_config.dart
[ -f assets/config.json ] || cp assets/config.json.example assets/config.json
