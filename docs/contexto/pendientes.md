# Pendientes

Lo que falta **probar** está al inicio de `pruebas.md`. La lista de funciones por hacer y deseables está en
`funcionalidades.md`. Aquí van los pendientes técnicos y lo que conviene revisar.

## Prioridad

1. **Prueba de grabación al aire libre** (la hace el usuario): pantalla bloqueada, notificación fija,
   reloj, bitácora y resumen con datos reales.
2. Probar el **SOS con la ubicación encendida** y el SMS a un contacto.

## Técnicos

- "Pendiente máxima" de una ruta dio 74 %: revisar si es ruido del relieve de 30 m y suavizar.
- La expedición de ejemplo dice "Sin mapas descargados" aunque sus mapas vienen en la app.
- En la lista de recorridos, nombres antiguos pueden repetir la fecha.
- `snowLikely` marca nieve con muy poca precipitación (≥ 0.1 mm en una hora): quizá subir el umbral.
- El ajuste a senderos solo usa lo visible y solo distancia (no desnivel).
- Descargas de mapas: solo con la app abierta.

## Herramientas

- **graphify** (skill de grafo de conocimiento del código): en evaluación. Ver la conversación del
  27 oct 2026: el README no lista Dart entre sus lenguajes.
