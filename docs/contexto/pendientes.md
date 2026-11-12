# Pendientes

Lo que falta **probar** está al inicio de `pruebas.md`. La lista de funciones por hacer y deseables está en
`funcionalidades.md`. Aquí van los pendientes técnicos y lo que conviene revisar.

## Prioridad

1. **Prueba de grabación al aire libre** (la hace el usuario): pantalla bloqueada, notificación fija,
   reloj, bitácora y resumen con datos reales.

## Siguiente (revisión de diseño del 12 nov 2026)

1. **Capa de pendientes y zonas planas** calculada del relieve (franjas < 10°, 10–20, 20–30, 30–45 de avalancha, > 45).
2. **Fase E:** ruta A → B por senderos (grafo ya probado) y, sin sendero, por el terreno con costo de Tobler.
3. Actualizar mapas con Wi-Fi: guardar fecha por zona y ofrecer "Actualizar" a los ~3 meses (solo el topo).

Recorridos libres: falta poder pasarlos a una expedición desde su detalle. "Trazar ruta" hoy es el planificador
de siempre (ajuste a lo visible); la fase E lo vuelve una búsqueda completa.

Otros de la revisión: botones con borde de 1 px en la expedición ("Armar lista de equipo", "Actualizar", "Agregar zona
de mapas", "Agregar referencia") contra la regla del diseño; textos grises pequeños con poco contraste para el sol;
descargar una zona desde la pestaña Mapas; etiqueta en el botón de "Planear ruta".

## Técnicos

- En ciudades la capa de senderos dibuja banquetas y andadores (`path`) en rojo punteado: mucho ruido. Quizá ocultar
  `footway`/`sidewalk` o mostrar senderos urbanos solo de cerca.

- Si en una nota o nombre del SMS del SOS hay un "+", Mensajes de Samsung lo pierde (solo se corrigió el
  tipo de sangre).
- La notificación de la hora límite solo funciona grabando y en Android; la hora no se puede fijar con la
  app cerrada.
- En la lista de recorridos, nombres antiguos pueden repetir la fecha.
- El ajuste a senderos solo usa lo visible y solo distancia (no desnivel). La fase E lo pasa a Dart con los mosaicos
  de zoom 14 de toda la zona (base ya hecha: `lib/src/tiles/`).
- Descargas de mapas: solo con la app abierta.

## Herramientas

- graphify: listo (grupos nombrados con Gemini el 28 oct 2026).
