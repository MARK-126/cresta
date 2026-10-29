# Registro de pruebas

Una entrada por prueba, **también las que fallaron**. Lo más reciente arriba.
Formato: fecha · rama/commit · qué · cómo · resultado · corrección.
Teléfono de pruebas: Samsung Galaxy S23 Ultra (SM-S918B), Android 16, salvo que se diga otra cosa.

## Sin probar todavía (revisar antes de dar por hecho)

- Grabación **al aire libre** con la pantalla bloqueada: reloj, notificación fija, que siga grabando,
  y que la Bitácora y el Resumen se llenen con un recorrido real.
- Importar un GPX/KML real desde el teléfono (la lectura está cubierta por pruebas automáticas).
- Adjuntar una foto o un PDF como referencia y abrirlo.
- Exportar GPX (ruta) a otra app.
- Descargas de mapas en Android con conexión móvil (opción "solo Wi-Fi").

## 2026-10-28

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
