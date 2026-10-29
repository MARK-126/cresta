# Estado: qué está hecho

Actualizado: 28 oct 2026 · `main` con SOS probado, aviso al salir del perfil, notificación de hora límite y mapa libre.

## Fases

| Fase | Contenido | Rama | Último commit |
|---|---|---|---|
| 0 | Prototipo: mapa 3D en WebView, ejemplo Izta–Popo, modo protección civil (demostración) | `main` | `69e3203` |
| 1 | Expediciones, descarga de mapas por zona, gestor de mapas, mapa topográfico propio | `feat/expediciones-mapas-offline` | `27668a0` |
| 2 | Grabar recorrido (segundo plano, estadísticas, hora límite, salida de ruta, GPX) | `feat/grabar-recorrido` | `0f9de30` |
| UI | Rediseño "Andes Industrial", pestañas, bitácora, resumen, splash, ícono | `feat/rediseno-ui`, `feat/icono-y-contexto` | `8ed84eb` |
| 3 | Planificador de rutas, detalle de ruta, importar/exportar GPX y KML | `feat/planificador-rutas` | `abe6e0f` |
| SOS | Perfil de emergencia y pantalla SOS | `feat/perfil-sos` | `f54c534` |
| 4 | Clima por altitud, lista de equipo, referencias | `feat/preparacion` | `f2496bf` |
| Fix | Mapas del ejemplo, relieve interpolado (pendientes), umbral de nieve, graphify con Gemini | `fix/ejemplo-pendiente-nieve` | `7b7c2dc` |
| Mejoras | Sangre con palabras en el SMS, aviso al salir del perfil, notificación de hora límite, mapa libre | `fix/sms-sangre`, `fix/perfil-sin-guardar`, `feat/notificacion-hora-limite`, `feat/mapa-libre` | `0bf2400` |
| Rutas A | Rutas como entidades propias (id, expedición opcional), formato 2 con migración y respaldo | `feat/rutas-propias` | (este commit) |

## Por área

### Mapa y mapas sin conexión
- MapLibre GL JS 4.7.1 en un WebView (`assets/web/map.js`), controlado desde `lib/src/map/map_bridge.dart`.
- Servidor local `lib/src/tiles/tile_server.dart`: zonas descargadas → caché → red.
- Descarga por zona (`lib/src/offline/`), topográfico OpenFreeMap, satélite Sentinel-2 (EOX), relieve
  Terrain Tiles (AWS), curvas de nivel calculadas en el teléfono, buscador (Nominatim).

### Expediciones (`lib/src/expeditions/`, `ui/expedition_screen.dart`)
- Nombre, fecha, notas, zonas de mapas, hora límite de retorno.
- Lista **"Antes de salir"**: mapas, ruta, clima (vigente 48 h), equipo empacado, hora límite.
- Borrar una expedición borra su ruta, clima, equipo, referencias, recorridos y mapas propios.

### Grabación (`lib/src/tracking/`, `ui/recording_panel.dart`)
- Segundo plano (Android: servicio en primer plano; iOS: indicador azul), puntos cada 10 s, recuperación
  en pausa si la app se cierra.
- Reloj de tiempo activo (sin pausas) que corre desde que se toca Grabar; aviso "Esperando una señal GPS
  precisa" si la precisión es peor que ±50 m.
- Permiso de notificaciones (Android 13+) por canal propio `cresta/permissions` (`MainActivity.kt`).
- Estadísticas, desnivel con relieve, hora límite, aviso de salida de ruta, exportar GPX.

### Rutas (`lib/src/routes/`, `ui/planner_panel.dart`, `ui/route_screen.dart`)
- Cada ruta tiene su `id` y puede estar ligada a una expedición o existir sola (`RouteStore`: `all`, `byId`,
  `of`, `save`, `delete`, `deleteOf`, `replaceOf`). Las pantallas siguen manejando una por expedición
  (`forExpedition`). `routes.json` es `{"version": 2, "routes": [...]}`.
- Planificar tocando el mapa; ajuste a senderos visibles
  (`snapLeg` en `map.js`), deshacer, invertir, puntos de interés (agua, campamento, refugio, cumbre,
  punto de no retorno, peligro).
