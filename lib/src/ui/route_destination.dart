import 'package:flutter/material.dart';

import '../app_services.dart';
import 'expeditions_screen.dart' show askNewExpedition;
import 'theme.dart';

/// Dónde queda una ruta: sola ([expeditionId] null) o dentro de una expedición.
class RouteDestination {
  const RouteDestination(this.expeditionId);
  final String? expeditionId;
}

/// Pregunta dónde guardar la ruta: sola, en una expedición que ya existe o en una nueva.
/// Devuelve null si el usuario cancela. [current] es la expedición actual de la ruta, si la tiene.
Future<RouteDestination?> askRouteDestination(
  BuildContext context, {
  String? current,
}) => askExpeditionDestination(
  context,
  current: current,
  title: '¿Dónde guardar la ruta?',
  body: 'Sola queda en tus rutas guardadas; en una expedición se junta con su mapa, clima y equipo.',
  aloneTitle: 'Solo la ruta',
  aloneIcon: Icons.route_rounded,
);

/// Pregunta a qué expedición pasar un recorrido grabado: a una que ya existe, a una
/// nueva (con el nombre y la fecha del recorrido) o dejarlo libre.
Future<RouteDestination?> askTrackDestination(
  BuildContext context, {
  String? current,
  required String name,
  required DateTime date,
}) => askExpeditionDestination(
  context,
  current: current,
  title: '¿A qué expedición pasarlo?',
  body: 'En una expedición, el recorrido aparece con su mapa, su ruta y sus otras salidas.',
  aloneTitle: 'Recorrido libre',
  aloneIcon: Icons.fiber_manual_record_outlined,
  newName: name,
  newDate: date,
);

/// Hoja para elegir expedición: sin ninguna, una nueva o una que ya existe.
Future<RouteDestination?> askExpeditionDestination(
  BuildContext context, {
  String? current,
  required String title,
  required String body,
  required String aloneTitle,
  required IconData aloneIcon,
  String? newName,
  DateTime? newDate,
}) async {
  final services = AppScope.of(context);
  final choice = await showModalBottomSheet<(String, String?)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final items = services.expeditions.all;
      final muted = Theme.of(sheet).colorScheme.onSurfaceVariant;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(title, style: signage(sheet, size: 24)),
              const SizedBox(height: 4),
              Text(
                body,
                style: TextStyle(color: muted, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(aloneIcon),
                title: Text(aloneTitle),
                subtitle: const Text('Sin expedición'),
                selected: current == null,
                onTap: () => Navigator.pop(sheet, ('alone', null)),
              ),
              ListTile(
                leading: const Icon(Icons.add_location_alt_outlined),
                title: const Text('Nueva expedición'),
                onTap: () => Navigator.pop(sheet, ('new', null)),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('EXPEDICIONES', style: labelStyle(sheet)),
                for (final e in items)
                  ListTile(
                    leading: Icon(
                      e.id == current
                          ? Icons.check_circle_rounded
                          : Icons.landscape_outlined,
                    ),
                    title: Text(e.name),
                    selected: e.id == current,
                    onTap: () => Navigator.pop(sheet, ('exp', e.id)),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return null;
  switch (choice.$1) {
    case 'alone':
      return const RouteDestination(null);
    case 'new':
      final e = await askNewExpedition(context, name: newName, date: newDate);
      return e == null ? null : RouteDestination(e.id);
    default:
      return RouteDestination(choice.$2);
  }
}
