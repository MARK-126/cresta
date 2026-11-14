# Registro de pruebas

Una entrada por prueba, **también las que fallaron**. Lo más reciente arriba.
Formato: fecha · rama/commit · qué · cómo · resultado · corrección.
Teléfono de pruebas: Samsung Galaxy S23 Ultra (SM-S918B), Android 16, salvo que se diga otra cosa.

## Sin probar todavía (revisar antes de dar por hecho)


- **Buscar sin señal en el teléfono** (12 nov 2026): botón, hoja, tiempo de la primera vez con las 3 zonas, vuelo,
  marca y tarjeta.

- **Avisos de puntos de interés en una salida** (12 nov 2026): instalado y la app arranca. El canal sigue como
  "Hora límite de regreso" hasta el próximo aviso (Android lo renombra al volver a registrarlo). Falta, con una ruta
  con puntos, recibir la notificación al acercarse y ver "Próximo:" en el panel (la "Ruta de Salto" no tiene puntos).

- **Volver por mi traza caminando** (12 nov 2026): falta grabar unos cientos de metros, tocar "Volver al inicio por mi
  traza", ver "REGRESANDO", lo que falta y el rumbo, y salirse > 80 m para ver el aviso. En el teléfono quieto solo se
  comprobó que el panel graba igual. Cubierto por pruebas automáticas (abajo).

- Grabación **al aire libre** con la pantalla bloqueada: reloj, notificación fija, que siga grabando,
  y que la Bitácora y el Resumen se llenen con un recorrido real.
- Importar un GPX/KML real desde el teléfono (la lectura está cubierta por pruebas automáticas).
- Adjuntar una foto o un PDF como referencia y abrirlo.
- Exportar GPX (ruta) a otra app.
- Descargas de mapas en Android con conexión móvil (opción "solo Wi-Fi").

## 2026-11-14

**Ajustes de mapa e imagen · `feat/ajustes-mapa-imagen`** (S23) — mapa libre en 2D (el botón ofrece "3D"); barra
de acciones con degradado teal; "Ver en el mapa" del recorrido 3 con la traza teal; imagen con mapa sin senderos, con
las capas elegibles y tamaños 9:16 · 1:1 · 4:5. **OK**.

**Rediseño · `feat/rediseno-jerarquia`** (S23, solo vistas; datos iguales)
- Inicio con "GRABAR" enorme y tres botones; Bitácora con km grandes y la forma de cada recorrido; Resumen "+80 m";
  Recorrido "6.81" con su forma, cifras parejas, perfil de 700 a 850 m (antes plano de 500 a 1,000) y barra fija;
  Compartir abre la hoja de cuatro opciones; Expedición "SALTO" con la ruta y "ABRIR MAPA | 3.3 km · +883 m";
  "IZTACCÍHUATL POR LA ARISTA DEL SOL" en dos líneas. **OK**.
- Falla: la forma del recorrido junto a los km salía diminuta (sin alto fijo en la fila) → `SizedBox` con alto. **OK**.
- Mapa de Mendoza a z15: sin comida; las farmacias seguían llenándolo → fuera de "de lejos". **OK**.

**Ícono del perfil · `fix/icono-perfil`** (S23) — en el inicio, junto a SOS, la personita sola. **OK**.

**Imagen del recorrido · `feat/imagen-recorrido`** (S23; recorrido 3 del usuario, solo leído)
- Mapa de fondo al tamaño del recuadro: nombres enormes → mapa a 400 px lógicos reducido. **OK** después.
- Fondo liso de inicio: traza vertical, "DESDE Juan Galo de Lavalle" y "HASTA Ciclovía" (antes "Mendoza" y luego
  "Estilo Repuestos Renault": corregido), fecha vertical, cifras. PNG 1,080 × 1,920. **OK**.
- Foto: imagen de prueba propia subida a `Pictures/CrestaPrueba` (para no abrir las fotos del usuario) elegida en el
  selector de Google; queda debajo, oscurecida 40 %; guardada en JPG. **OK**.
- Mapa: captura a 1,080 × 1,920 con la traza y las cifras. Sin fondo: PNG con alfa 0 en las esquinas. **OK**.
- Falla: la segunda imagen no aparecía en la galería (mismo nombre) → hora en el nombre. **OK** después.
- Nota de prueba: con `uiautomator` el aviso con acción no se cierra solo (accesibilidad) y tapaba el botón.
- Limpieza: imágenes y carpeta de prueba borradas; datos del usuario iguales.

**Recortar para compartir · `feat/recorte-compartir`** (S23; recorrido 3 del usuario, respaldado y restaurado)
- Detalle → "Recortar para compartir": mapa con la traza; tiradores a 698 m y 458 m → "Se ocultan 698 m al inicio y
  458 m al final. Se ven 5.7 km de 6.8 km", lo oculto gris punteado. Guardar → `hideStartM: 698`, `hideEndM: 458` y
  el estado en el detalle. **OK**.
- Video rápido: empieza en 12 de Octubre (698 m después del inicio real) y el contador termina en 5.66 km. **OK**.
  Nota: el título sigue con las cifras del recorrido completo (6.81 km).
- Limpieza: `tracks.json` restaurado (md5 igual), video borrado de la galería.

**Abrir en tu posición · `fix/grabar-en-tu-posicion`** (S23, en Mendoza) — Inicio → "Grabar · Desde aquí": con la hoja
"Grabar recorrido" abierta el mapa ya está en tu posición (antes, la última zona descargada). Se cerró sin grabar: sin
recorrido nuevo, datos iguales. **OK**.

**Splash más arriba · `fix/splash-arriba`** (S23) — capturas cada 0.4 s al abrir: la montaña de Android y la de Flutter
en el mismo lugar (~43 % del alto), sin salto; la marca debajo deja el conjunto centrado. **OK**.

**Noche de inicio · `feat/noche-por-defecto`** (S23)
- Sin `map.json`: el mapa libre abre en Noche; Vista dice Noche · Claro · Satélite · Relieve. Elegir Claro → se guarda
  `{"base": "topo"}` y al volver a entrar abre claro. Selector de zonas: Noche · Claro · Satélite, abre con la
  preferencia y elegir Noche la guarda. **OK**. Se borró `map.json` al terminar; datos del usuario iguales.

**Contorno sobre mapa oscuro · `feat/contorno-mapa-oscuro`** (S23, mapa libre en Mendoza)
- Topográfico: barra, título y botones sin cambios. Noche y Satélite: tono más claro y aro gris; la barra y los
  botones se separan del mapa. **OK**. Pruebas de widget: sin aro en mapa claro, con aro y opaco en oscuro.

**Opciones del video · `feat/video-opciones`** (S23, desde Mendoza; recorridos 2 y 3 del usuario, solo leídos)
- Hoja "Opciones del video": fondo de cuatro opciones en una fila, velocidad e interruptores. **OK**.
- Recorrido 2 (1 km, Mapa, Normal): vista previa con el punto que avanza y FIN; al terminar "Guardado en tu galería,
  álbum Cresta". Video de 13 s (antes 15 s), 720 × 1280, 30 cuadros/s; calles con nombre, edificios en volumen y
  alejamiento final que llena el cuadro. **OK**.
