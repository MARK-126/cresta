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
- **Límites de OpenFreeMap** (términos del 14 oct 2026): cada descarga offline, como máximo 3,000 mosaicos o 50 MB,
  4 peticiones en paralelo y User-Agent propio; para más, escribir a info@openfreemap.org. La app ya usaba 4
  conexiones; desde el 12 nov 2026 el topo se limita a 3,000 mosaicos por zona (≈ 100 × 100 km en Detallado). Sus
  datos se regeneran cada semana. Alternativa si hace falta más: Protomaps (versiones diarias, ODbL, otro esquema:
  habría que rehacer el estilo).
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
- **Búsqueda de rutas en Dart (fase E): viable y recomendada.** Medido el 28 oct 2026 (ver `pruebas.md`): leer un
  mosaico tarda 0.2–0.6 ms, un grafo de 18 mil nodos se busca en ~8 ms, y las coordenadas coinciden con la ruta real
  a ≤ 1 m. Condiciones: (1) recortar cada línea al cuadro de su mosaico (los márgenes duplican senderos); (2) unir
  solo los **extremos sueltos** a la línea más cercana (resultado estable con 3–30 m); unir cualquier nodo con
  cualquier nodo depende de un radio de filo (≤ 2 m falla, ≥ 5 m inventa atajos); (3) hacen falta los mosaicos de
  **zoom 14** (descarga Detallado): a zoom 13 hay ~14 veces menos senderos y el grafo no conecta; (4) medir contra
  el costo de la ruta real, no contra su trazo: la más corta puede ser otra trocha igual de real.
- **Hora límite:** se quita con una "x" en su fila (y "Deshacer"). El selector usa solo el reloj
  (`TimePickerEntryMode.dialOnly`): su modo teclado fallaba con el tema de la app (pantalla roja
  "BoxConstraints has non-normalized height").
- **Sol sin conexión:** cálculo propio en Dart (sin paquete ni red), validado contra astral en 7 lugares y
  fechas (±2.5 min). Se muestra en la zona horaria del teléfono porque sin conexión no hay base de zonas
  horarias; es la misma con la que la app guarda la hora límite. Margen de bajada: 2 h (decisión mía, ajustable).
- **Comparar:** máximo 3 rutas (un color cada una: cian, oro, terracota); "mejor" = menor valor, y las cifras
  de relieve no se comparan con rutas sin relieve para que los ceros no ganen.
- **Inicio (12 nov 2026):** primero qué hacer (de lo inmediato a lo planeado: grabar, explorar, trazar, planear) y
  luego las expediciones; antes solo invitaba a planear. **Recorridos libres** como las rutas sueltas (fase A):
  `expeditionId` opcional en vez de una expedición automática, para no llenar la lista de expediciones vacías.
- **Pendiente sin franja de avalanchas** (pedido del usuario, 12 nov 2026: en Argentina casi no hay riesgo de
  avalancha): bandas de 10° para leer el terreno, y una capa aparte de zonas planas (< 10°) para acampar. Se calcula
  en el WebView con `addProtocol` (como las curvas), no en Dart: no cruza el puente y ya existe el relieve ahí. Grados
  y no %, como se usa en mapas de pendiente; los avisos de la ruta siguen en % (40 % ≈ 22°).
- **Ruta por senderos (fase E, parte 1):** en Dart y en un isolate, con los mosaicos guardados (no los que ve el
  WebView): así encuentra caminos fuera de la pantalla y a cualquier zoom. Si no hay, se cae al ajuste de `map.js`.
  Distancia pura con carreteras grandes ×2 (para caminar, mejor brecha que autopista); el desnivel entra en la parte 2.
  Pegar el punto marcado a ≤ 150 m: con el dedo a zoom 12 se falla por cientos de metros, pero ese conector cuenta
  como "con sendero", así que no conviene más.
- **Campo traviesa (fase E, parte 2):** costo = tiempo de Tobler × 0.6 (su factor fuera de sendero), que ya prefiere
  lo llano y rodea lo empinado sin reglas extra; tope duro de 45° (en relieve de 30 m eso es pared). En Dart con la
  cuadrícula del relieve (no en `map.js`), para que sirva igual que los senderos y se pruebe con relieves sintéticos.
  Va como último recurso antes de la línea recta y se dibuja como "sin sendero": no ve ríos, barrancas cortas,
  vegetación ni cercas.
