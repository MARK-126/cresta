# Pendientes

Lo que falta **probar** está al inicio de `pruebas.md`. La lista de funciones por hacer y deseables está en
`funcionalidades.md`. Aquí van los pendientes técnicos y lo que conviene revisar.

## Prioridad

1. **Prueba de grabación al aire libre** (la hace el usuario): pantalla bloqueada, notificación fija,
   reloj, bitácora y resumen con datos reales.

## Técnicos

- El selector de hora (hora límite) en modo teclado muestra una pantalla roja de Flutter ("BoxConstraints has
  non-normalized height"); con el reloj de esfera funciona.
- Una hora límite fijada no se puede quitar desde la interfaz.
- Si en una nota o nombre del SMS del SOS hay un "+", Mensajes de Samsung lo pierde (solo se corrigió el
  tipo de sangre).
- La notificación de la hora límite solo funciona grabando y en Android; la hora no se puede fijar con la
  app cerrada.
- En la lista de recorridos, nombres antiguos pueden repetir la fecha.
- El ajuste a senderos solo usa lo visible y solo distancia (no desnivel).
- Descargas de mapas: solo con la app abierta.

## Herramientas

- graphify: listo (grupos nombrados con Gemini el 28 oct 2026).
