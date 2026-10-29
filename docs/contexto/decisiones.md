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
- **Rutas:** entidades propias con `id` y `expeditionId` opcional (fase A del plan de rutas sueltas, clima y
  comparar). Archivo `routes.json` en formato 2 (`{"version": 2, "routes": [...]}`); el formato anterior
  (mapa expedición → ruta) se migra al abrir con id `r-<expedición>` y queda `routes.json.v1.bak`; si no se
  puede hacer el respaldo no se reescribe. Las rutas ilegibles se omiten y siguen en el respaldo.
  Una por expedición hasta que las pantallas muestren varias. Ajuste a senderos en `map.js` con lo **visible** (decisión del usuario,
  más simple que leer los mosaicos desde Dart); Dijkstra por distancia.
- **Clima:** Open-Meteo, gratis y sin clave; se guarda la respuesta cruda y se interpreta al leer.
- **SOS:** SMS con `sms:` y cuerpo codificado a mano (con `queryParameters` los espacios salen como `+`).
- **graphify:** salida en `.gitignore` (decisión del usuario: que las ramas no se pisen; el grafo se
  regenera del código y los nombres de grupos quedan locales entre ramas). Solo código (`--code-only`):
  documentos e imágenes no se envían a ningún LLM. Grupos nombrados con Gemini (elección del usuario).
  Sin merge driver de graphify (sirve solo si `graph.json` se versiona). Skill propia y breve en el repo
  en lugar de la oficial (793 líneas, asume que `graphify` existe donde corre Claude, que aquí es Windows).
  El README de graphify está desactualizado: **sí** soporta Dart (extractor por expresiones regulares).
- **Avisos de hora límite:** temporizadores en Dart (`TurnaroundAlerts`) más un canal nativo propio
  (`cresta/notify`), sin plugin de notificaciones: la grabación ya mantiene la app viva con el servicio en
  primer plano. Solo mientras hay recorrido en curso; en iOS sin efecto hasta que haya código nativo.
- **Salir del perfil sin guardar:** `PopScope` con `canPop: false` que compara el borrador con lo guardado
  y pregunta solo si hay cambios.
- **Mapa libre:** `MapScreen` sin `expeditionId` usa una `Expedition` transitoria (`id: ''`, todas las zonas
  descargadas); grabar un recorrido pide crear una expedición. Planear rutas sí se puede: al guardar se elige
  destino (sola, expedición existente o nueva). `MapScreen` acepta `routeId` (mostrar/editar esa ruta) y
  `compareRouteIds` (superponer rutas, sin planear ni grabar).
- **Un solo conjunto de mapas:** las zonas descargadas son globales y comparten mosaicos; expediciones y rutas
  solo apuntan a las que usan. Un mapa del mundo entero descargado no es viable (≈ 11 KB por mosaico).
- **Clima por ruta:** misma `WeatherService` con clave `route:<id>` (`routeWeatherKey`); el clima de la
  expedición sigue aparte. Se borra con la ruta.
- **Avisos de la ruta:** son parte de la seguridad, no de "mejor ruta"; valen aunque no haya fase E. Umbral de
  40 % sobre ventanas de 100 m; un tramo sin sendero se dibuja punteado con etiqueta y se avisa en el detalle.
- **Sol sin conexión:** cálculo propio en Dart (sin paquete ni red), validado contra astral en 7 lugares y
  fechas (±2.5 min). Se muestra en la zona horaria del teléfono porque sin conexión no hay base de zonas
  horarias; es la misma con la que la app guarda la hora límite. Margen de bajada: 2 h (decisión mía, ajustable).
- **Comparar:** máximo 3 rutas (un color cada una: cian, oro, terracota); "mejor" = menor valor, y las cifras
  de relieve no se comparan con rutas sin relieve para que los ceros no ganen.
- **Grupo en tiempo real descartado** (no hay señal en la montaña).

- **Ahorro de tokens** (pedido del usuario, 28 oct 2026): leer solo README y pendientes al empezar, graphify
  antes de `grep`, verificar con texto (`ui.sh`) antes que con capturas, capturas a la mitad. Reglas en
  `CLAUDE.md`.

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

- **Dos rutas con el mismo nombre en Comparar** → el nombre por defecto era solo la fecha → incluye la hora, y
  los chips muestran los km.
- **Botón 2D/3D desincronizado al comparar** → `_is3d` se cambiaba sin `setState` → con `setState`.
- **"Sangre B ." en el SMS** → Mensajes de Samsung pierde el "+" del cuerpo aunque vaya codificado
  (`%2B`) → el tipo de sangre se escribe con palabras ("B positivo").
- **Contactos o cambios del perfil perdidos** → salir sin "Guardar" los descartaba sin avisar → aviso
  "¿Salir sin guardar?" cuando hay cambios.
- **Pantalla roja `_dependents.isEmpty` al guardar** → `TextEditingController` liberado al volver de
  `showDialog`, mientras el diálogo seguía animando → usar `askText` (el controlador vive en el estado).
- **El splash ocupaba parte del ancho** → `AnimatedSwitcher` apila con restricciones sueltas →
  `layoutBuilder` con `StackFit.expand`.
- **Se ve el mapa a través del panel** → cualquier transparencia sobre el WebView deja ver etiquetas → opaco.
- **El ajuste a senderos da rodeos** → los mosaicos simplifican líneas y los cruces no comparten vértice →
  unir extremos sueltos a < 20 m.
- **El modelo dice lluvia en la cumbre** → la nieve/código de Open-Meteo es de su celda → decidir con la
  altitud del punto y el nivel de congelación.
- **El ejemplo dice "Sin mapas descargados"** → la zona incluida se podía quitar (Mapas o la expedición) y
  `prune()` borraba sus 422 mosaicos; nada la reinstalaba → sin botón de borrar para zonas `bundled` y
  reparación al arrancar si el ejemplo existe sin su zona.
- **Pendiente máxima de 74 %** → la altitud era la del píxel más cercano (~36 m a 19° N): en laderas sube
  en escalones de 15–20 m y una ventana de 100 m suma uno de más → interpolación bilineal. La ruta de
  ejemplo sí tiene ~60 % sostenido en 300 m (4,780–5,000 m): un valor alto puede ser real.
- **"Nieve probable" con una traza** → bastaba 0.1 mm en una hora → suma del día en horas frías ≥ 1 mm
  de agua (≈ 1 cm de nieve).
- **graphify no nombraba grupos con Gemini** → su backend de Gemini usa el cliente `openai`, que no venía
  instalado → `graphifyy[openai]` en `tool/dev/graphify-setup.sh`. Si quedaron nombres provisionales
  (nombre de archivo), `--missing-only` no los cambia: correr una vez `graphify label . --backend gemini`.
- **Reloj de grabación en 0 bajo techo** → contaba tiempo en movimiento y las lecturas > ±50 m se descartan.
- **Logo de Flutter al abrir** → faltaba configurar el splash de Android 12+ (y `values-night-v31`: con el
  teléfono en modo oscuro, `night` pesa más que `v31`).
