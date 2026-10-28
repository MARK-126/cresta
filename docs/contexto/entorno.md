# Entorno de desarrollo

## Computadora (Windows + WSL)

- El proyecto vive en WSL Ubuntu: `~/PRACTICE/PROJECTS/cresta` (desde Windows:
  `\\wsl.localhost\Ubuntu\home\neo\PRACTICE\PROJECTS\cresta`).
- Flutter 3.47.8 en `~/flutter`; Android SDK en `~/Android/Sdk` (sin Android Studio). `sdkmanager` está
  obsoleto: se usa `~/Android/Sdk/cmdline-tools/latest/bin/android --no-metrics sdk install ...`.
- El PATH está en `~/.bashrc`; en scripts no interactivos hay que exportarlo
  (`export PATH=~/flutter/bin:$PATH`).
- **Git se usa dentro de WSL**: desde Windows falla por "dubious ownership".
- Remoto: `https://github.com/MARK-126/cresta.git`.

## Teléfono (Samsung Galaxy S23 Ultra, Android 16)

Por **depuración inalámbrica** (por USB, Windows no lo detectó: probablemente cable solo de carga).

1. Vincular **una vez**: en el teléfono, *Depuración inalámbrica → Vincular con código*;
   `adb pair 192.168.100.39:PUERTO_VINCULAR CÓDIGO`.
2. Conectar **cada vez**: `adb connect 192.168.100.39:PUERTO` (el de "Dirección IP y puerto", cambia
   al reactivar la depuración o al bloquearse la pantalla).
3. `flutter run -d 192.168.100.39:PUERTO`.

Cuidado:
- Si viene un código, ese puerto es el de **vincular**: solo `adb pair`. Un `adb connect` a ese puerto gasta
  el código ("protocol fault" después). Nunca `adb pair` al puerto de conexión.
- La IP del teléfono ha sido siempre `.39` (una vez el usuario escribió `.38` por error).
- Conviene "Pantalla activa" en Opciones de desarrollador y el teléfono cargando.

## Compilar e instalar

- Antes de cada commit: `dart format lib test`, `flutter analyze`, `flutter test`.
- Lanzar en una pestaña de terminal (para ver el log):
  `wsl -d Ubuntu --cd /home/neo/PRACTICE/PROJECTS/cresta -- bash -ic "flutter run -d IP:PUERTO"`
  (`--cd ~` no funciona).
- **Recarga en caliente sin escribir en la terminal:** `pkill -USR1 -f "flutter_tools.snapshot run"`
  (recargar) y `-USR2` (reiniciar).
- A veces la recarga se **rechaza** ("Hot reload was rejected: Error while starting Kernel isolate task"):
  los cambios no llegan aunque no haya error visible. Revisar el log y, si pasa, cerrar y volver a lanzar
  `flutter run`.
- **La recarga no cambia la app instalada:** si se cierra y se abre, corre el último APK. Reinstalar antes
  de que el usuario pruebe solo (`flutter run`, o `flutter build apk --debug` + `adb install -r`).
- Cambios nativos (Kotlin, `AndroidManifest`, plugins nuevos) requieren compilación completa.
- `adb shell am force-stop com.cresta.cresta` termina la sesión de `flutter run`.

## graphify (grafo de conocimiento del código)

- Instalado en un entorno virtual de WSL: `~/.venvs/graphify` (paquete `graphifyy` 0.9.97, Apache-2.0).
  Instalación completa e idempotente: `tool/dev/graphify-setup.sh` (dentro de WSL, en la raíz del repo).
- Se usa con `tool/dev/graphify.sh <comando>` desde Windows o WSL. Skill del proyecto:
  `.claude/skills/graphify/SKILL.md` (se carga cuando la sesión de Claude abre la carpeta del repo).
- Hooks de git (`.git/hooks`, no versionados): post-commit, post-checkout, post-merge y post-rewrite
  reconstruyen el grafo del código cambiado, en segundo plano y sin LLM. Al final del post-commit,
  `tool/dev/graphify-label.sh` nombra con **Gemini** los grupos nuevos (`label --missing-only`).
- La clave va en `~/.config/cresta/graphify.env` (`GEMINI_API_KEY=...`, permisos 600, fuera del repo).
  La escribe el usuario; nunca se versiona ni se muestra.
- Salida en `graphify-out/` (en `.gitignore`). Registros: `~/.cache/graphify-rebuild.log` y
  `~/.cache/graphify-label.log`.

## Herramientas de prueba (`tool/dev/`)

- `shot.sh NOMBRE [acciones...]`: ejecuta toques (`"tap X Y"`, `"swipe ..."`, `"keyevent 4"`, `"sleep N"`)
  y guarda una captura del teléfono a la mitad (360 × 772; `SHOT_SCALE=1` para 720 × 1544). Los toques
  van siempre en coordenadas del teléfono (720 × 1544).
- `ui.sh [acciones...]`: textos visibles en pantalla (uiautomator), uno por línea. Preferirlo a las
  capturas para revisar qué dice una pantalla: gasta mucho menos.
- `cdp.py 'expresión JS'`: evalúa JavaScript en el WebView del mapa (p. ej.
  `window.cresta.jumpTo(-98.64, 19.15, 14)` o `window.cresta.snapLeg([...], [...])`). Requiere
  `adb forward tcp:9333 localabstract:webview_devtools_remote_$(adb shell pidof com.cresta.cresta)`.
- En scripts `bash -s <<'EOF'`, cada `adb shell` necesita `</dev/null` o se come el resto del script.
- No hay `node` en WSL; Python 3 sí (con Pillow).
