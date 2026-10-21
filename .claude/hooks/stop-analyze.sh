#!/bin/bash
# Hook de Stop: antes de que Claude dé el turno por terminado, corre
# `flutter analyze` si hay cambios en Dart. Si encuentra problemas, sale con
# código 2 y Claude recibe el reporte y tiene que corregirlos.
set -uo pipefail

input=$(cat)
# Si Claude ya está continuando por este mismo hook, no bloquear otra vez
# (evita ciclos infinitos).
if echo "$input" | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("stop_hook_active") else 1)' 2>/dev/null; then
  exit 0
fi

export PATH="$HOME/flutter/bin:$PATH"
command -v flutter >/dev/null 2>&1 || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Solo si hay Dart modificado sin commitear o en commits aún no subidos.
changed=$(git status --porcelain -- '*.dart' pubspec.yaml analysis_options.yaml 2>/dev/null)
if [ -z "$changed" ] && git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  changed=$(git diff --name-only '@{u}..HEAD' -- '*.dart' pubspec.yaml analysis_options.yaml 2>/dev/null)
fi
[ -n "$changed" ] || exit 0

if ! out=$(flutter analyze --no-pub 2>&1); then
  {
    echo "flutter analyze encontró problemas. Corrígelos antes de terminar:"
    echo "$out" | grep -E '^\s*(error|warning|info) •' | head -50
  } >&2
  exit 2
fi
exit 0
