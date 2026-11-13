#!/bin/bash
# Toca en el teléfono el primer elemento cuyo texto o descripción contiene $1 y espera $2
# segundos (1.5 por omisión). Uso: tool/dev/tap.sh "Mapa libre" 3
ADB=${ADB:-$HOME/Android/Sdk/platform-tools/adb}
command -v adb >/dev/null && ADB=adb
$ADB shell uiautomator dump /sdcard/u.xml >/dev/null
xy=$($ADB shell cat /sdcard/u.xml | python3 -c "
import sys,re
pat=sys.argv[1]
for n in re.findall(r'<node [^>]*>',sys.stdin.read()):
  t=re.search(r' text=\"([^\"]*)\"',n).group(1)+re.search(r'content-desc=\"([^\"]*)\"',n).group(1)
  if pat in t:
    a,b,c,d=map(int,re.search(r'bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"',n).groups()); print((a+c)//2,(b+d)//2); break" "$1")
[ -z "$xy" ] && { echo "no encontrado: $1"; exit 1; }
$ADB shell input tap $xy
sleep "${2:-1.5}"
