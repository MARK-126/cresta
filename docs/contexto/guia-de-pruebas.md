# Guía de pruebas para el usuario

Qué se construyó en la sesión del **12 nov 2026** y qué falta que el usuario pruebe en el teléfono o en el terreno.
Cada prueba dice cómo hacerla y qué debería pasar. Al probar algo, anotar el resultado en `pruebas.md` (también si
falla) y quitarlo de aquí y de "Sin probar todavía".

## Lo que se hizo el 12 nov 2026

Todo está en `main`, salvo la búsqueda sin señal (rama `feat/buscar-lugares`, falta probarla en el teléfono y
juntarla).

| # | Qué | Dónde se usa |
|---|-----|--------------|
| 1 | **Revisión de diseño** de la app (crítica con la skill design-critique) y sus correcciones | Toda la app |
| 2 | **Botón de centrar** del mapa libre: centra en cada toque, también con el panel abierto | Mapa, botón de ubicación |
| 3 | **Nombres en el mapa**: calles, colonias, parajes, estados, países y límites, según el zoom | Mapa, capa "Nombres" |
| 4 | **Mapas viejos**: aviso cuando una zona tiene más de 3 meses y botón para actualizarla con Wi-Fi | Pestaña Mapas |
| 5 | **Inicio nuevo** "¿Qué quieres hacer?": Grabar desde aquí, Mapa libre, De A a B, Expedición | Inicio |
| 6 | **Grabar sin expedición** ("recorrido libre") | Inicio → Grabar |
| 7 | **Rutas de A a B** por senderos (la más rápida a pie, contando subidas) y, sin sendero, a campo traviesa por la pendiente más suave | Inicio → De A a B |
| 8 | **Capas de pendiente y zonas planas** del relieve | Mapa → capas |
| 9 | **Volver por mi traza**: guía de regreso al punto de salida, con rumbo y distancia | Panel de grabación |
| 10 | **Hora de llegada en vivo**, contra la hora límite y el atardecer | Panel de grabación |
| 11 | **Batería**: pedir que Android no detenga la app al grabar, y consejos | Al empezar a grabar |
| 12 | **Avisos de puntos de interés** (agua, refugio, punto de no retorno…) y "Próximo:" en el panel | Al grabar con una ruta con puntos |
| 13 | **Pasar un recorrido libre a una expedición** (o cambiarlo, o dejarlo libre otra vez) | Bitácora → recorrido → menú ⋮ |
| 14 | **Buscar sin señal**: cumbres, refugios, agua, pueblos y senderos de los mapas descargados | Mapa → lupa (rama `feat/buscar-lugares`) |

Descartado a pedido del usuario: franja de riesgo de avalanchas (casi no aplica en Argentina) y descargas más
grandes que el límite de OpenFreeMap (no vale la pena por ahora).

## Correcciones de la salida del 12 nov 2026 (rama `feat/gps-grabacion`)

Lo que se corrigió a partir de tus observaciones en el Parque San Martín, y cómo probarlo:

- **Grabar con la pantalla bloqueada** (antes salían líneas rectas): graba caminando 10 minutos con la pantalla
  bloqueada. La traza debe seguir tu camino, sin tramos rectos. Debe verse la notificación fija "Cresta está grabando".
- **Ya no pide encender el Wi-Fi** al ubicarte ni al grabar.
- **Si el GPS falla**, el panel lo dice en rojo y vuelve a intentarlo solo.
- **Tu posición en vivo**: al abrir el mapa libre te centra solo; el botón de ubicación te sigue mientras caminas
  hasta que muevas el mapa con el dedo.
- **Recorrido sin puntos**: lo explica y no deja abrir mapa, video ni GPX vacíos (tu "Recorrido 1" es así: puedes
  borrarlo desde su menú).
- **Inicio y fin** marcados en la traza; **ruta en teal** y recorrido en coral.
- **Indicaciones la primera vez** que abres el mapa, trazas una ruta o grabas (se vuelven a ver desde el perfil).
- **Escribir lugares al trazar una ruta**: campo "¿Desde dónde sales?" / "Agregar parada o destino por nombre".
  "Tu ubicación", tus mapas y, con conexión, todo el mundo (confirma con Enter).
- **Íconos de lugares** (agua, refugio, camping, comida, baños, salud…) y nombres legibles sobre el satélite.
- **Video del recorrido en 3D** (rehecho el 13 nov 2026): en el detalle del recorrido, "Video del recorrido en 3D".
  Primero dice "Preparando el video…" y luego "Generando el video… N %"; al terminar se abre compartir. Debe verse
  fluido, sin parpadeos ni cuadros en blanco, con carteles INICIO y FIN. Probar con un recorrido en la montaña (zona
  descargada) y en una zona que nunca se vio (los mosaicos bajan de internet: tarda más en generarse, pero debe salir
  igual de fluido).

