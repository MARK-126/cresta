# Pendientes

Lo que falta **probar** está al inicio de `pruebas.md`. La lista de funciones por hacer y deseables está en
`funcionalidades.md`. Aquí van los pendientes técnicos y lo que conviene revisar.

## Prioridad

1. **Prueba de grabación al aire libre** (la hace el usuario): pantalla bloqueada, notificación fija,
   reloj, bitácora y resumen con datos reales.

## Técnicos

- El "+" del cuerpo del SMS del SOS se pierde en Mensajes de Samsung ("B+" sale "B "): revisar la
  codificación del cuerpo en `sos_screen.dart` (p. ej. escribir "positivo" en lugar de "+").
- El perfil de emergencia descarta los cambios al salir sin "Guardar", sin avisar: guardar al salir o
  preguntar.
- En la lista de recorridos, nombres antiguos pueden repetir la fecha.
- El ajuste a senderos solo usa lo visible y solo distancia (no desnivel).
- Descargas de mapas: solo con la app abierta.

## Herramientas

- graphify: listo (grupos nombrados con Gemini el 28 oct 2026).
