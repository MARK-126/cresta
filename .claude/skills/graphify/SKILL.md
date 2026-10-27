---
name: graphify
description: Grafo de conocimiento del código de Cresta (graphify). Úsala antes de explorar o cambiar código que no conoces, para preguntar cómo se relacionan clases y archivos, qué se rompe si cambias algo, o cuál es el camino entre dos piezas; y para regenerar el grafo o nombrar sus grupos con Gemini.
---

# graphify en Cresta

El grafo vive en `graphify-out/` (en `.gitignore`: cada rama tiene el suyo). Lo reconstruyen solos los
hooks de git en cada commit, cambio de rama, merge y rebase (solo código, análisis local sin LLM). Después
de cada commit, `tool/dev/graphify-label.sh` nombra con Gemini los grupos nuevos.

graphify está instalado en WSL. **Siempre** llamarlo con el envoltorio, que funciona desde Windows y WSL:

```bash
tool/dev/graphify.sh <comando> ...
```

(Desde Windows, con la ruta completa: `bash //wsl.localhost/Ubuntu/home/neo/PRACTICE/PROJECTS/cresta/tool/dev/graphify.sh ...`)

## Antes de leer muchos archivos, preguntar al grafo

| Para | Comando |
|---|---|
| Panorama: grupos, nodos centrales, conexiones sorprendentes | leer `graphify-out/GRAPH_REPORT.md` |
| Pregunta en lenguaje natural | `query "¿cómo se guarda una ruta?"` (`--budget 2000` tokens) |
| Qué es algo y con qué se conecta | `explain "TrackRecorder"` |
| Cómo se llega de A a B | `path "MapScreen" "RouteStore"` |
| Qué se afecta si cambio X (antes de refactorizar) | `affected "TrailRoute" --depth 2` |
| Nodos más conectados | `god-nodes --top 15` |

Las respuestas citan archivos: úsalas para decidir qué leer, y lee el código antes de cambiarlo
(el extractor de Dart es por expresiones regulares y puede omitir relaciones).

## Mantenimiento

- **Reconstruir a mano** (si el hook no corrió o tras cambios grandes): `update .`
  (`--force` si se borró mucho código).
- **Nombrar grupos con Gemini:** `label . --missing-only` (solo los que no tienen nombre) o `label .`
  (todos). Requiere `GEMINI_API_KEY` en `~/.config/cresta/graphify.env` (fuera del repo; **nunca**
  escribir, leer en voz alta ni pedir la clave: la pone el usuario). Para usarla en una llamada manual:
  `wsl -d Ubuntu -- bash -c 'set -a; . ~/.config/cresta/graphify.env; set +a; cd ~/PRACTICE/PROJECTS/cresta && ~/.venvs/graphify/bin/graphify label . --missing-only --backend gemini'`
- **Reporte y HTML sin LLM:** `cluster-only . --no-label`.
- **Ver el grafo:** abrir `graphify-out/graph.html`.
- Registros: `~/.cache/graphify-rebuild.log` (hook) y `~/.cache/graphify-label.log` (etiquetado).
- Estado de los hooks: `hook status`. Instalación completa en otra computadora:
  `tool/dev/graphify-setup.sh` (dentro de WSL, en la raíz del repo).

## Qué se indexa

Código (Dart, JS del mapa, Kotlin, Swift, Python de `tool/`), sin documentos ni imágenes (`--code-only`:
no se envían a ningún LLM). Exclusiones en `.graphifyignore` (MapLibre, tipografías, paquetes de mapas,
datos y código generado).