- **Senderos por tiempo, no por distancia:** con el relieve, cada arista cuesta lo que tarda a pie (Tobler, distinto
  subiendo y bajando). En el Izta no cambió la ruta, pero evita rodeos que suben de más.
- **Actualizar mapas (12 nov 2026):** pedido del usuario ("al abrir con Wi-Fi revisar si hay actualización"). Se
  revisa por antigüedad (90 días), no por la versión semanal de OpenFreeMap: los senderos de montaña cambian despacio
  y avisar cada semana sería ruido. Se ofrece, no se descarga solo (la descarga necesita la app abierta). Solo el
  topográfico; cada actualización respeta el tope de 3,000 mosaicos.
- **Grupo en tiempo real descartado** (no hay señal en la montaña).

- **Ahorro de tokens** (pedido del usuario, 28 oct 2026): leer solo README y pendientes al empezar, graphify
  antes de `grep`, verificar con texto (`ui.sh`) antes que con capturas, capturas a la mitad. Reglas en
  `CLAUDE.md`.

## Diseño (UI)

- Sistema **"Andes Industrial"** (Google Stitch del usuario, proyecto "Live Geolocation Tracking"; la
  exportación está en el escritorio del usuario: `stitch_live_geolocation_tracking.zip`).
- **Solo oscuro.** Pizarra `#0E1416`; Cian Cumbre `#46EAE5` = acción, rastreo, listo; Oro Inca `#F0BF63` =
  importante, pendiente; Terracota `#FFA089` = alertas, grabación, SOS. Tokens en `Andes` (`theme.dart`).
- Sin bordes de 1 px ni sombras: bloques por tono (desde el 12 nov 2026 también los botones secundarios: el "borde
  fantasma" al 35 % se quitó) (`TonalCard` con barra de acento). Cifras con `Figure` /
  `dataStyle` (Inter, números tabulares). Botón principal `GlowButton`. Sobre el mapa, `Glass`; el panel
  inferior del mapa es **opaco**.
- Inter incluida en la app (OFL). Mapa base claro (topográfico) a propósito, por legibilidad del relieve.
- Solo se adaptan pantallas de Stitch con equivalente real en Cresta: nada de logística, metas ni rankings.
- Splash: Android 12+ muestra **siempre** su pantalla con el ícono (no se puede quitar; el usuario eligió
  dejarla). Su montaña coincide en tamaño y lugar con la del splash de Flutter. Mínimo 2 s, "BY FRUTAL".
- Ícono generado con `tool/make_icon.py`; adaptativo y monocromático en Android 8+/13.

## Errores resueltos (síntoma → causa → solución)

- **"Textos grises con poco contraste" (revisión del 12 nov 2026)** → no era cierto: medido, `onSurfaceVariant`
  da 7.3–10.9:1 sobre los fondos (AAA) y `outline` 3.9–5.9:1; la impresión venía de capturas a la mitad → no se
  cambió. Si con sol cuesta leer, lo que pesa es el tamaño (etiquetas de 10–11 px), no el color.

- **"Mi ubicación" solo centraba la primera vez** → `_locating` nunca volvía a `false` y el vuelo solo iba en la
  primera lectura → centra en cada toque con la última lectura (o `getLastKnownPosition` mientras llega una).
- **En 3D tu punto quedaba fuera de la pantalla tras centrar** → MapLibre 4.7.1 toma la altura del destino al
  empezar el vuelo; si su relieve no había cargado, la cámara quedaba a la altura del sitio anterior (la montaña) →
  en `moveend` + `idle`, `map.js` corrige `transform.elevation` con la del centro y hace `jumpTo` al mismo centro.
- **El punto quedaba a la mitad de toda la pantalla, tapado por el panel** → con animaciones reducidas (el S23 las
  tiene en 0), `flyTo`/`easeTo` de MapLibre se vuelven un `jumpTo` que descarta `padding` → `essential: true` (con
  duración 0 sigue siendo instantáneo). Además el margen era fijo al 38 %: ahora sigue al panel.
- **Mapa en blanco tras agregar los límites** → dos `interpolate` de zoom dentro de un `match` ("Only one zoom-based
  step or interpolate") → un solo `interpolate` con el `match` en cada parada. El error sale en el log como `Mapa: ...`.
- **Sin nombres de calles ni colonias** → el estilo propio nunca tuvo capas de `transportation_name` y `places` solo
  dejaba ciudad/pueblo/caserío → capas nuevas (ver `estado.md`). Los datos de OpenFreeMap sí los traían.

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
