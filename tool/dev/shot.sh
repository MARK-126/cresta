#!/bin/bash
# Captura de pantalla del teléfono, con acciones antes (toques, deslizar, teclas, esperas).
# Uso: tool/dev/shot.sh NOMBRE ["tap X Y"] ["swipe X1 Y1 X2 Y2 MS"] ["keyevent 4"] ["sleep 1.5"] ...
# Guarda en $CAPTURAS (por defecto /tmp/cresta-capturas)/NOMBRE.png. Pantalla del S23 Ultra: 720 × 1544.
ADB=${ADB:-$HOME/Android/Sdk/platform-tools/adb}
DEV=$($ADB devices </dev/null | awk '/\tdevice$/{print $1; exit}')
[ -z "$DEV" ] && { echo "No hay teléfono conectado (adb connect IP:PUERTO)"; exit 1; }
OUT=${CAPTURAS:-/tmp/cresta-capturas}; mkdir -p "$OUT"
name=$1; shift
for act in "$@"; do
  if [[ $act == sleep* ]]; then eval "$act"; else $ADB -s "$DEV" shell input $act </dev/null; sleep 0.8; fi
done
sleep 1
$ADB -s "$DEV" exec-out screencap -p </dev/null > "$OUT/$name.png" && echo "$OUT/$name.png"