- Detalle "Route Details": cifras, perfil, bitácora de paradas con hora estimada, renombrar, borrar,
  exportar GPX. Importar GPX/KML desde la expedición.

### SOS (`lib/src/profile/`, `ui/sos_screen.dart`, `ui/profile_screen.dart`)
- Perfil de emergencia local (`profile.json`): datos médicos, contactos, número de emergencias.
- Pantalla SOS (inicio y mapa): coordenadas decimal, GMS y UTM, altitud, precisión; llamar, SMS a
  contactos, compartir, copiar. Pantalla encendida mientras está abierta.

### Preparación (Fase 4)
- **Clima** (`lib/src/weather/`, `ui/weather_widgets.dart`): Open-Meteo, 16 días, por altitud de salida y
  punto más alto; guardado en `weather.json`; nieve calculada a la altitud del punto.
- **Equipo** (`lib/src/gear/`, `ui/gear_screen.dart`): `gear.json`, plantillas, peso, empacado.
- **Referencias** (`lib/src/references/`, `ui/references_section.dart`): fotos y PDF copiados a la app,
  enlaces y teléfonos.

### Correcciones (28 oct 2026)
- La zona incluida del ejemplo ya no se puede borrar ("Incluida en la app"); si una instalación vieja la
  perdió, se reinstala al abrir la app (`installSampleOnce` en `sample_data.dart`).
- Altitud del relieve con **interpolación bilineal** (`terrain_elevation.dart`): pendientes y desnivel
  sin escalones de píxel.
- "Nieve probable" solo si en las horas frías del día caen ≥ 1 mm (`snowMinMm` en `forecast.dart`).

### Hora límite: notificación (`lib/src/tracking/turnaround_alerts.dart`)
- Con un recorrido en curso (grabando o en pausa) y hora límite fijada, avisa **30 min antes** y **a la hora**.
- Temporizadores en Dart (la app sigue viva por el servicio en primer plano de la grabación) y canal nativo
  `cresta/notify` en `MainActivity.kt` (canal `cresta_alerts`, importancia alta). Se retiran al terminar o
  descartar el recorrido. Solo Android: en iOS las llamadas no hacen nada.
- Lo que ya pasó al empezar no se avisa (el panel de grabación ya lo muestra).

### Mapa libre (`ui/map_screen.dart`, `ui/expeditions_screen.dart`)
- Tarjeta "Explorar mapa" en el inicio: abre `MapScreen` sin `expeditionId`. Capas, vistas 2D/3D, mi
  ubicación y SOS funcionan; encuadra la última zona descargada.
- Grabar y planear ruta piden crear una expedición (`startNewExpedition`, que reemplaza el mapa).

### Interfaz
- Pestañas: Expediciones · Bitácora · Resumen · Mapas (`ui/home_shell.dart`).
- Splash de Android 12+ y splash cinematográfico de Flutter (mín. 2 s, "BY FRUTAL"); ícono propio.

## Estructura

```
lib/main.dart                  arranque, idioma, tema, splash → HomeShell
lib/src/app_services.dart      crea todos los servicios y almacenes
lib/src/expeditions/           expediciones
lib/src/offline/               zonas, mosaicos, fuentes, descargas, paquete de ejemplo
lib/src/tiles/tile_server.dart servidor local para el WebView
lib/src/tracking/              grabador, estadísticas, resumen, altitud del terreno, GPX, avisos de hora límite
lib/src/routes/                rutas: modelo, perfil, planificador, importar/exportar, bitácora
lib/src/profile/               perfil de emergencia, UTM, mensaje SOS
lib/src/weather/               pronóstico (Open-Meteo)
lib/src/gear/                  lista de equipo
lib/src/references/            referencias
lib/src/map/                   MapBridge y capas
lib/src/ui/                    pantallas; theme.dart = paleta y componentes del diseño
assets/web/                    map.js, MapLibre, maplibre-contour, tipografías del mapa
assets/fonts/inter/            tipografía de la app · assets/images/ textura del splash
tool/                          scripts de datos (Python) e ícono; tool/dev/ herramientas de prueba
test/                          98 pruebas
```