- Recorrido 3 (6.8 km, Noche, Rápido): 15 s de video (antes ~46 s), 19 s en generarse. Falla: en la cuadrícula del
  centro salían casi todas las calles y su nombre en cualquier parte (cada calle larga cruza el recorrido) → solo
  el pedazo de calle a ~200 m (`video-streets`). Repetido: nombres solo junto a la traza. **OK**.
- Mapa libre: "Noche" en Vista (montaña y ciudad) y "Edificios en 3D" en General; en el centro de Mendoza a z16 se
  ven los edificios en volumen. **OK**.
- Limpieza: borrados los 3 videos de prueba de `Pictures/Cresta` (sin entradas en la galería) y `video.json`; datos
  del usuario con md5 iguales.

## 2026-11-13

**Buscar y trazar · `feat/buscar-y-trazar`** (S23, desde Mendoza)
- Mapa libre → buscar → Cerro del Medio (42 km): tarjeta con botón de flecha "Ruta hasta aquí" → trazado desde tu
  posición, 42.2 km en línea recta con aviso (Mendoza no está en los mapas descargados). **OK**.
- Iztaccíhuatl (6,599 km): pregunta "¿Desde dónde sales?". Falla: sugería lugares cerca de ti → `near`: "CERCA DE
  IZTACCÍHUATL" con "Tu ubicación" arriba. Salida Peña Ordoñez → 0.6 km +13 m por sendero, encuadrado. **OK**.
- Falla: distancias "6598.8 km" → `fmtKm` con miles ("6,598.8"). **OK**.
- Expedición Salto → buscar → "Agregar a la ruta": 3.3 → 36.1 km; salir sin guardar, `routes.json` igual. **OK**.
- Selector de zonas sin red para la app (chain3): "refugio" → "SIN CONEXIÓN · EN TUS MAPAS" con 4 resultados; elegir
  uno pone el nombre de la zona. El mapa queda en blanco por el método (bloquea `127.0.0.1`; el mapa libre igual).
  Con red: calcula el recuadro y "Aconcagua" busca en línea. **OK**.
- Datos del usuario idénticos (md5). 193 pruebas automáticas en verde.

**Mapa limpio · `feat/mapa-limpio`** (S23)
- Falla al quitar el panel: la pila se encogió al alto de la barra de arriba (mapa en una franja, la barra de abajo
  arriba) → `SizedBox.expand`. **OK**.
- Explorar: mapa a pantalla completa, barra Capas · Grabar · Ruta. Capas: vista, relieve, capas; satélite aplicado.
  Expedición "Salto": tarjeta "Ruta de Salto · 3.3 km · +883 m · ≈ 3 h 02" y "Editar ruta"; detalle con perfil,
  "Recorrer en 3D" y "Ver ruta completa". Trazar (mapa libre, sin guardar): buscador arriba, tira con cifras; falla: el
  aviso de campo traviesa tapaba los km → cifras y aviso en dos líneas. Grabar (ubicación encendida para la prueba y
  apagada al final): barra de datos arriba, tira abajo; "Más" abre el panel completo. **OK**.
- Foto grabando (cámara de Samsung, Aceptar): guardada con lat/lng y 738 m; "Fotos (1)" en el detalle; pantalla
  completa con fecha, hora y altitud. Recorrido borrado → índice vacío y archivo borrado. El ícono 📷 quedaba bajo la
  marca de inicio y tu posición → la capa de fotos va encima de la traza. **OK**.
- Plan de salida con "Salto" (sin enviar): horarios sugeridos y mensaje completo; sin contactos el SMS se desactiva.
  Expediciones sin cambios. **OK**. Nota: el perfil del usuario tiene un celular en "Número de emergencias".
- Velocidad en la barra: quieto bajo techo marcaba 4.0 km/h (GPS por Wi-Fi, ±16 m) → solo con precisión ≤ 15 m.
- 193 pruebas automáticas en verde.

**Plan de salida y fotos · `feat/plan-y-fotos`** (solo pruebas automáticas: el teléfono se desconectó)
- 192 en verde: horarios sugeridos (con fecha, sin fecha, sin ruta), el mensaje completo (ruta, enlace, hora límite,
  alarma, 911, sangre), regreso otro día; fotos guardadas con ubicación y en orden, recordadas al reabrir, borrar una y
  todas con su recorrido sin tocar las de otro.
- Falta en el teléfono: la hoja del plan con la expedición "Salto" (sin enviar), SMS y compartir; tomar una foto
  grabando, verla en el mapa, en el detalle y a pantalla completa.

**Barra de datos y brújula · `feat/barra-datos`** (S23)
- Con la ubicación del teléfono apagada, "Grabar" no abre nada y muestra el aviso "Activa la ubicación…" con "Abrir
  ajustes" (correcto). Encendida para la prueba (y apagada otra vez al final): barra arriba con ALTITUD 738 m,
  VELOCIDAD 0.0 km/h (quieto), DISTANCIA 0.00 km. Mapa girado 60°: aparece la brújula con la aguja al norte; al
  tocarla el mapa vuelve al norte, conserva la inclinación (50°) y la brújula se va. Grabación descartada. **OK**.
- Pruebas automáticas: 186 en verde (4 de velocidad en vivo y 1 de la barra).

**Video del recorrido: relevamiento de fallas** (prueba del usuario: parpadea, abre en un punto por defecto, a veces
sale en blanco, cuadros trabados; pide leyendas de inicio y fin más visibles)
- Videos del usuario (caché de la app y los enviados por WhatsApp, que sí acepta el MP4): uno a **6.4 cuadros/s** (91
  cuadros en 14 s, ~160 ms entre cuadros) y otro a 9.6 cuadros/s **todo en blanco** (mismo brillo en los 127 cuadros:
  solo cielo, color de fondo y el título). Análisis con `ffmpeg` (`imageio-ffmpeg` en un venv temporal).
- **En blanco**: reproducido en el teléfono (también la pantalla). `debugState()` en `map.js`: durante el vuelo
  `transform.elevation` = 0 con el suelo a 808 m (×1.4 de exageración = 1,138 m): la **cámara queda bajo el terreno**
  y solo se dibujan las etiquetas (el resto va en la textura del relieve). Causa: al empezar el vuelo el relieve del
  lugar aún no cargó, `getElevationForLngLatZoom` da 0 y la corrección por cuadro (13 nov) lo copiaba. Antes de esa
  corrección pasaba lo contrario: la altura del ejemplo del Izta (cámara lejísimos).
