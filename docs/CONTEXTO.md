# Contexto del proyecto Cresta

Resumen de lo decidido y construido, para continuar en otra computadora o sesión.
Actualizado: 27 oct 2026.

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
| UI | Rediseño "Andes Industrial" (Stitch), pestañas, bitácora, resumen, splash, ícono | Hecha | `feat/rediseno-ui`, `feat/icono-y-contexto` |
| 3 | Planificador de rutas: dibujar, ajustar a senderos OSM offline, importar GPX/KML | Hecha | `feat/planificador-rutas` |
| SOS | Perfil de emergencia y pantalla SOS (coordenadas, UTM, llamar, SMS) | Hecha | `feat/perfil-sos` |
| 4 | Clima por altitud (Open-Meteo), lista de equipo, referencias (fotos, PDF, enlaces, teléfonos) | Hecha | `feat/preparacion` |

Los merges a `main` se hacen por avance directo (fast-forward), sin pull request, cuando el usuario lo aprueba.

## Fases 3, SOS y 4 (resumen técnico)

- **Rutas:** una por expedición (`routes.json`, `RouteStore`). El ajuste a senderos corre en `map.js`
  (`snapLeg`): arma un grafo con `querySourceFeatures` de la capa `transportation` **visible** (zoom ≥ 12.5),
  une extremos sueltos a < 20 m y usa Dijkstra por distancia (no por desnivel). Sin sendero → tramo recto.
  Perfil con `buildProfile` (puntos cada 30 m, altitud del relieve). Importa GPX (trk/rte/wpt) y KML
  (LineString, gx:Track, Placemark); exporta GPX. Detalle: `RouteScreen` con bitácora de paradas.
- **SOS:** `profile.json` (sin cuenta). Coordenadas decimal, grados-minutos-segundos y UTM (`toUtm`, Krüger);
  llamada con `tel:`, SMS con `sms:` (cuerpo codificado a mano), compartir/copiar. Mantiene la pantalla encendida.
- **Clima:** Open-Meteo, 16 días por hora, con `elevation` de la salida y del punto más alto (o centro de la
  zona). Se guarda en `weather.json`. "Nieve probable" y el código de nieve se calculan con la altitud del
  punto y el nivel de congelación (la nieve del modelo es la de su celda). Vigente 48 h en el checklist.
- **Equipo:** `gear.json`, plantillas (senderismo, alta montaña, con campamento), peso y empacado.
- **Referencias:** `references.json`; los archivos se copian a `references/<expedición>/` (sirven sin señal).
  PDF y otros se abren con `open_filex`; fotos en un visor propio con zoom.
- Borrar una expedición borra su ruta, clima, equipo, referencias, recorridos y mapas propios.
- Probado en el Samsung: planificador (en el Izta; en Vallecitos OSM no tiene senderos), detalle de ruta,
  SOS (con la ubicación apagada), clima real, equipo y referencias (enlace). Pendiente probar: SMS y
  coordenadas del SOS con la ubicación encendida, importar un GPX real y abrir un PDF.

## Diseño (UI)

- Sistema **"Andes Industrial"** del proyecto de Google Stitch del usuario ("Live Geolocation Tracking"):
  solo tema oscuro, pizarra `#0E1416`, Cian Cumbre `#46EAE5` (acción, rastreo, lo que está listo),
  Oro Inca `#F0BF63` (lo importante, pendientes) y Terracota (alertas y grabación). Tokens en `Andes`
  (`lib/src/ui/theme.dart`).
- Reglas: sin bordes de 1 px ni sombras; los bloques se separan por tono (`TonalCard`, con barra lateral de
  acento opcional). Cifras con `Figure`/`dataStyle` (Inter con números tabulares). Botón principal `GlowButton`.
  Lo que flota sobre el mapa usa `Glass`, y el panel inferior del mapa es **opaco** (sobre el WebView cualquier
  transparencia deja ver las etiquetas).
- Tipografía **Inter** incluida en la app (`assets/fonts/inter`, licencia OFL), para que funcione sin conexión.
- Pestañas (`HomeShell`): Expediciones · Bitácora · Resumen · Mapas. El resumen (`ActivitySummary`) solo usa
  recorridos terminados y datos reales: sin metas ni rankings.
- Splash: Android 12+ muestra **obligatoriamente** su pantalla con el ícono (no se puede quitar). La montaña de
  ese splash (`drawable/splash_icon.xml`) tiene el mismo tamaño y posición que la del splash de Flutter
  (`SplashScreen`), para que se vea como una sola animación. Dura al menos 2 s y lleva la firma "BY FRUTAL".