## En casa (con el teléfono conectado a la computadora)

Para estas basta con que el teléfono esté en la misma red Wi-Fi con **depuración inalámbrica** activa: pasarle a
Claude el puerto nuevo (Ajustes → Opciones de desarrollador → Depuración inalámbrica). El puerto cambia cada vez que
se reconecta.

### Buscar sin señal (rama `feat/buscar-lugares`)

1. Abrir **Mapa libre** y tocar la **lupa** (arriba a la derecha).
   - Debe abrir "Buscar en tus mapas". La primera vez dice "Preparando la búsqueda…" unos segundos; las siguientes,
     no.
2. Sin escribir nada: debe listar "CERCA DE TI" (o "CERCA DEL CENTRO DEL MAPA" sin ubicación) con cumbres, refugios,
   agua y campamentos, cada uno con distancia y dirección ("7.7 km al NO").
3. Escribir **arenales**: debe salir "Cerro Arenales · Cumbre · 3,460 m".
   Probar también **refugio**, **agua**, **adolfo** y uno sin acento (**shangrila**).
4. Tocar un resultado: el mapa vuela hasta ahí, lo marca en dorado con su nombre y arriba aparece una tarjeta
   (nombre, tipo, altura, distancia). Tocar la tarjeta vuelve a centrar en el lugar; la **✕** quita la marca.
5. **Con el teléfono en modo avión**: repetir el paso 3. Debe funcionar igual.

Si falla: anotar qué búsqueda y qué salió. Si tarda mucho la primera vez, anotar cuántos segundos.

### Avisos de puntos de interés (sin salir de casa, solo lo visible)

1. Abrir una ruta guardada, **agregarle un punto de agua** y uno de **no retorno**, y guardar.
2. Grabar con esa ruta: el panel debe mostrar "Próximo: … en … m (≈ … min)".
3. En Ajustes → Apps → Cresta → Notificaciones, el canal se llamará **"Avisos del recorrido"** después del primer
   aviso (antes puede seguir diciendo "Hora límite de regreso").

## En el terreno (caminando, sin señal)

Llevar los mapas de la zona descargados y, si se puede, una ruta con puntos marcados. Al terminar, revisar la
Bitácora y el Resumen.

### Grabación al aire libre

1. Inicio → **Grabar · Desde aquí**. Si Android pregunta por la batería, tocar **Permitir**.
2. Bloquear la pantalla y caminar al menos 15 minutos.
   - Debe seguir grabando: notificación fija, reloj corriendo, distancia y desnivel que suben.
3. Al terminar: el recorrido aparece en la **Bitácora** como "RECORRIDO LIBRE" y suma en el **Resumen**.

### Hora de llegada en vivo

Con una ruta y una hora límite en la expedición: el panel dice "Llegas al final ≈ HH:MM". Hasta llevar 15 minutos
en movimiento y 500 m dice "según la regla de Naismith"; después, "a tu ritmo". Si vas tarde, avisa que llegarías después de la
hora límite.

### Avisos de puntos de interés

Caminando hacia un punto de la ruta:
- Agua, campamento, refugio o cumbre: **notificación a 150 m**, por ejemplo "A 150 m del agua. Buen momento para
  rellenar."
- Punto de no retorno o peligro: **notificación a 300 m**, por ejemplo "A 300 m del punto de no retorno. Decide ahí si
  sigues…".
- Cada punto avisa **una sola vez** por recorrido.

### Volver por mi traza

1. Grabar unos cientos de metros.
2. Tocar **"Volver al inicio por mi traza"**.
   - El panel cambia a "REGRESANDO", dice cuánto falta por tu traza y "El inicio está a … m en línea recta, rumbo …°
     (…)".
3. Salirse más de 80 m de la traza: debe avisar que te saliste.
4. **"Dejar de guiar el regreso"** vuelve a la ruta planeada (si había).

### Pasar el recorrido a una expedición

Con el recorrido real de la salida: Bitácora → abrirlo → menú **⋮** → **"Pasar a una expedición"** → elegir una o
**"Nueva expedición"** (sale con el nombre y el día del recorrido). Arriba debe decir "RECORRIDO · NOMBRE" y aparecer
en "Recorridos grabados" de la expedición. Se puede deshacer con "Cambiar de expedición" → "Recorrido libre".

## Otras pruebas pendientes (de antes)

- Importar un GPX/KML real desde el teléfono.
- Adjuntar una foto o un PDF como referencia y abrirlo.
- Exportar GPX (ruta) a otra app.
- Descargar mapas con datos móviles (opción "solo Wi-Fi" apagada).
- Al sol: si las etiquetas pequeñas (10–11 px) se leen bien.