- **Parpadeo**: en cuadros seguidos, nombres e íconos aparecen y desaparecen ("Punta del Lago", "Fuente de los
  Continentes", íconos): con la cámara girando en cada cuadro, MapLibre recalcula qué etiquetas caben y las funde.
- **Trabado**: el mapa se dibuja a ~44 cuadros/s y copiar el lienzo cuesta 12.8 ms; con la copia en cada cuadro el
  codificador da 22–30 cuadros/s (H.264 o VP8, 720 × 1546 o 720 × 1280). Los 6–10 del usuario coinciden con la primera
  vez en una zona: los mosaicos de la ciudad bajan de internet durante el vuelo, el mapa se dibuja a tirones y, como el
  vuelo avanza con el reloj, la cámara salta. `MediaRecorder` pone a cada cuadro la hora real: no hay forma de esperar a
  que cargue el mapa sin que el video se congele.
- **Punto por defecto**: el mapa arranca centrado en el ejemplo (Izta), luego encuadra la última zona descargada y
  recién después vuela al recorrido.
- **Corrección** (`fix/video-recorrido`): video generado cuadro por cuadro (ver `estado.md`). Con el "Recorrido 2":
  450 cuadros a 30/s exactos en 15 s, sin cuadros lisos ni parpadeos (análisis de cuadros), INICIO y FIN visibles,
  cámara a la altura correcta todo el vuelo, 7.4 MB (4 Mbps; con 6 Mbps eran 11 MB). Se genera en ~12 s. El mapa queda
  tapado con "Preparando el video…" hasta el primer cuadro (ya no se ve el punto por defecto). Falla en el camino: el
  cartel INICIO caía sobre la franja del título → no se dibuja ahí. Menú de compartir cerrado sin enviar; videos
  temporales borrados. **OK**.
- WebCodecs (`VideoEncoder`) está en el WebView del S23 (Chrome 157; H.264 720 × 1280 admitido): permite armar el video
  cuadro por cuadro con tiempos exactos, esperando a que cargue cada cuadro.

## 2026-11-12

**Salida del usuario al Parque General San Martín (Mendoza), con pantalla bloqueada** · `main` + `feat/buscar-lugares`
- Observaciones del usuario: al grabar "desde aquí" no se actualizaba la posición ni se guardaba el recorrido; pedía
  encender el Wi-Fi para mejorar la ubicación cada vez; no se pudo exportar ni ver el recorrido; "Ver en el mapa"
  llevaba a una zona descargada; con la pantalla bloqueada el recorrido salía en línea recta; había que tocar
  "Mi ubicación" para ver dónde estaba; la traza no mostraba inicio ni fin; letras difíciles de leer sobre el satélite.
- Datos del teléfono: "Recorrido 1" 28 min y **0 puntos**; "Recorrido 2" un punto cada ~8 s con la pantalla encendida y
  huecos de **314 s y 228 s** (los tramos rectos). Permiso de ubicación "mientras se usa" (correcto) y la app ya exenta
  de la optimización de batería.
- Causas (código de `geolocator_android` 5.2.1):
  1. El plugin reutiliza el flujo de posiciones que ya esté abierto e **ignora la configuración nueva**. Con
     "Mi ubicación" abierto en el mapa (sin servicio en primer plano), la grabación recibía ese flujo: sin servicio, al
     bloquear la pantalla dejaban de llegar puntos.
  2. El cliente "fusionado" de Google revisa los ajustes y muestra "mejorar la precisión (Wi-Fi)" en cada inicio; si se
     rechaza, **corta el flujo con un error**. El grabador ignoraba el error y seguía "grabando" sin puntos.
  3. Recorrido sin puntos: no hay nada que ver ni exportar, y el mapa se quedaba en la zona descargada.
- Corrección (`feat/gps-grabacion`): un solo flujo de GPS en `LocationService` (`watch()` para la vista y
  `recording()` para grabar; se abre uno a la vez, la grabación con el servicio en primer plano), `forceLocationManager`
  en Android (el proveedor "fused" del sistema, sin el aviso de Wi-Fi), aviso y reintento cada 15 s si el GPS falla,
  posición en vivo y seguir al abrir el mapa libre, y no guardar ni mostrar como normal un recorrido sin puntos.
- **Segundo plano (13 nov 2026, de madrugada):** grabando con "Mi ubicación" ya abierto, app en segundo plano (botón de
  inicio, para que no se cayera la depuración inalámbrica como al bloquear) y posiciones simuladas con el proveedor de
  prueba `fused` (`cmd location providers add-test-provider`): **un punto cada 5 s** durante 1 minuto con la app fuera
  de la vista. Al quitar el proveedor de prueba: el panel avisó "El GPS no está entregando tu posición…" y a los 15 s
  se recuperó solo (GPS ±16 m). Grabación de prueba descartada. **OK**. Falta: caminar con la pantalla bloqueada.
- Falla mía en la prueba: la barra de arriba del mapa quedó a media pantalla (el `Align` que separa el título de la
  lupa se estiraba a todo el alto) → `heightFactor: 1`. **OK**.
- Indicaciones de la primera vez: mapa, trazar ruta y grabar salen una vez. **OK**.
- Íconos de lugares en el Parque San Martín: agua, museo, colectivo, hotel, comida, deportes, estacionamiento. Falla:
  muchos íconos de "cultura" sin nombre (estatuas) → sin nombre solo lo útil. Satélite: nombres blancos con borde
  oscuro legibles. **OK**.
- Trazar por nombre: "Tu ubicación" como salida + "Museo Moyano" buscado en línea ("EN TODO EL MUNDO") → ruta de 5.4 km
  por calles, en teal. No se guardó. **OK**.
- Video del recorrido con el "Recorrido 2" del usuario. Fallas en orden: (1) el codificador por hardware falló con el
  lienzo completo → copia de 720 px; (2) la copia salía vacía fuera de `render` → copiar en `render`; (3) los pedazos
  llegaban pero no el final: `type` pisaba el nombre del evento → `mime`; (4) a mitad del vuelo la cámara se veía
  lejísimos (altura del terreno del lugar anterior) → altura corregida en cada cuadro y esperar a que cargue el inicio.
  Resultado: MP4 de 4.4 MB que abre el reproductor del teléfono, con título y distancia; se abre compartir (cerrado
  sin compartir; video temporal borrado). **OK**.
- En el teléfono: con la ubicación del teléfono apagada, el mapa no centra (correcto). Encendida: el mapa libre se
  centra solo en tu posición y queda "Siguiendo tu posición", sin el aviso de Wi-Fi. Al grabar con "Mi ubicación"
  abierto: se cierra ese flujo y se abre el de grabación con servicio en primer plano (`isForeground=true`, tipo
  ubicación).

**Buscar sin señal · `feat/buscar-lugares`**
- Con los 210 mosaicos z14 de Vallecitos copiados del teléfono: 100 lugares en 42 ms (31 cumbres, 3 refugios, 11
  campamentos, 1 agua, 29 tramos de río…). "arenales" → Cerro Arenales (3,460 m, 7.7 km); "cerro adolfo" → Cerro Adolfo
  Calle (4,227 m) y su sendero de descenso; "refugio" → Mausy, UNCuyo, San Bernardo. Fallas: "arroyo blanco" salía
  5 veces (un tramo por mosaico) → solo el tramo más cercano; "agua" no encontraba "punto 3" (agua potable) → también
  coincide por tipo, después de los nombres. **OK**.
- Pruebas automáticas: 178 en verde (10 nuevas en `places_test.dart`, con 4 mosaicos reales del Cordón del Plata en
  `test/fixtures/topo/`: tipos y altura, sin repetir un sendero de dos mosaicos, juntar repetidos, orden de la
  búsqueda, sin acentos, por tipo, tramo más cercano, búsqueda vacía, índice guardado y rehecho al actualizar la zona).
- En el teléfono: pendiente (se desconectó al instalar).

**Pasar un recorrido libre a una expedición · `feat/recorrido-a-expedicion`** (S23)
- Recorrido libre de prueba ("Prueba Cerro", 8 dic 2024, 30 puntos) cargado con `run-as`. Detalle: "RECORRIDO LIBRE";
  menú con "Pasar a una expedición"; selector con "Recorrido libre" marcado, "Nueva expedición" y las 3 expediciones.
  **OK**.
- Nueva expedición: formulario lleno ("Prueba Cerro", "dom 8 dic 2024", botón "Crear expedición"); el calendario abre
  en diciembre de 2024 sin fallar. Al crear: cabecera "RECORRIDO · PRUEBA CERRO", la Bitácora lo muestra con la
  expedición y la expedición lo lista en "Recorridos grabados". **OK**. Falla: la fecha se guardó con la hora de salida
  (`2024-12-08T10:00`) → se pasa solo el día (`DateUtils.dateOnly`) → `2024-12-08T00:00`. **OK**.
- "Cambiar de expedición" → Vallecitos ("RECORRIDO · VALLECITOS") → "Recorrido libre" ("Ahora es un recorrido libre.",
  `expeditionId: null` en `tracks.json`). **OK**. Datos del usuario restaurados (sin recorridos, 3 expediciones).
- Pruebas automáticas: 168 en verde (1 nueva: pasar a una expedición y volver a libre, se conserva al recargar con
  sus puntos; el resumen guardado se redondea al metro).

**Avisos de puntos de interés en el teléfono**: instalado, la app arranca con el inicio de siempre. El canal aún dice
"Hora límite de regreso" (`dumpsys notification`): se crea en `showAlert`, así que se renombra con el próximo aviso.

**Avisos de puntos de interés · `feat/aviso-puntos`** (solo pruebas automáticas; el teléfono se desconectó)
- Distancias de aviso; próximo punto por delante (400 m, luego 800 m; uno a 1 km de la ruta no cuenta; al final, nada);
  cerca según el tipo (agua 150 m, no retorno 300 m); textos ("A 120 m del agua…", "Llegaste al agua.", "Estás en el
  punto de no retorno."); grabador simulado caminando 2 km: dos notificaciones (agua a 150 m, no retorno a 300 m), sin
  repetir y sin la del campamento lejano. 167 en verde. Compila (cambio nativo del nombre del canal).
- **Falla mía** (vista antes de probar): a menos de 20 m el texto decía "Llegaste del agua"; ahora cada tipo tiene su
  frase.

**Batería · `feat/bateria`** (cambio nativo: compilación completa)
- En el S23 (la app no estaba exenta: `dumpsys deviceidle whitelist` sin cresta): "Grabar · Desde aquí" → el diálogo de
  modo muestra el consejo de modo avión → Normal → "Que Android no detenga la grabación · Ahora no / Permitir" →
  Permitir abrió el diálogo del sistema "¿Dejar de optimizar el uso de la batería?" (`RequestIgnoreBatteryOptimizations`).
  Se tocó **Cancelar** para no cambiar la configuración del usuario; la grabación siguió (GRABANDO). Descartada:
  `tracks.json` vacío; la app sigue sin exención. **OK**. 162 pruebas en verde.
- Sin probar: aceptar la exención y que el aviso ya no salga (lo hace el usuario al grabar de verdad).

**Llegada en vivo · `feat/llegada-en-vivo`**
- Pruebas automáticas: Naismith; sin datos (menos de 500 m o 15 min) usa la regla; 2 km/+200 m en 1 h 30 → ritmo 1.5 y
  4 km/+400 m que faltan → 3 h; más rápido 0.75; muy lento se acota a 2.5; tan lento que no es movimiento → sin ritmo;
  sin ruta → nada. Panel de regreso: "Llegas al inicio ≈ HH:MM (en …), según la regla de Naismith". 162 en verde.
  **Falla mía** en una prueba: esperaba ritmo 2.5 con una velocidad que la app ni cuenta como movimiento (el resultado
  correcto era "sin ritmo").
- En el S23, expedición de ejemplo con hora límite 16:00 (editando `expeditions.json` con respaldo) y grabando a las
  14:20 lejos del Izta: "Faltan 12.1 km y 1,701 m de subida", "Llegas al final ≈ 21:38 (en 7 h 17 min), según la regla
  de Naismith, sin contar paradas" y el aviso "…llegarías al final a las 21:38, después de tu hora límite (16:00)". **OK**.
  El aviso decía "A este ritmo" aunque aún no hay ritmo: ahora dice "Según la regla de Naismith" o "A tu ritmo".
  Grabación descartada (`tracks.json` vacío) y `expeditions.json` restaurado idéntico.

**Volver por mi traza · `feat/volver-traza`**
- En el S23 (reconectado en `192.168.100.3:33071`), quieto bajo techo: "Grabar · Desde aquí" → GRABANDO, GPS ±18 m,
  49 s; sin recorrido aún, el botón "Volver al inicio" no aparece (correcto). Descartado: `tracks.json` vacío.
- Traza al revés sin la nube de puntos de cuando estás parado y terminando justo en la salida; rumbo y punto cardinal;
  grabador: sin recorrido no guía, tras 500 m faltan 500 m y 0 m de subida, a la mitad faltan 250, y al dejar de guiar
  vuelve la ruta planeada; panel (widget): "Volver al inicio por mi traza" → "REGRESANDO", lo que falta y "El inicio
  está a 503 m en línea recta, rumbo 180° (S)"; "Dejar de guiar el regreso" vuelve a "GRABANDO". 158 en verde.
- **Fallas mías:** el filtro de 5 m dejaba la traza terminando a 1 m de la salida (ahora termina en ella); al insertar
  pruebas borré una función auxiliar del archivo (`_sinh`); y la prueba de widget con una grabación real se colgaba
  (temporizadores reales del grabador): se arma el estado del grabador a mano.

**Actualizar mapas con Wi-Fi · `feat/actualizar-mapas`**
- Pruebas automáticas: al actualizar el descargador solo pide topo viejo (relieve y satélite no) y es reanudable;
  ciclo completo (zona → vieja a los 120 días → `refreshStale` → al día, sigue `isComplete` mientras, conserva su
  tamaño, se guarda en disco); sin topo o pasando el tope no se ofrece. 154 en verde. **Falla mía:** la reanudación
  volvía a pedir 3 mosaicos escritos en el mismo segundo del corte (fecha de archivo al segundo): corte 2 s antes.
- En el S23 (solo la zona del ejemplo, fechada en julio editando `regions.json` con respaldo): al abrir con Wi-Fi salió
  "'Iztaccíhuatl–Popocatépetl' tiene senderos y calles hace 4 meses · Ahora no · Actualizar". Actualizar: en ~2 s
  bajó 121 mosaicos topo (relieve y satélite intactos, salvo uno de cada uno que faltaba en el paquete) y la zona
  dijo "Senderos y calles del jue 12 nov 2026". **Falla mía:** el tamaño bajó de 9.4 a 4.5 MB (la cuenta del
  descargador no incluye el z14 extra del ejemplo): ahora no se recalcula al actualizar; repetido, quedó en 9.4 MB y el
  aviso se fue. Vallecitos y Salto quedaron idénticos al respaldo.

**Ajustes de diseño · `fix/diseno-revision`**
- Expedición de ejemplo: "Armar lista de equipo", "Actualizar", "Agregar zona de mapas" y "Agregar referencia" ya son
  bloques tonales sin borde. **OK**.
- Mapas: "Descargar una zona" arriba de la lista; abre "NUEVA ZONA" centrada en la última zona (el salto), 10 × 11 km,
  138 mosaicos. Salí sin descargar. **OK**.
- Contraste medido (WCAG): `onSurfaceVariant` 7.3–10.9:1, `outline` 3.9–5.9:1, oro 7.2–10.9:1. No se cambió.
- 151 pruebas en verde.

**Ruta a campo traviesa y senderos con desnivel (fase E, parte 2) · `feat/ruta-terreno`**
- Pruebas automáticas: Tobler; ida y vuelta píxel ↔ coordenadas; en lo plano va recto (±2 %); rodea un cono de 500 m
  (no pasa de 3,200 m); cruza una pared de 300 m solo por su hueco; sin paso o sin relieve → null; relieve real del
  Izta (PNG decodificados en la prueba): campo traviesa de Paso de Cortés hacia el Popo sin tramos de más de 45°, y la
  ruta por senderos con relieve; planificador: sin sendero usa el terreno, queda `snapped: false` con aviso, y sin
  terreno, línea recta. 151 en verde. **Fallas mías:** dos patrones en un mismo `final` (Dart no lo permite) y
  comparar `LngLat` con `==` (no tiene igualdad por valor).
- Medición: Izta por senderos con relieve 11.80 km / 125 ms (sin relieve 11.78 km); ambos a < 60 m de la real en ~40 %
  (arriba va por el valle del oeste, igual que antes). Campo traviesa: 2,126 m contra 1,978 en línea recta, 17 ms.
- En el S23, ladera del Popo con la capa de pendiente encendida: tramo punteado de 2.7 km, +233 m, 1 h 16 que rodea lo
  rojo/morado por lo verde/amarillo, con el aviso de campo traviesa. **OK**. Salí sin guardar (`routes.json` igual).

**Ruta por senderos (fase E, parte 1) · `feat/ruta-senderos`**
- Pruebas automáticas con los mosaicos del paquete del Izta (78 de z14): Paso de Cortés → cumbre por senderos (10.5–14 km,
  la mitad de abajo a < 60 m de la ruta real en > 80 % de los puntos), tramo corto sobre el mismo sendero (±15 %), sin
  mapas o mosaicos rotos → null, y tope de mosaicos. 142 en verde. **Falla mía** primero: el final quedaba a 12 cm del
  punto marcado (se pegaba al sendero); ahora termina justo en él.
- Medición: 11.78 km (igual que el experimento) en 125 ms; tramo 100–300 de la ruta real: 4.56 km contra 4.55, 8 ms.
- En el S23, "Trazar ruta" y dos toques simulados (`CrestaBridge.postMessage` con `mapTap`) a zoom 11.6: ruta
  continua de 11.8 km, +1,624 m, 7 h 00, dibujada por la arista. Con los mismos puntos, el ajuste viejo de `map.js`
  (`snapLeg`) dio null: habría sido línea recta. **OK**.
- Dentro del cráter del Popo (sin senderos): línea recta con el aviso "No encontré un sendero… en tus mapas
  descargados ni en lo que se ve". **OK**. Se salió sin guardar (`routes.json` igual: solo "Ruta de Salto").

**Pendiente del terreno y zonas planas · `feat/pendientes`** (S23, ejemplo del Izta)
- Capa "Pendiente del terreno" a z12.5 en 3D: colores por grados sobre todo el macizo, sin errores en el log. **OK**.
- Valores (`slopeAt`): Paso de Cortés 2.3° (collado plano), borde del cráter del Popo 30.5°, una ladera del Izta 19.6°.
  El mismo píxel calculado aparte en Python con el mosaico sacado del teléfono (`run-as`, 36.1 m/píxel): 19.6°. **OK**.
- "Zonas planas" desde la lista de capas: la leyenda (menos de 5° · 5–10°) sale al encenderla; en el mapa marca valles,
  llanos y la parte alta del Izta. **OK**.
- Pruebas automáticas: 138 en verde (nueva: cada capa de Dart existe en `LAYER_MAP` de `map.js`; pendiente y planas
  apagadas al entrar).

**Inicio nuevo y recorridos libres · `feat/inicio`** (S23, puerto inalámbrico nuevo `192.168.100.3:45425`)
- Inicio: "¿Qué quieres hacer?" con las cuatro tarjetas en 2 × 2 y "TUS EXPEDICIONES · 3 · 3 listas sin conexión". **OK**.
- "Grabar · Desde aquí": abrió el mapa libre con el selector de modo; con Normal empezó a grabar ("GRABANDO", GPS ±15 m,
  reloj corriendo) siguiendo la posición. En el inicio: aviso "GRABANDO · Recorrido libre · 0.0 km" y Grabar y Trazar
  apagadas; el aviso volvió al mapa grabando. Terminar → Guardar abrió el detalle; en la Bitácora: "TERMINADO ·
  RECORRIDO LIBRE". **OK**. El recorrido de prueba se borró (Bitácora vacía, como estaba).
- "Trazar ruta": abrió el mapa libre en "PLANEANDO RUTA"; atrás volvió al inicio sin guardar nada. **OK**.
- El texto vacío de la Bitácora decía "Abre el mapa de una expedición…": cambiado a "Toca «Grabar · Desde aquí»…".
- Pruebas automáticas: 137 en verde (1 nueva: recorrido libre se guarda, se lee y no se borra con una expedición).
- Nota: el detalle de un recorrido de 1 min sin moverse dice "0 h 00 · TIEMPO TOTAL" (el diálogo decía 0:01:01); ya
  pasaba antes, no se tocó.

**Revisión de diseño y mapa libre · `fix/mapa-libre`** (S23, Wi-Fi, ubicación encendida por el usuario)
- Revisión (skill design-critique) con capturas de inicio, mapa libre, expedición, SOS y Mapas; hallazgos en
  `pendientes.md`. Con la ubicación apagada, "Mi ubicación" solo daba un aviso sin acción y el SOS solo "Reintentar".
- Nombres: antes, en la Ciudad de México a z15 no salía ninguna calle ni colonia. Después: calles ("Calle Río Lerma",
  "Avenida Paseo de la Reforma"), colonias ("COLONIA CUAUHTÉMOC", "ZONA ROSA") y a z6.5 estados ("HIDALGO", "MORELOS",
  "PUEBLA", "TLAXCALA"). **OK**.
- **Falla mía:** el primer APK abrió el mapa en blanco: la capa de límites tenía dos `interpolate` de zoom dentro de un
  `match` (log: `Mapa: layers[19].paint.line-width: Only one zoom-based...`). Corregido; el mapa volvió a cargar.
- "Mi ubicación", medido con `cameraInfo()` (vista 411 × 882, margen arriba 110):
  - Primer intento en 3D: centro = tus coordenadas, pero tu punto en y = 1373 (fuera de la pantalla). Causa: altura de
    la cámara del sitio anterior. Con la corrección en `idle`: en pantalla.
  - Segundo intento: punto en y = 441 = mitad de toda la vista; `getPadding()` = 0. Causa: animaciones en 0 →
    `flyTo` se volvía `jumpTo` sin padding. Con `essential: true`: y = 371, esperado (110 + 882 − 249) / 2 = 371. **OK**.
  - Mover el mapa con el dedo (punto en y = 614) y volver a tocar: y = 371. **OK** (antes no hacía nada).
  - Panel al mínimo: margen 144, punto en y = 424 = esperado; en 2D igual. **OK**.
- Ubicación apagada (con `settings put secure location_mode 0`, luego devuelta a 3): en el SOS sale "La ubicación del
  teléfono está apagada." con "Activar", que abrió los ajustes de ubicación; al volver con la ubicación encendida dijo
  "Buscando GPS…" sin otro toque. En el mapa, el aviso trae "Abrir ajustes". **OK**.
- Panel del mapa libre al 26 %: se ve casi el doble de mapa; texto de ayuda de 2 líneas.
- Pruebas automáticas: 136 en verde (1 nueva: tope de 3,000 mosaicos del topo, satélite sin tope, zona normal cabe).
- Sin probar en el teléfono: el aviso del selector de zona al pasar el tope (cubierto por la prueba automática).

## 2026-10-28

**Experimento: senderos de los mosaicos en Dart · `spike/senderos-dart`**
- Lectura: los mosaicos topo se guardan sin comprimir; el decodificador de `mvt.dart` lee 193 mosaicos del paquete
  del Izta en 65 ms (0.3 ms cada uno) y 417 del teléfono en 83 ms. Senderos (`path`, `track`) solo desde zoom 13.
- Izta, zoom 14 (72 mosaicos): 691 líneas, 530 km (317 `path` + 213 `track`). Los 469 puntos de La Arista del Sol
  caen a ≤ 1 m de un sendero leído: la conversión de coordenadas es correcta.
- Grafo (18 mil nodos) y búsqueda por distancia (~8 ms), inicio→final de La Arista:
  - Sin recortar mosaicos: 14.4–15.7 km (ruta real 12.1) y hasta 145 piezas sueltas. Recortar cada línea al mosaico
    fue necesario (el margen duplica los senderos con otros vértices).
  - Unir todos los nodos a ≤ R m: R = 1–2 m falla (15.7 km); R = 3 m reproduce la ruta (12.1 km, 98 % a ≤ 50 m); R ≥ 5 m
    inventa atajos (11.8 km, 37 %). Es de filo: no sirve como método.
  - Hipótesis descartada (la mía): unir solo en los bordes de mosaico no arregla nada; el desajuste está dentro de los
    mosaicos (un sendero termina a 1–3 m del otro sin compartir vértice).
  - Unir solo los **extremos sueltos** a la línea más cercana (3–30 m): resultado estable, 11.8 km. Dibujado contra la
    ruta real (`/tmp/cresta-capturas/spike_ruta.png`): coincide en la mitad de abajo y en la de arriba usa **otro sendero
    real** (valle del oeste, 0.3 km más corto) en vez de la arista del este. La más corta no es la mejor.
- Zoom 13 (descarga Básica): 154 líneas, 41 km (contra 561 km a zoom 14 en la misma zona); el grafo queda en 108–129
  piezas y no conecta inicio y final. Para sugerir rutas hace falta Detallado.
- **Corrección:** los mosaicos de Vallecitos (210 a zoom 14, del teléfono) traen **104 km de senderos** (87 `path` y 17
  `track`) en 44 de ellos (~0.5 km por mosaico; el Izta ~7). Lo anotado en octubre ("OpenStreetMap no tiene senderos
  ahí", 15 puntos de prueba sin resultado) era demasiado fuerte: hay pocos, no ninguno.
- Tropiezos míos: un filtro de longitud invertido mezcló los mosaicos de México con los de Argentina (se rehízo).
- Pruebas automáticas (135 en verde, 10 nuevas): decodificar un mosaico real de 1.5 KB (4 senderos), tamaño de un
  mosaico z14 (~2.3 km) y esquina del mundo, y 6 casos de recorte (dentro, sale, atraviesa, fuera, sale y vuelve,
  diagonal).

**Quitar la hora límite · `feat/quitar-hora-limite`**
- En el S23: el selector ya no trae el botón de teclado (solo reloj, Cancelar y ACEPTAR). Se fijó 11:00; la "x"
  la quitó (`turnaroundMinutes` volvió a vacío en el archivo) y salió "Hora límite quitada · Deshacer"; Deshacer
  la devolvió (660 min) y otra "x" la quitó de nuevo. **OK**. El ejemplo quedó sin hora límite.
- Prueba automática (125 en verde): fijar, cambiar con otros datos, quitar y que se guarde y se lea del disco.

**Luz del día · `feat/luz-del-dia`**
- Pruebas automáticas: 10 nuevas contra valores de referencia de astral (Ciudad de México, salida del Izta,
  Londres, Ecuador, Mendoza, Nueva York, Tokio, todos a ≤ 2.5 min), día/noche polar, hora sugerida y duración.
  Pasaron a la primera.
- En el S23 (zona Buenos Aires): la tarjeta del ejemplo del Izta dijo amanecer 09:33, atardecer 21:03, 11 h 30 de
  luz, igual que la referencia (12:33:36Z y 00:02:43Z). "Usar 19:00 como hora límite" fijó 19:00 y la tarjeta
  dijo "deja 2 h 03 de luz". Con 20:30 (editado en el archivo) avisó "deja menos de 2 h… adelántala a las
  19:00". **OK**. La hora límite del ejemplo se quitó al terminar (editando `expeditions.json`).
- Nota: para una expedición en otro país las horas salen en la zona del teléfono (aquí, Argentina para el Izta).
- Fallo de prueba (mío): faltaba crear la carpeta `lib/src/sun/` antes de escribir el archivo.

**Tramos sin sendero y pendientes fuertes · `feat/tramos-sin-sendero`**
- Ruta recta de 10.6 km sobre el Popo (1 tramo sin sendero): en el mapa va punteada y repite "sin sendero"
  (visible al acercar); en el perfil los tramos muy empinados van en terracota; el detalle dice "Revisa antes
  de salir: sin sendero 10.6 km (1 tramo); muy empinado: 14 tramos de más de 40 % (5,350 m, hasta 103 %)". **OK**.
- A zoom amplio la etiqueta no se alcanza a leer (solo se ve el punteado): es lo esperado.
- Fallo de prueba (mía): el ayudante de la prueba fijaba `gain: 0` y ninguna ruta contaba con relieve.
- Pruebas automáticas: 114 en verde (6 nuevas: tramos empinados, sin sendero, filas de Comparar). Sin probar en
  el teléfono: las filas nuevas de Comparar. Se borró la ruta de prueba.

**Rutas B, C y D · `feat/rutas-b-mapa-libre`, `feat/rutas-c-clima-mapa`, `feat/rutas-d-comparar`**
- B: en el mapa libre se trazó una ruta (2 puntos, 10.6 km, +2,142 m), "Guardar ruta" pidió nombre y destino
  (solo la ruta / nueva expedición / expediciones) y quedó suelta en `routes.json`; salió en "Rutas
  guardadas" del inicio. En su detalle: "Ruta suelta, sin expedición". "Guardar en una expedición" la pasó al
  ejemplo (el archivo y la pantalla de la expedición lo confirmaron y salió de las guardadas). **OK**.
- C: en el detalle de ruta, "Preparar sin conexión": el mapa del Izta salió "descargado" (zona incluida cubre la
  ruta); "Consultar clima" guardó el clima con 2 puntos (3,512 m: 3°/13° llovizna; 5,236 m: −8°/2° nieve) en
  `weather.json` con clave `route:<id>`. Una ruta de 6.6 km fuera de las zonas dijo "3.1 MB (110 mosaicos)";
  "Consultar clima y descargar mapa" guardó el clima y descargó la zona (5.1 MB, 31 % → completa), después
  "Mapa descargado… funciona sin señal". Borrar la ruta quitó su clima. **OK**.
- D: con 2 rutas guardadas el inicio muestra "Comparar"; la tabla destacó en cian lo mejor de cada fila, los
  perfiles se superpusieron y "Ver en el mapa" dibujó las dos líneas con su leyenda. **OK**.
- Fallos: (1) las dos rutas se llamaban igual en los chips → nombre con hora y km en el chip. (2) en el mapa de
  comparar el botón 2D/3D quedó desincronizado y sobraba el de grabar → `setState` y ocultarlo. (3) un menú
  emergente (con "Borrar expedición") quedó abierto por un atajo de prueba que no encontró el botón; se cerró sin
  elegir nada y las expediciones siguieron intactas.
- Limpieza: se borraron las rutas y las zonas de prueba (la de 5.1 MB desde Mapas); el teléfono quedó con 0 rutas,
  2 zonas (16 MB) y las 2 expediciones. La caché de navegación (42 MB) creció al navegar; no se borró.
- Pruebas automáticas: 108 en verde (5 de zona de ruta, 5 de comparar). Sin probar en el teléfono: importar GPX
  como ruta adicional, "Nueva expedición" desde el destino de la ruta y comparar desde el detalle o la expedición.

**Rutas como entidades propias · `feat/rutas-propias`**
- Migración en el teléfono: con la versión anterior se guardó la ruta del ejemplo del Izta (formato
  antiguo, 469 puntos, 52,129 bytes); se instaló la nueva: apareció `routes.json.v1.bak` idéntico al
  original, `routes.json` en formato 2 con 1 ruta (id `r-sample-arista-del-sol`) y contenido idéntico salvo
  id y expedición. La expedición muestra su ruta y el detalle da lo mismo (12.1 km, +1,633 m, 60 %). **OK**.
- Editar y guardar con el planificador deja 1 ruta con el mismo id (no se duplica). **OK**.
- Borrar la ruta desde el detalle: 0 rutas y la expedición vuelve a "Ruta de ejemplo cargada". **OK**.
  Se borró el respaldo de prueba al terminar.
- Pruebas automáticas (98 en verde): migración con respaldo y sin repetir, ruta ilegible, varias rutas por
  expedición, rutas sueltas, reemplazar, editar sin duplicar y borrar. Sin probar en el teléfono: importar
  GPX (usa `replaceOf`) y borrar una expedición con ruta (usa `deleteOf`), solo por pruebas automáticas.

**Mejoras · `fix/sms-sangre`, `fix/perfil-sin-guardar`, `feat/notificacion-hora-limite`, `feat/mapa-libre`**
- Aviso al salir del perfil: sin cambios sale directo; con cambios pregunta "¿Salir sin guardar?";
  "Cancelar" se queda y "Salir" descarta (el nombre escrito no se guardó). **OK**. Ojo: el primer "atrás"
  solo cierra el teclado.
- Notificación de hora límite 21:05, grabando con la pantalla **bloqueada**: el aviso previo salió a las
  20:35:00 ("Hora límite en 30 min"). **OK**. La grabación siguió corriendo bloqueada.
- Hora límite 20:55 con la pantalla encendida: "Es tu hora límite de regreso · Son las 20:55…" salió a las
  20:55:00. **OK**. Al descartar el recorrido desaparecen las notificaciones (la barra del teléfono no
  muestra nada de Cresta). `dumpsys notification` seguía listándolas minutos después: no fiarse de él.
- Fallo (conexión): al bloquear la pantalla con el botón de encendido adb quedó "offline" y hubo que
  reconectar con otro puerto; el teléfono siguió grabando.
- Fallo (selector de hora): el modo teclado muestra una pantalla roja ("non-normalized height"); anotado.
- Fallo (Samsung): Mensajes de Samsung ofrece cambiar la app predeterminada y transferir el historial al
  abrir el SMS; no se aceptó. El selector "Abrir con" cambia de orden: usar "Solo una vez".
- Texto del SOS con la sangre en palabras: prueba automática ("O positivo"); en el teléfono la vista previa
  de "Compartir" corta el texto antes de ese tramo. Falta verlo en un SMS real con Mensajes de Samsung.
- Mapa libre: la tarjeta "Explorar mapa" abre el mapa (título "EXPLORAR · Mapa libre", encuadra el Izta);
  grabar y planear ruta muestran "Necesitas una expedición"; "Nueva expedición" crea la expedición y
  reemplaza el mapa (atrás vuelve al inicio). **OK**. La expedición de prueba se borró.
- Limpieza: la interfaz no permite quitar una hora límite; se quitó de la expedición de ejemplo editando
  `expeditions.json` con `run-as`. Se descartó el recorrido de prueba.
- Pruebas automáticas: 95 en verde (4 de `TurnaroundAlerts`, 1 de sangre con palabras).

**SOS con la ubicación encendida · `main`**
- Pantalla SOS con GPS fijo (±16 m): coordenadas decimales, grados-minutos-segundos y UTM coherentes
  entre sí (revisado a mano), altitud 738 m, precisión y "hace N s" que se actualiza. **OK**.
- Sin contactos en el perfil: sale el aviso "No tienes contactos de emergencia" y no hay botón de SMS. **OK**.
- "Compartir": la vista previa dice "SOS. Necesito ayuda. Ubicación: lat, lon, altitud (±precisión) a las
  HH:MM. https://maps.google.com…". Se cerró sin enviar. **OK**.
- No se pulsó "Llamar al 911".

**SOS, SMS a un contacto · `main` (28 oct 2026)**
- Contacto de prueba agregado en el perfil y botón "SMS con tu ubicación a …" en el SOS: **OK**. Se envió
  el SMS (el usuario confirmó que avisaría al destinatario); llegó como mensaje RCS en Mensajes de Google
  con el texto completo. El contacto se quitó después.
- Fallo: la primera vez el SMS se abrió en Mensajes de Samsung y el tipo de sangre salió como "Sangre B ."
  (sin el "+"). En Mensajes de Google sale "Sangre B+." bien. Sin corregir (ver `pendientes.md`).
- Fallo de uso: en el perfil, el contacto agregado **no se guarda** si se sale sin pulsar "Guardar"
  (no avisa); el SOS seguía sin contactos. Con "Guardar": **OK**.
- Nota: el selector "Abrir con" del SMS cambia de orden entre veces; con "Solo una vez" no deja
  aplicación predeterminada. Mensajes de Samsung ofrece cambiar la app predeterminada: no aceptarlo.

**Correcciones · `fix/ejemplo-pendiente-nieve`**
- Diagnóstico en el S23: `regions.json` sin la zona `sample-izta-popo`, el ejemplo con `regionIds: []` y
  solo los 622 mosaicos de Vallecitos en disco (los 422 del paquete se habían borrado con `prune()`).
- Tras instalar: el ejemplo dice "Lista sin conexión · 9.4 MB"; en Mapas, 2 zonas (16 MB), la del Izta
  "Incluida en la app" y sin botón de borrar. **OK** (verificado con `uiautomator dump`, sin capturas).
- La ruta de ejemplo (altitudes del paquete) da 60 % en 100 m y 57 % en 300 m a 4,780–5,000 m:
  terreno real. La corrección (interpolación bilineal) se probó con una prueba automática de rampa.
- En el teléfono (28 oct 2026): se guardó la ruta de ejemplo del Izta desde el planificador (12.1 km,
  +1,633 m, 7 h 07) y su detalle da **60 % de pendiente máx.** (antes 74 %), subida 1,633 m, bajada 94 m.
  **OK**. Luego se borró la ruta y la expedición volvió a "Ruta de ejemplo cargada" con sus mapas.
  Nota: el detalle de ruta solo se abre con una ruta **guardada**; la de ejemplo no tiene esa tarjeta.
- Nieve con umbral de 1 mm y reparación del ejemplo: pruebas automáticas. **OK** (90 en verde).
- graphify: etiquetado con Gemini fallaba (faltaba `openai`); instalado y 94 grupos nombrados. **OK**.

## 2026-10-27

**graphify · `chore/graphify` `4f05a32`**
- Primer grafo (`extract --code-only`): 99 archivos de código, 1,882 nodos, 2,575 relaciones, 92 grupos;
  nodos centrales `JsonStore`, `TrailRoute`, `Expedition`, `TileStore`. **OK**.
- `tool/dev/graphify.sh god-nodes` desde Windows (Git Bash → WSL): **OK**.
- Commit real con los hooks: reconstrucción en segundo plano de 11 archivos cambiados (1,910 nodos,
  87 grupos) y el etiquetado se lanzó y se saltó por falta de clave ("GEMINI_API_KEY vacía"). **OK**.
- Falta: etiquetar con Gemini (cuando el usuario ponga la clave).

**Fase 4c, referencias · `feat/preparacion` `12fdddc`**
- Agregar y quitar un enlace en la expedición de ejemplo: **OK**. Archivos (foto, PDF) no probados.

**Fase 4b, equipo · `5890e4e`**
- Plantilla "Alta montaña, un día" (24 objetos, 11.8 kg), marcar empacados (2/24, 0.8 kg), editar
  un objeto, vaciar la lista: **OK** (en la expedición de ejemplo, dejada vacía).
- Toques de prueba en el nombre abren el editor (correcto); las casillas están a la izquierda (x≈77).

**Fase 4a, clima · `9e34e1f`**
- Vallecitos (sin ruta → centro de la zona, 4,318 m por relieve): −12°/−6°, nevada fuerte, ráfagas
  69 km/h, congelación a 3,410 m: **OK**, datos reales de Open-Meteo.
- Izta (ruta de ejemplo): salida 3,680 m "Chubascos" vs punto más alto 5,207 m: el modelo decía
  chubascos (lluvia) en ambos → se agregó `snowAdjusted`: ahora dice "Chubascos de nieve" arriba. **OK**.
- Fallo: el ícono de las 00:00 era un sol → se usa luna de noche (según amanecer/atardecer). **OK**.
- Fallo: la expedición de ejemplo no podía consultar clima (su ruta viene en la app) → se carga la
  ruta incluida. **OK**.
- Dato: la API no ajusta la nieve a la altitud pedida (0 cm a 5,100 m con −6 °C y 8.8 mm).

**SOS · `feat/perfil-sos` `f54c534`**
- Pantalla SOS con la **ubicación del teléfono apagada**: muestra el aviso; se agregó "Reintentar". **OK**.
- Perfil y formulario de contacto se ven bien; no se guardaron datos del usuario.
- No se tocó "Llamar al 911".

**Fase 3, planificador · `feat/planificador-rutas` `d1e6c1b` → `abe6e0f`**
- `snapLeg` por consola de depuración (CDP) en 15 puntos de Vallecitos: **siempre null** en 2–9 ms →
  OpenStreetMap no tiene senderos ahí. En el Izta: caminos de 142 y 75 puntos en ~30 ms. **OK**.
- Flujo con toques: 2 puntos en el Izta → 6.2 km con rodeo por el valle. **Fallo**: cruces de senderos
  desconectados en los mosaicos → se unen extremos a < 20 m → 5.0 km. **OK**.
- Fallo: al guardar, pantalla roja `_dependents.isEmpty` → causa: `TextEditingController` liberado
  mientras el diálogo se cerraba → `askText` con estado propio. **OK** (también en renombrar recorrido).
- Fallo: el selector de tipo de punto se desbordaba 21 px → `isScrollControlled` + scroll. **OK**.
- Fallo: el panel no bajaba al elegir un punto de interés → `_moveSheet` tras el cuadro. **OK**.
- Detalle de ruta, renombrar y borrar: **OK**. Pendiente máx. de 74 % parece alta (posible ruido del
  relieve de 30 m).

## 2026-10-26

**Splash · `feat/rediseno-ui` `dc7008e` → `88c5695`**
- Fallo: el splash de Flutter ocupaba 2/3 del ancho → `AnimatedSwitcher` con `StackFit.expand`. **OK**.
- Fallo: el usuario veía el logo de Flutter → splash de Android 12+ configurado (también `values-night-v31`). **OK**.
- Fallo: costuras en la textura en mosaico → una sola imagen `BoxFit.cover`. **OK**.
- Fallo: con teclado abierto se encimaba "BY FRUTAL" → `resizeToAvoidBottomInset: false`. **OK**.
- Arranque en frío: la montaña de Android y la de Flutter coinciden en tamaño y lugar. **OK**. Duración ≥ 2 s.

**Pestañas, bitácora, resumen · `8f62768`**
- Las 4 pestañas en el teléfono: **OK**. Bitácora y Resumen vacíos (sin recorridos terminados).
- Fallo: al cerrar y abrir la app no había barra inferior → se abría el APK viejo (la recarga en
  caliente no cambia lo instalado) → reinstalar. **OK**.

**Ícono · `8ed84eb`**: el usuario lo aprobó.

## 2026-10-25

**Rediseño UI · `c321647`, `acfb45f`**
- Fallo: el panel del mapa dejaba ver etiquetas del mapa → panel opaco. **OK**.
- Fallo: botón "Agregar zona" en dorado sucio → botones tonales en pizarra. **OK**.

**Grabación · `feat/grabar-recorrido` `0f9de30`**
- Usuario grabó dentro de casa: el reloj no avanzó. Causa: el reloj era "tiempo en movimiento" y las
  lecturas peores que ±50 m se descartan → reloj de tiempo total + aviso de GPS. Corregido; **falta
  probar al aire libre**.
- Fallo: no se pedía el permiso de notificaciones (Android 13+) → canal `cresta/permissions`. Corregido.
- Permiso de ubicación: se pide al tocar "Mi ubicación" o "Grabar" (correcto, por diseño).
- Descarga de una zona (Vallecitos, 6.8 MB) con Wi-Fi: **OK** (la hizo el usuario).

**Entorno**: Flutter 3.47.8 instalado en WSL; `flutter analyze` limpio y 46 pruebas en verde en la
rama `feat/grabar-recorrido` antes de cualquier cambio. Primera ejecución en Android: arranca sin errores.

## Antes de octubre 2026 (otra computadora)

- iOS en el simulador de iPhone 16 Pro, con caminatas simuladas (`xcrun simctl location ...`).
- Descargas reales: Nevado de Toluca (71 mosaicos) y Aconcagua.
