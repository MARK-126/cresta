#!/bin/bash
# Instala y configura graphify para Cresta (correr dentro de WSL, en la raíz del repo). Idempotente.
# 1) entorno virtual con graphify  2) hooks de git (reconstruye el grafo al hacer commit, cambiar
# de rama, merge o rebase) sin el merge driver  3) paso de etiquetado con Gemini tras cada commit
# 4) primer grafo (solo código, sin LLM).
set -e
REPO=$(git rev-parse --show-toplevel)
VENV=${GRAPHIFY_VENV:-$HOME/.venvs/graphify}
cd "$REPO"

[ -x "$VENV/bin/graphify" ] || python3 -m venv "$VENV"
# El backend de Gemini habla con la API compatible con OpenAI: necesita el paquete openai
"$VENV/bin/python" -c "import graphify, openai" 2>/dev/null ||
  "$VENV/bin/pip" install -q "graphifyy[openai]"
"$VENV/bin/graphify" hook install

# El merge driver sirve para versionar graph.json; aquí el grafo está en .gitignore
"$VENV/bin/python" -c "from pathlib import Path; from graphify.hooks import _unregister_merge_driver as u; print('merge driver:', u(Path('.')))"

# Etiquetado con Gemini al final del post-commit, en segundo plano (no traba el commit)
HOOK=$(git rev-parse --git-path hooks)/post-commit
if ! grep -q "# cresta-label-start" "$HOOK"; then
  cat >> "$HOOK" <<'BLOCK'
# cresta-label-start
# Nombra con Gemini los grupos nuevos del grafo (ver tool/dev/graphify-label.sh)
[ "${GRAPHIFY_SKIP_HOOK:-0}" = "1" ] || nohup "$(git rev-parse --show-toplevel)/tool/dev/graphify-label.sh" >/dev/null 2>&1 &
# cresta-label-end
BLOCK
fi

mkdir -p "$HOME/.config/cresta"
[ -f "$HOME/.config/cresta/graphify.env" ] || {
  printf '# Clave de Gemini para nombrar los grupos del grafo de Cresta. NO va en el repo.\nGEMINI_API_KEY=\n' > "$HOME/.config/cresta/graphify.env"
  chmod 600 "$HOME/.config/cresta/graphify.env"
}

# Primer grafo: solo código (análisis local, sin LLM)
"$VENV/bin/graphify" extract . --code-only
echo "Listo. Pega tu clave en ~/.config/cresta/graphify.env y corre: tool/dev/graphify.sh label ."
