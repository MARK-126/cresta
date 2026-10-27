#!/bin/bash
# Pone nombre con Gemini a los grupos (comunidades) del grafo que aún no lo tienen.
# Lo lanza el hook post-commit después de la reconstrucción del grafo.
# La clave NO va en el repositorio: se lee de ~/.config/cresta/graphify.env (fuera del repo),
# que debe definir GEMINI_API_KEY=... (y opcionalmente GRAPHIFY_GEMINI_MODEL=...).
REPO=${CRESTA_REPO:-/home/neo/PRACTICE/PROJECTS/cresta}
GRAPHIFY_BIN=${GRAPHIFY_BIN:-/home/neo/.venvs/graphify/bin/graphify}
ENV_FILE=${CRESTA_GRAPHIFY_ENV:-$HOME/.config/cresta/graphify.env}
LOG=$HOME/.cache/graphify-label.log
mkdir -p "$(dirname "$LOG")"
{
  echo "== $(date -Iseconds) etiquetado"
  if [ ! -f "$ENV_FILE" ]; then echo "sin $ENV_FILE: no se etiqueta"; exit 0; fi
  set -a; . "$ENV_FILE"; set +a
  if [ -z "${GEMINI_API_KEY:-}" ]; then echo "GEMINI_API_KEY vacía: no se etiqueta"; exit 0; fi
  cd "$REPO" || exit 0
  [ -f graphify-out/graph.json ] || { echo "aún no hay grafo"; exit 0; }
  # Esperar a que termine la reconstrucción en segundo plano (usa este mismo candado)
  touch graphify-out/.rebuild.lock
  flock graphify-out/.rebuild.lock true
  "$GRAPHIFY_BIN" label . --missing-only --backend gemini
} >>"$LOG" 2>&1
