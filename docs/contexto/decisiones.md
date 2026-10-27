# Decisiones y errores resueltos

## Arquitectura

- **Mapa:** MapLibre GL JS 4.7.1 en un WebView (`webview_flutter`). El plugin nativo `maplibre_gl` no tiene
  terreno 3D en iOS/Android (en 2026 sigue experimental en MapLibre Native). `MapBridge` aísla el motor.
- **Servidor local** (`tile_server.dart`) en `127.0.0.1`: página del mapa, datos, tipografías y mosaicos;
  primero zonas descargadas, luego caché, luego red.
- **Fuentes que permiten uso sin conexión:** OpenFreeMap (topográfico, la URL cambia cada semana: se lee del
  TileJSON), Sentinel-2 cloudless 2024 de EOX (CC BY-NC-SA, **no comercial**, hasta z14), Mapzen Terrain
  Tiles en AWS (terrarium, hasta z12 ≈ 30 m), Nominatim (1 búsqueda/s). **Esri se retiró**: prohíbe guardar
  mosaicos. El **User-Agent debe ser ASCII** (con acentos fallan las descargas).
- **Curvas de nivel** con `maplibre-contour` en el teléfono.
- **Mosaicos** en `<fuente>/<z>/<x>/<y>`, compartidos entre zonas; borrar una zona quita solo los que
  ninguna otra usa. Descargas: una a la vez, reanudables, máx. 40,000 mosaicos, solo con la app abierta.
- **Persistencia:** JSON en Application Support con `JsonStore` (escrituras en serie, archivo temporal y
  renombrar): `expeditions.json`, `regions.json`, `settings.json`, `tracks/`, `routes.json`,
  `profile.json`, `weather.json`, `gear.json`, `references.json` + `references/<expedición>/`.
- **Altitud:** del relieve descargado (`TerrainElevation`); si no hay, la del GPS. Desnivel suavizado
  con umbral de 5 m.
- **Grabación en segundo plano:** Android, servicio en primer plano de `geolocator`; iOS,
  `UIBackgroundModes: location`. Puntos cada 10 s. Reloj = tiempo activo guardado en `activeS`.
- **Rutas:** una por expedición. Ajuste a senderos en `map.js` con lo **visible** (decisión del usuario,
  más simple que leer los mosaicos desde Dart); Dijkstra por distancia.
- **Clima:** Open-Meteo, gratis y sin clave; se guarda la respuesta cruda y se interpreta al leer.
- **SOS:** SMS con `sms:` y cuerpo codificado a mano (con `queryParameters` los espacios salen como `+`).
- **Grupo en tiempo real descartado** (no hay señal en la montaña).

## Diseño (UI)

- Sistema **"Andes Industrial"** (Google Stitch del usuario, proyecto "Live Geolocation Tracking"; la
  exportación está en el escritorio del usuario: `stitch_live_geolocation_tracking.zip`).
- **Solo oscuro.** Pizarra `#0E1416`; Cian Cumbre `#46EAE5` = acción, rastreo, listo; Oro Inca `#F0BF63` =
  importante, pendiente; Terracota `#FFA089` = alertas, grabación, SOS. Tokens en `Andes` (`theme.dart`).
- Sin bordes de 1 px ni sombras: bloques por tono (`TonalCard` con barra de acento). Cifras con `Figure` /
  `dataStyle` (Inter, números tabulares). Botón principal `GlowButton`. Sobre el mapa, `Glass`; el panel
  inferior del mapa es **opaco**.
- Inter incluida en la app (OFL). Mapa base claro (topográfico) a propósito, por legibilidad del relieve.
- Solo se adaptan pantallas de Stitch con equivalente real en Cresta: nada de logística, metas ni rankings.
- Splash: Android 12+ muestra **siempre** su pantalla con el ícono (no se puede quitar; el usuario eligió
  dejarla). Su montaña coincide en tamaño y lugar con la del splash de Flutter. Mínimo 2 s, "BY FRUTAL".
- Ícono generado con `tool/make_icon.py`; adaptativo y monocromático en Android 8+/13.

## Errores resueltos (síntoma → causa → solución)

- **Pantalla roja `_dependents.isEmpty` al guardar** → `TextEditingController` liberado al volver de
  `showDialog`, mientras el diálogo seguía animando → usar `askText` (el controlador vive en el estado).
- **El splash ocupaba parte del ancho** → `AnimatedSwitcher` apila con restricciones sueltas →
  `layoutBuilder` con `StackFit.expand`.
- **Se ve el mapa a través del panel** → cualquier transparencia sobre el WebView deja ver etiquetas → opaco.
- **El ajuste a senderos da rodeos** → los mosaicos simplifican líneas y los cruces no comparten vértice →
  unir extremos sueltos a < 20 m.
- **El modelo dice lluvia en la cumbre** → la nieve/código de Open-Meteo es de su celda → decidir con la
  altitud del punto y el nivel de congelación.
- **Reloj de grabación en 0 bajo techo** → contaba tiempo en movimiento y las lecturas > ±50 m se descartan.
- **Logo de Flutter al abrir** → faltaba configurar el splash de Android 12+ (y `values-night-v31`: con el
  teléfono en modo oscuro, `night` pesa más que `v31`).