- Ícono: `tool/make_icon.py` genera los PNG de Android e iOS; el adaptativo de Android 8+ está en XML
  (`mipmap-anydpi-v26`, `drawable/ic_launcher_*`).
- Las pantallas de Stitch de logística (flotas, tablero ejecutivo) no se adaptan: solo lo que existe en Cresta.
  Candidatas futuras: "Route Details" (con la Fase 3), "Fleet Asset Management" como lista de equipo (Fase 4)
  y "Athlete Registration" como perfil con datos de emergencia.

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
- **Reloj de grabación:** muestra el tiempo activo desde que se toca "Grabar" (sin pausas), guardado en el
  recorrido (`activeS`). Las lecturas con error mayor a ±50 m no se guardan: bajo techo el panel avisa
  "Esperando una señal GPS precisa".
- **Permiso de notificaciones (Android 13+):** se pide al empezar a grabar con un canal propio
  (`cresta/permissions` en `MainActivity.kt`); si se niega, se graba igual y se avisa.

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
lib/src/ui/                    pantallas; theme.dart tiene la paleta y los componentes del diseño
assets/web/                    map.js, MapLibre, maplibre-contour, tipografías Noto Sans (pbf)
assets/data/                   ruta de ejemplo (La Arista del Sol, OSM) y datos de demostración
assets/packs/izta_popo.zip     mapas del ejemplo (~10 MB)
assets/fonts/inter/            tipografía de la app
assets/images/                 textura del splash
tool/                          scripts de Python: ruta, paquete de mapas e ícono
test/                          87 pruebas
```

## Entorno de desarrollo (computadora con Windows)

- El proyecto vive en WSL (`~/PRACTICE/PROJECTS/cresta`). Flutter en `~/flutter` y Android SDK en
  `~/Android/Sdk` (sin Android Studio); `sdkmanager` está obsoleto, se usa `android sdk install ...`.
- Git se usa **dentro de WSL**: desde Windows falla por "dubious ownership".
- Teléfono de pruebas: Galaxy S23 Ultra (Android 16) por **depuración inalámbrica**. Vincular una vez con
  `adb pair IP:PUERTO_VINCULAR CÓDIGO` y conectar cada vez con `adb connect IP:PUERTO` (el puerto cambia al
  reactivar la depuración). Por USB, Windows no detectó el teléfono (probablemente cable solo de carga).
- Recargar en caliente no cambia la app instalada: si se cierra y se vuelve a abrir, corre el último APK
  instalado. Reinstalar (`flutter run` o `flutter build apk --debug` + `adb install -r`) antes de que el
  usuario pruebe por su cuenta.

## Cómo se probó

- iOS en el simulador de iPhone 16 Pro, con caminatas simuladas por la ruta usando
  `xcrun simctl location booted start --speed=15 --distance=10 <lat,lon> ...`.
- Descargas reales probadas: Nevado de Toluca (71 mosaicos) y Aconcagua.
- Android en el Samsung del usuario (oct 2026): mapa, descargas, permisos de ubicación y la UI completa.
- **Pendiente de probar:** la grabación al aire libre con la pantalla bloqueada y sin señal real.

## Pendientes conocidos

- Prueba real de grabación al aire libre (pantalla bloqueada, notificación fija, bitácora y resumen con datos).
- Descargas que sigan con la app cerrada (p. ej. `background_downloader`).
- Altímetro barométrico como complemento (ahora: relieve o GPS).
- Notificación local al pasar la hora límite (ahora el aviso es dentro de la app).
- En la lista de recorridos, nombres antiguos pueden incluir la fecha repetida (los nuevos son "Recorrido N").
- Si la app se vuelve comercial: cambiar el satélite (licencia no comercial) y revisar términos de OpenFreeMap.

## Próximo paso sugerido

Hechas las fases 3, SOS y 4. Sigue pendiente la **prueba de grabación al aire libre**. Ideas siguientes:
brújula y rumbo de regreso, salida y puesta del sol sin conexión, fotos geolocalizadas en el recorrido,
ajuste a senderos que considere el desnivel, notificación al pasar la hora límite.

Fase 3, planificador de rutas: tocar puntos en el mapa; trazar a mano o ajustado a los senderos de la capa
`transportation` de OpenMapTiles (ya descargada con la zona); perfil y tiempo estimado en vivo (reusar
`TrailRoute` y `ElevationProfile`); puntos de interés (agua, campamento, punto de no retorno); importar GPX/KML.
La ruta de la expedición hoy solo existe en el ejemplo (`Expedition.routeAsset`); habrá que guardarla en el
teléfono.
