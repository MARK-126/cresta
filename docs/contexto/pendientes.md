# Pendientes

Lo que falta **probar** está al inicio de `pruebas.md`. La lista de funciones por hacer y deseables está en
`funcionalidades.md`. Aquí van los pendientes técnicos y lo que conviene revisar.

## Prioridad

1. **Prueba de grabación al aire libre** (la hace el usuario): pantalla bloqueada, notificación fija,
   reloj, bitácora y resumen con datos reales.

## Siguiente (revisión de diseño del 12 nov 2026)


Búsqueda sin señal hecha (falta verla en el teléfono). Ideas: usarla de respaldo en el selector de zonas cuando no
hay conexión, y "Trazar ruta hasta aquí" desde el lugar encontrado.

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
