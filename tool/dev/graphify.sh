#!/bin/bash
# Ejecuta graphify sobre este proyecto, se llame desde WSL o desde Windows (Git Bash).
# graphify vive en un entorno virtual de WSL (ver tool/dev/graphify-setup.sh).
# Uso: tool/dev/graphify.sh query "¿cómo se graba un recorrido?"
#      tool/dev/graphify.sh explain "TrackRecorder"
GRAPHIFY_BIN=${GRAPHIFY_BIN:-/home/neo/.venvs/graphify/bin/graphify}
REPO=${CRESTA_REPO:-/home/neo/PRACTICE/PROJECTS/cresta}
if grep -qi microsoft /proc/version 2>/dev/null || [ "$(uname -s)" = "Linux" ]; then
  cd "$REPO" && exec "$GRAPHIFY_BIN" "$@"
else
  # Desde Windows: pasar por WSL (MSYS_NO_PATHCONV evita que Git Bash reescriba rutas)
  MSYS_NO_PATHCONV=1 exec wsl.exe -d Ubuntu --cd "$REPO" -- "$GRAPHIFY_BIN" "$@"
fi
