# Funcionalidades

Lista viva para ir al día. Al terminar algo, pasarlo de "Por implementar" a "Ya funcionan".
Detalles técnicos en `estado.md`; qué se probó en `pruebas.md`.

## Ya funcionan

- Mapa 2D y 3D con relieve, curvas de nivel, satélite, topográfico y relieve sombreado.
- Pendiente del terreno por colores (cada 10°) y zonas planas (< 10°) para acampar, sin conexión.
- Descargar mapas de cualquier zona del mundo para usarlos sin señal, desde una expedición o directo en la pestaña
  Mapas; gestor de mapas descargados. Con Wi-Fi avisa si los senderos y calles de una zona tienen más de 3 meses
  y los actualiza con un toque (sin volver a bajar relieve ni satélite).
- Buscador de lugares (cumbres, parques, pueblos).
- Nombres en el mapa según el zoom: calles, caminos y senderos; colonias y parajes; pueblos; estados y países.
- "Mi ubicación" centra en cada toque, en la parte del mapa que no tapan las barras; si la ubicación está apagada, el
  aviso (mapa y SOS) lleva directo a Ajustes.
- Expediciones: nombre, fecha, notas, zonas de mapas y lista "Antes de salir".
- Hora límite de retorno con aviso dentro de la app y notificación (30 min antes y a la hora) mientras se
  graba (la notificación, solo en Android).
- Mapa libre: explorar el mapa desde el inicio sin crear una expedición.
- Trazar rutas en el mapa libre y guardarlas solas o dentro de una expedición (nueva o existente).
- Clima y mapa sin conexión por ruta ("Preparar sin conexión"), con descarga de la zona de la ruta.
- Comparar de 2 a 3 rutas: cifras lado a lado, perfiles superpuestos y mapa.
- Quitar una hora límite fijada (botón con "Deshacer"); el selector de hora es solo de reloj.
- Luz del día sin conexión: amanecer, atardecer y horas de luz de la expedición, con una hora límite sugerida
  que deja 2 h de luz para bajar.
- Avisos de seguridad de la ruta: tramos sin sendero punteados y con etiqueta, y tramos de más de 40 % de
  pendiente marcados en el perfil y avisados en el detalle.
- Inicio con cuatro acciones: grabar desde aquí, explorar el mapa, trazar una ruta y planear una expedición.
- Cuidar la batería al grabar: modo Ahorro (un punto cada 20 m), pedir que Android no detenga la app y consejos.
- Grabar recorridos sin señal, con la pantalla bloqueada, pausa y recuperación si la app se cierra; también sin
  expedición ("recorrido libre", en la Bitácora), y pasarlo después a una expedición (nueva o existente) o de
  vuelta a libre.
- Reloj de tiempo total, distancia, altitud, desnivel, velocidad vertical y aviso de GPS débil.
- Hora de llegada en vivo a tu ritmo, con aviso si llegarías después de tu hora límite o, de regreso, después del
  atardecer.
- Aviso al salirse de la ruta planeada.
- Aviso (notificación) al acercarte a un punto de interés de la ruta: agua, campamento, punto de no retorno, peligro; y
  el próximo punto con su distancia y tiempo en la tira de grabación.
- Volver al inicio por la propia traza mientras grabas: lo que falta, aviso si te sales de ella, y distancia y rumbo en
  línea recta al punto de salida.
- Exportar recorridos a GPX.
- Bitácora de todos los recorridos y resumen personal (semana, mes, altitud máxima, desnivel por semana).
- Planificar rutas tocando el mapa, ajustadas a los senderos (donde OpenStreetMap los tiene): con los mapas
  descargados busca el camino completo por senderos y calles entre dos puntos, aunque no se vea en pantalla, el más
  rápido a pie contando el desnivel. Donde no hay sendero, traza un camino a campo traviesa por la pendiente más
  suave del relieve (punteado y con aviso).
- Puntos de interés en la ruta: agua, campamento, refugio, cumbre, punto de no retorno, peligro.
- Detalle de la ruta: cifras, perfil de elevación y hora estimada de llegada a cada punto.
- Importar rutas GPX y KML; exportar rutas a GPX.
- Vuelo 3D sobre la ruta.
- Perfil de emergencia (datos médicos y contactos), solo en el teléfono.
- Pantalla SOS: coordenadas (decimal, grados y UTM), llamar a emergencias, SMS con la ubicación, compartir.
- Clima por altitud de 16 días guardado para verlo sin señal, con nieve, ráfagas y tormentas.
- Lista de equipo con plantillas, peso y empacado.
- Referencias: fotos, PDF, enlaces y teléfonos guardados con la expedición.
- Expedición de ejemplo con sus mapas incluidos, que no se pueden borrar por error.
- Modo protección civil (datos de demostración, no oficiales).
- Diseño "Andes Industrial", solo oscuro; splash e ícono propios.
- Plan de salida a un contacto: a dónde vas, la ruta (con GPX), cuándo vuelves y a qué hora avisar a emergencias si
  no das señales; por SMS a los contactos del perfil o por WhatsApp.
