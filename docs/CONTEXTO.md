# Contexto del proyecto Cresta

Resumen de lo decidido y construido, para continuar en otra computadora o sesión.
Actualizado: 25 oct 2026.

## Qué quiere el usuario

Una app personal de montaña (senderismo, montañismo) que:
1. Muestre mapas en **2D y 3D**.
2. **Grabe el recorrido** con GPS, sin señal.
3. Permita **armar rutas**.
4. Antes de salir, **consultar el clima** y **guardar referencias**.
5. **Funcione offline**: con Wi-Fi en casa se descargan los mapas de la zona elegida por el usuario
   (cualquier lugar del mundo: México, Andes…).

Uso **personal y gratuito**. Teléfonos: **iPhone y Android** (tiene un Samsung).

Se descartó por ahora el backend para compartir ubicación del grupo: en la montaña no hay señal. Si se retoma,
el plan era offline-first (cola local + sincronizar al haber señal) y, para grupos sin señal, radios LoRa con
Meshtastic.

## Fases

| Fase | Contenido | Estado | Rama |
|---|---|---|---|
| 0 | Prototipo web + app base (mapa 3D en WebView, ejemplo Izta–Popo, modo protección civil de demostración) | Hecha | `main` |
| 1 | Expediciones, descarga de mapas por zona, gestor de mapas, mapa topográfico propio | Hecha | `feat/expediciones-mapas-offline` |
| 2 | Grabar recorrido (segundo plano, estadísticas, hora límite, salida de ruta, GPX) | Hecha | `feat/grabar-recorrido` (incluye la 1) |
| 3 | Planificador de rutas: dibujar, ajustar a senderos OSM offline, importar GPX/KML | Pendiente | |
| 4 | Clima por altitud guardado con la expedición (Open-Meteo), referencias (fotos, PDF, contactos), lista de equipo | Pendiente | |

`feat/grabar-recorrido` contiene todo lo hecho. Aún no se ha hecho merge a `main` (falta abrir el pull request).

## Decisiones técnicas clave

- **Mapa:** MapLibre GL JS 4.7.1 en un WebView (`webview_flutter`). El plugin nativo `maplibre_gl` no tiene
  terreno 3D en iOS/Android (en 2026 sigue en una rama experimental de MapLibre Native).
  `MapBridge` aísla el motor para poder cambiarlo después.
- **Servidor local** (`lib/src/tiles/tile_server.dart`) en `127.0.0.1` que sirve la página del mapa, datos,
  tipografías y mosaicos: primero zonas descargadas, luego caché de navegación, luego red.
- **Fuentes libres que permiten uso offline:**
  - Topográfico vectorial: OpenFreeMap (esquema OpenMapTiles). La URL cambia cada semana; se obtiene del TileJSON.
  - Satélite: Sentinel-2 cloudless 2024 de EOX (CC BY-NC-SA, **no comercial**; 10 m/píxel, hasta zoom 14).
  - Relieve: Mapzen Terrain Tiles en AWS (terrarium, hasta zoom 12 ≈ 30 m/píxel).
  - Búsqueda: Nominatim (máx. 1 búsqueda/s, sin autocompletar, sin priorizar la zona visible).
  - Esri se retiró porque prohíbe guardar mosaicos.
- **Curvas de nivel** generadas en el teléfono con `maplibre-contour` a partir del relieve.
- **Almacén de mosaicos** en archivos `<fuente>/<z>/<x>/<y>`, compartidos entre zonas; al borrar una zona se
  eliminan solo los que ninguna otra cubre (`OfflineMaps.prune`).
- **Descargas:** una zona a la vez, reanudables, opción "solo Wi-Fi", máx. 40,000 mosaicos por zona.
  Avanzan solo con la app abierta (pantalla encendida con `wakelock_plus`).
- **Persistencia:** JSON en Application Support (`expeditions.json`, `regions.json`, `settings.json`,
  `tracks/tracks.json`) y puntos del recorrido en `tracks/points/<id>.jsonl` (una línea por punto).
- **Altitud del recorrido:** se toma del relieve descargado (`TerrainElevation`); si no hay, la del GPS.
  Desnivel con suavizado y umbral de 5 m.
- **Grabación en segundo plano:** iOS con `UIBackgroundModes: location` (indicador azul); Android con servicio
  en primer plano de `geolocator` (notificación fija). Puntos guardados cada 10 s; si la app se cierra, el
  recorrido se recupera en pausa.

## Estructura

```
lib/main.dart                  arranque, idioma español, AppScope
lib/src/app_services.dart      crea servicios (mapas, expediciones, recorridos, servidor)
lib/src/expeditions/           modelo de expedición y su almacenamiento
lib/src/offline/               zonas, mosaicos, fuentes, motor de descargas, paquete de ejemplo
lib/src/tiles/tile_server.dart servidor local para el WebView
lib/src/tracking/              grabador, estadísticas, avance en ruta, altitud del terreno, GPX
lib/src/search/                búsqueda de lugares
lib/src/map/                   MapBridge y capas
lib/src/ui/                    pantallas
assets/web/                    map.js, MapLibre, maplibre-contour, tipografías Noto Sans (pbf)
assets/data/                   ruta de ejemplo (La Arista del Sol, OSM) y datos de demostración
assets/packs/izta_popo.zip     mapas del ejemplo (~10 MB)
tool/                          scripts de Python que generaron la ruta y el paquete
test/                          46 pruebas
```

## Cómo se probó

- iOS en el simulador de iPhone 16 Pro, con caminatas simuladas por la ruta usando
  `xcrun simctl location booted start --speed=15 --distance=10 <lat,lon> ...`.
- Descargas reales probadas: Nevado de Toluca (71 mosaicos) y Aconcagua.
- **Nunca probado:** Android, un teléfono físico, la grabación con pantalla bloqueada y sin señal real.

## Pendientes conocidos

- Probar en Android (Samsung del usuario). Opción sin ocupar disco: compilar el APK con GitHub Actions y
  descargarlo en el teléfono.
- Descargas que sigan con la app cerrada (p. ej. `background_downloader`).
- Altímetro barométrico como complemento (ahora: relieve o GPS).
- Notificación local al pasar la hora límite (ahora el aviso es dentro de la app).
- En la lista de recorridos, nombres antiguos pueden incluir la fecha repetida (los nuevos son "Recorrido N").
- Si la app se vuelve comercial: cambiar el satélite (licencia no comercial) y revisar términos de OpenFreeMap.

## Próximo paso sugerido

Fase 3, planificador de rutas: tocar puntos en el mapa; trazar a mano o ajustado a los senderos de la capa
`transportation` de OpenMapTiles (ya descargada con la zona); perfil y tiempo estimado en vivo (reusar
`TrailRoute` y `ElevationProfile`); puntos de interés (agua, campamento, punto de no retorno); importar GPX/KML.
La ruta de la expedición hoy solo existe en el ejemplo (`Expedition.routeAsset`); habrá que guardarla en el
teléfono.
