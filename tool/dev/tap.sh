#!/bin/bash
# Toca en el teléfono el elemento cuyo texto o descripción es $1 (o, si no hay, lo contiene) y espera $2
# segundos (1.5 por omisión). Uso: tool/dev/tap.sh "Mapa libre" 3
ADB=${ADB:-$HOME/Android/Sdk/platform-tools/adb}
command -v adb >/dev/null && ADB=adb
$ADB shell uiautomator dump /sdcard/u.xml >/dev/null
xy=$($ADB shell cat /sdcard/u.xml | python3 -c "
import sys,re
pat=sys.argv[1]
nodes=[]
for n in re.findall(r'<node [^>]*>',sys.stdin.read()):
  tx=re.search(r' text=\"([^\"]*)\"',n); cd=re.search(r'content-desc=\"([^\"]*)\"',n)
  bb=re.search(r'bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"',n)
  if not bb: continue
  t=(tx.group(1) if tx else '')+(cd.group(1) if cd else '')
  a,b,c,d=map(int,bb.groups())
  nodes.append((t,(a+c)//2,(b+d)//2,(c-a)*(d-b)))
# Primero el texto exacto (el más chico: un botón, no la ventana); si no, el que lo contiene
for ok in (lambda t: t==pat, lambda t: pat in t):
  hits=sorted([n for n in nodes if ok(n[0])], key=lambda n: n[3])
  if hits: print(hits[0][1],hits[0][2]); break" "$1")
[ -z "$xy" ] && { echo "no encontrado: $1"; exit 1; }
$ADB shell input tap $xy
sleep "${2:-1.5}"