- Fotos durante el recorrido con su ubicación, en el mapa y en el detalle del recorrido.
- Barra de datos al grabar (altitud, velocidad y distancia arriba del mapa) y brújula al girar el mapa.
- Video del recorrido en 3D: sobrevuelo con la línea que se va dibujando, título y distancia; MP4 que se guarda en la
  galería (álbum Cresta) y se comparte. Antes se eligen fondo (Mapa, Satélite, Relieve, Noche), velocidad y capas
  (nombres de las calles cercanas, edificios 3D, senderos, curvas de nivel, título); mientras se genera se ve igual
  que el video.
- Mapa Noche (oscuro, con los colores de Cresta) y edificios en 3D. Sobre Noche y Satélite, los botones y la barra
  llevan un contorno para no confundirse con el mapa.
- Indicaciones la primera vez que se abre el mapa, se traza una ruta o se graba (se pueden volver a ver desde el
  perfil).
- Trazar rutas escribiendo la salida, las paradas y el destino (tu ubicación, tus mapas o, con conexión, todo el
  mundo).
- Íconos de lugares en el mapa (agua, refugio, camping, comida, alojamiento, salud, baños, estacionamiento…) y nombres
  legibles sobre el satélite.
- Tu posición en vivo en el mapa; el mapa libre te centra al abrirlo y el botón de ubicación te sigue.
- Buscar sin señal en los mapas descargados: cumbres (con altura), refugios, agua, campamentos, pueblos,
  senderos y ríos, con distancia y dirección desde donde estás; el lugar queda marcado en el mapa. Desde él, "Ruta
  hasta aquí" (o "Agregar a la ruta") traza el camino desde tu posición. Sin conexión, el selector de zonas para
  descargar también busca en los mapas descargados.
- Mapa a pantalla completa: abajo una barra flotante (Capas, Grabar, Ruta); al grabar o trazar, una tira compacta
  con lo esencial; con ruta, protección civil o rutas comparadas, una tarjeta de una línea. El detalle se abre en
  hojas a pedido que se cierran deslizando o tocando el mapa.

## Por implementar

De la revisión del 12 nov 2026 (detalle en `pendientes.md`):
- Distancia configurable del aviso de salida de ruta.
- Puntos de agua con fecha de comprobación.

- Ruta sugerida: buscar la mejor ruta entre los puntos marcados (más corta, más rápida, con menos desnivel),
  con el relieve y los senderos descargados, y dejarla comparable con las demás. Necesita los mosaicos de zoom 14
  (descarga Detallado) y la búsqueda en Dart (ver `decisiones.md`).
- Descargar solo un corredor alrededor de la ruta (rutas largas pesan mucho menos que la caja completa).
- Mapa base ligero del mundo, para que el mapa libre no quede en blanco sin señal (medir su peso antes).
- Notificación de la hora límite también en iPhone (falta el código nativo).
- Descargas de mapas que sigan con la app cerrada (hoy necesitan la pantalla encendida).
- Altímetro barométrico como complemento del relieve y del GPS.
- Ajuste a senderos que tome en cuenta el desnivel, no solo la distancia.

## Deseables a futuro

- Compartir la ubicación con el grupo sin señal (radios LoRa con Meshtastic).
- SMS periódico con la ubicación a contactos (solo Android; necesita algo de señal celular).
- Identificador de cumbres con la cámara (o girar el mapa 3D con la brújula y nombrar las cumbres).
- Sincronizar recorridos y expediciones entre teléfonos o con la nube.
- Versión para iPhone probada en un teléfono real.
- Reloj inteligente (Wear OS / Apple Watch) para ver datos de la grabación.
- Más plantillas de equipo (invierno, escalada en roca, trail running).
- Datos oficiales de protección civil (CENAPRED) en lugar de los de demostración.
- Si la app se vuelve comercial: cambiar el satélite (licencia no comercial) y revisar OpenFreeMap.
