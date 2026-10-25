# Cresta

App móvil de mapas 3D para **montañismo y senderismo** y para **protección civil**.
El primer paquete de mapas cubre el Iztaccíhuatl y el Popocatépetl y funciona sin conexión.

- **Modo Montaña:** terreno 3D, ruta La Arista del Sol (datos reales de OpenStreetMap), perfil de elevación
  que se recorre con el dedo, vuelo 3D sobre la ruta, curvas de nivel, senderos, cumbres y refugios, y el grupo
  en tiempo real (simulado por ahora).
- **Modo Protección civil:** semáforo volcánico, zonas de peligro, dispersión de ceniza, rutas de evacuación,
  albergues con ocupación y reportes ciudadanos. **Todos estos datos son de demostración**, no oficiales.
- **General:** satélite o relieve, 2D/3D, exageración del relieve, capas que se encienden y apagan,
  y tu ubicación por GPS.

## Arquitectura

```
Flutter (UI nativa, GPS, estado)
   │  MapBridge: llamadas JS ⇄ eventos por el canal "CrestaBridge"
   ▼
WebView ── MapLibre GL JS 4.7.1 (assets/web)  ← terreno 3D
   │  http://127.0.0.1:<puerto>
   ▼
TileServer (Dart, solo loopback)
   1. paquete sin conexión (assets/packs/*.zip, se extrae al primer arranque)
   2. caché en disco (lo que ya se descargó)
   3. red: Terrain Tiles de AWS y Esri World Imagery (y lo guarda en caché)
```

**¿Por qué un WebView y no el plugin nativo `maplibre_gl`?** MapLibre Native (iOS/Android) todavía no tiene
terreno 3D; en 2026 sigue en una rama experimental. MapLibre GL JS sí lo tiene. Toda la comunicación con el mapa
pasa por `lib/src/map/map_bridge.dart`, así que cuando el SDK nativo soporte terreno se puede cambiar el motor
sin tocar las pantallas.

| Carpeta | Contenido |
|---|---|
| `lib/src/data/` | Modelos: ruta y su perfil, datos de protección civil, cumbres |
| `lib/src/map/` | `MapBridge` (puente con el WebView) y definición de capas por modo |
| `lib/src/tiles/` | Servidor local de mosaicos y paquete sin conexión |
| `lib/src/group/` | Simulador del grupo (se reemplazará por ubicaciones reales) |
| `lib/src/location/` | Permisos y GPS (`geolocator`) |
| `lib/src/ui/` | Pantalla del mapa, paneles, perfil de elevación, tema |
| `assets/web/` | Página del mapa (`map.js`) y MapLibre GL JS incluido localmente |
| `assets/data/` | Ruta, senderos, curvas de nivel, cumbres y datos de demostración de protección civil |
| `assets/packs/` | Paquete de mosaicos Izta–Popo (relieve z10–12, satélite z10–14) |
| `tool/` | Scripts de Python con los que se generaron los datos |

## Correr la app

Requisitos: Flutter 3.47 o superior, Xcode (iOS) y/o Android Studio (Android).

```bash
flutter pub get
```

```bash
flutter run
```

Pruebas y análisis:

```bash
flutter test
```

```bash
flutter analyze
```

## Regenerar los datos

`tool/download_tiles.py` descarga los mosaicos del área y `tool/build_route_data.py` arma la ruta, el perfil de
elevación y las curvas de nivel a partir de un `osm.json` exportado de Overpass. Ambos se ejecutan desde una
carpeta de trabajo que contenga `tiles/` y `osm.json`. Después, comprime `tiles/dem` y `tiles/sat` en
`assets/packs/izta_popo.zip` y sube `OfflinePack.version`.

## Antes de publicar en las tiendas

- **Esri World Imagery** pide una cuenta de ArcGIS para usarse en apps. Cambia la fuente en
  `tileUpstreams` (`lib/src/tiles/tile_server.dart`) o consigue la licencia. Alternativas: MapTiler,
  Sentinel-2 cloudless o un servidor de mosaicos propio.
- Los datos de protección civil deben venir de fuentes oficiales (CENAPRED, protección civil estatal).
- Ubicación en segundo plano: hoy solo se usa con la app abierta. Compartir ubicación con el grupo en segundo
  plano requiere permisos adicionales y justificarlos ante Apple y Google.

## Siguientes pasos

1. Backend para grupos: ubicación compartida en tiempo real (p. ej. Supabase Realtime o Firebase) y reemplazar `GroupSimulator`.
2. Descargar zonas sin conexión desde la app (elegir un área y bajar sus mosaicos a la caché).
3. Grabar recorridos GPS y exportarlos a GPX.
4. Más rutas y un buscador; cargar GPX/KML del usuario.
5. Protección civil: reportes ciudadanos reales con foto y ubicación, y notificaciones push por zona.

## Créditos

Senderos y cumbres © colaboradores de OpenStreetMap (ODbL). Relieve: Mapzen Terrain Tiles (AWS Open Data).
Imagen satelital: Esri, Maxar, Earthstar Geographics. MapLibre GL JS (licencia BSD-3, `assets/web/vendor`).
