# Pendientes

Lo que falta **probar** está al inicio de `pruebas.md`. La lista de funciones por hacer y deseables está en
`funcionalidades.md`. Aquí van los pendientes técnicos y lo que conviene revisar.

## Prioridad

0. **Pruebas del usuario:** ver [`guia-de-pruebas.md`](guia-de-pruebas.md) (búsqueda sin señal en casa; grabación,
   avisos, regreso por la traza y llegada en vivo en el terreno).

1. **Prueba de grabación al aire libre** (la hace el usuario): pantalla bloqueada, notificación fija,
   reloj, bitácora y resumen con datos reales.

## Observaciones de la salida del 12 nov 2026 (Parque General San Martín, Mendoza)

Hechas en `feat/gps-grabacion` (detalle en `pruebas.md`): grabar con la pantalla bloqueada, el aviso repetido de
Wi-Fi, grabación sin puntos, ver tu posición en vivo y centrarte al abrir el mapa libre, recorrido sin puntos (no se
podía ver ni exportar; "Ver en el mapa" llevaba a la zona descargada), inicio y fin en la traza, ruta en teal.

También hechas en la misma rama: indicaciones de la primera vez, escribir salida/paradas/destino al trazar, íconos de
lugares y nombres legibles sobre el satélite, y video del recorrido en 3D.

Queda:
- **Probar caminando con la pantalla bloqueada** (la prueba en casa fue con la app en segundo plano y posiciones
  simuladas: ver `pruebas.md`).
- Video: es MP4 fragmentado (lo que da `MediaRecorder` de Chrome): el reproductor del teléfono lo abre; falta probar
  que WhatsApp e Instagram lo acepten.

## Siguiente (revisión de diseño del 12 nov 2026)


Búsqueda sin señal hecha; también de respaldo en el selector de zonas sin conexión y con "Ruta hasta aquí" desde el
lugar encontrado (13 nov 2026).

De la revisión queda: probar al sol si las etiquetas de 10–11 px se leen (el contraste ya es AAA). El botón de
"Planear ruta" del mapa usa el ícono de "Trazar ruta" del inicio; sigue sin texto (tiene ayuda al mantenerlo).

## Técnicos

- Campo traviesa: no evita agua ni zonas sin paso que el relieve no ve. Se podría castigar cruzar `water`/`waterway` de
  los mosaicos topo. Tampoco combina en un mismo tramo sendero + terreno (p. ej. salir a campo traviesa hasta un
  sendero lejano): hoy es todo sendero o todo terreno.

- Ruta por senderos: el conector del punto marcado al sendero (hasta 150 m) se marca como "con sendero"; habría que
  separar ese pedazo como tramo recto. Con zonas Básicas (sin z14) casi no hay senderos: se cae al ajuste visible.

- Pendiente/zonas planas: en el borde de cada mosaico la pendiente usa diferencias de un solo lado (no pide los
  vecinos); puede verse una costura leve. El relieve de ~30 m no ve rellanos pequeños: las "zonas planas" son
  candidatas, no garantía.

- En ciudades la capa de senderos dibuja banquetas y andadores (`path`) en rojo punteado: mucho ruido. Quizá ocultar
  `footway`/`sidewalk` o mostrar senderos urbanos solo de cerca.

- Si en una nota o nombre del SMS del SOS hay un "+", Mensajes de Samsung lo pierde (solo se corrigió el
  tipo de sangre).
- La notificación de la hora límite solo funciona grabando y en Android; la hora no se puede fijar con la
  app cerrada.
- En la lista de recorridos, nombres antiguos pueden repetir la fecha.
- Descargas de mapas: solo con la app abierta.

## Herramientas

- graphify: listo (grupos nombrados con Gemini el 28 oct 2026).
