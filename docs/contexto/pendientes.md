# Pendientes

Lo que falta **probar** está al inicio de `pruebas.md`. La lista de funciones por hacer y deseables está en
`funcionalidades.md`. Aquí van los pendientes técnicos y lo que conviene revisar.

## Prioridad

1. **Prueba de grabación al aire libre** (la hace el usuario): pantalla bloqueada, notificación fija,
   reloj, bitácora y resumen con datos reales.

## Siguiente (revisión de diseño del 12 nov 2026)

1. **Fase E, parte 2:** sin sendero, por el terreno con costo de Tobler y la pendiente (ya calculada en `map.js`;
   hay que llevarla a Dart o hacer la búsqueda allá). También: que la ruta por senderos pese el desnivel.
2. Actualizar mapas con Wi-Fi: guardar fecha por zona y ofrecer "Actualizar" a los ~3 meses (solo el topo).

Recorridos libres: falta poder pasarlos a una expedición desde su detalle. "Trazar ruta" hoy es el planificador
de siempre (ajuste a lo visible); la fase E lo vuelve una búsqueda completa.

Otros de la revisión: botones con borde de 1 px en la expedición ("Armar lista de equipo", "Actualizar", "Agregar zona
de mapas", "Agregar referencia") contra la regla del diseño; textos grises pequeños con poco contraste para el sol;
descargar una zona desde la pestaña Mapas; etiqueta en el botón de "Planear ruta".

## Técnicos

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
