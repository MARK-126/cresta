"""Descarga el paquete de ejemplo (Izta–Popo) que viene incluido en la app.

Uso: python3 tool/download_tiles.py <carpeta_salida>
Luego: cd <carpeta_salida> && zip -qr -0 assets/packs/izta_popo.zip sat dem topo

Las zonas y zooms deben coincidir con `samplePackRegion` en lib/src/offline/sample_data.dart.
"""
import json
import math
import os
import subprocess
import sys

WIDE = (18.92, -98.82, 19.24, -98.46)   # sur, oeste, norte, este
CORE = (18.99, -98.70, 19.21, -98.58)
UA = 'Cresta/0.1 (app personal de montaña)'


def tile(lat, lon, z):
    n = 2 ** z
    x = int((lon + 180) / 360 * n)
    r = math.radians(lat)
    y = int((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n)
    return x, y


def tiles(bbox, z):
    s, w, n, e = bbox
    x0, y0 = tile(n, w, z)
    x1, y1 = tile(s, e, z)
    return [(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)]


def main(out):
    tilejson = subprocess.run(['curl', '-sf', '-A', UA, 'https://tiles.openfreemap.org/planet'], capture_output=True, check=True)
    topo = json.loads(tilejson.stdout)['tiles'][0]
    urls = {
        'dem': 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
        'sat': 'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2024_3857/default/g/{z}/{y}/{x}.jpg',
        'topo': topo,
    }
    jobs = []
    jobs += [('dem', z, x, y) for z in (10, 11, 12) for x, y in tiles(WIDE, z)]
    jobs += [('sat', z, x, y) for z in (10, 11, 12, 13) for x, y in tiles(WIDE, z)]
    jobs += [('sat', 14, x, y) for x, y in tiles(CORE, 14)]
    jobs += [('topo', z, x, y) for z in range(8, 14) for x, y in tiles(WIDE, z)]
    jobs += [('topo', 14, x, y) for x, y in tiles(CORE, 14)]
    print(len(jobs), 'mosaicos')
    for kind, z, x, y in jobs:
        path = os.path.join(out, kind, str(z), str(x), str(y))
        if os.path.exists(path):
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        url = urls[kind].replace('{z}', str(z)).replace('{x}', str(x)).replace('{y}', str(y))
        # --compressed: los .pbf de OpenFreeMap vienen con gzip; se guardan descomprimidos
        subprocess.run(['curl', '-sf', '--compressed', '-A', UA, '-m', '30', '-o', path, url], check=False)


if __name__ == '__main__':
    main(sys.argv[1])
