# Funcionalidades

Lista viva para ir al día. Al terminar algo, pasarlo de "Por implementar" a "Ya funcionan".
Detalles técnicos en `estado.md`; qué se probó en `pruebas.md`.

## Ya funcionan

- Mapa 2D y 3D con relieve, curvas de nivel, satélite, topográfico y relieve sombreado.
- Descargar mapas de cualquier zona del mundo para usarlos sin señal; gestor de mapas descargados.
- Buscador de lugares (cumbres, parques, pueblos).
- Expediciones: nombre, fecha, notas, zonas de mapas y lista "Antes de salir".
- Hora límite de retorno con aviso dentro de la app y notificación (30 min antes y a la hora) mientras se
  graba (la notificación, solo en Android).
- Mapa libre: explorar el mapa desde el inicio sin crear una expedición.
- Trazar rutas en el mapa libre y guardarlas solas o dentro de una expedición (nueva o existente).
- Clima y mapa sin conexión por ruta ("Preparar sin conexión"), con descarga de la zona de la ruta.
- Comparar de 2 a 3 rutas: cifras lado a lado, perfiles superpuestos y mapa.
- Luz del día sin conexión: amanecer, atardecer y horas de luz de la expedición, con una hora límite sugerida
  que deja 2 h de luz para bajar.
- Avisos de seguridad de la ruta: tramos sin sendero punteados y con etiqueta, y tramos de más de 40 % de
  pendiente marcados en el perfil y avisados en el detalle.
- Grabar recorridos sin señal, con la pantalla bloqueada, pausa y recuperación si la app se cierra.
- Reloj de tiempo total, distancia, altitud, desnivel, velocidad vertical y aviso de GPS débil.
- Aviso al salirse de la ruta planeada.
- Exportar recorridos a GPX.
- Bitácora de todos los recorridos y resumen personal (semana, mes, altitud máxima, desnivel por semana).
- Planificar rutas tocando el mapa, ajustadas a los senderos (donde OpenStreetMap los tiene).
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

## Por implementar

- Ruta sugerida: buscar la mejor ruta entre los puntos marcados (más corta, más rápida, con menos desnivel),
  con el relieve y los senderos descargados, y dejarla comparable con las demás.
- Descargar solo un corredor alrededor de la ruta (rutas largas pesan mucho menos que la caja completa).
- Mapa base ligero del mundo, para que el mapa libre no quede en blanco sin señal (medir su peso antes).
- Notificación de la hora límite también en iPhone (falta el código nativo).
- Poder quitar una hora límite ya fijada (hoy solo se cambia).
- Descargas de mapas que sigan con la app cerrada (hoy necesitan la pantalla encendida).
- Altímetro barométrico como complemento del relieve y del GPS.
- Brújula y rumbo de regreso al punto de salida.
- Fotos geolocalizadas durante el recorrido, visibles en el mapa.
- Ajuste a senderos que tome en cuenta el desnivel, no solo la distancia.

## Deseables a futuro

- Compartir la ubicación con el grupo sin señal (radios LoRa con Meshtastic).
- Sincronizar recorridos y expediciones entre teléfonos o con la nube.
- Mapa base oscuro, a juego con el diseño de la app.
- Versión para iPhone probada en un teléfono real.
- Reloj inteligente (Wear OS / Apple Watch) para ver datos de la grabación.
- Más plantillas de equipo (invierno, escalada en roca, trail running).
- Datos oficiales de protección civil (CENAPRED) en lugar de los de demostración.
- Si la app se vuelve comercial: cambiar el satélite (licencia no comercial) y revisar OpenFreeMap.
