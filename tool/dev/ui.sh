#!/bin/bash
# Textos visibles en la pantalla del teléfono (uiautomator), uno por línea. Mucho más barato
# que una captura para revisar qué dice una pantalla. Uso: tool/dev/ui.sh ["tap X Y"] ["sleep 1"] ...
ADB=${ADB:-$HOME/Android/Sdk/platform-tools/adb}
DEV=$($ADB devices </dev/null | awk '/\tdevice$/{print $1; exit}')
[ -z "$DEV" ] && { echo "No hay teléfono conectado (adb connect IP:PUERTO)"; exit 1; }
for act in "$@"; do
  if [[ $act == sleep* ]]; then eval "$act"; else $ADB -s "$DEV" shell input $act </dev/null; sleep 0.8; fi
done
$ADB -s "$DEV" shell uiautomator dump /sdcard/ui.xml </dev/null >/dev/null
$ADB -s "$DEV" shell cat /sdcard/ui.xml </dev/null |
  grep -o '\(text\|content-desc\)="[^"]\+"' | sed -E 's/^[a-z-]+="(.*)"$/\1/; s/&#10;/ · /g'
