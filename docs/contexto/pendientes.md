# Pendientes

Lo que falta **probar** está al inicio de `pruebas.md`. La lista de funciones por hacer y deseables está en
`funcionalidades.md`. Aquí van los pendientes técnicos y lo que conviene revisar.

## Prioridad

1. **Prueba de grabación al aire libre** (la hace el usuario): pantalla bloqueada, notificación fija,
   reloj, bitácora y resumen con datos reales.

## Técnicos

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
