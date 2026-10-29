import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../routes/planned_route.dart';
import '../routes/route_export.dart';
import '../routes/route_import.dart';
import '../routes/route_profile.dart';
import 'format.dart';
import 'offline_widgets.dart';

/// Importa un GPX o KML del teléfono como una ruta más de la expedición. Devuelve la ruta guardada,
/// o null si el usuario canceló o el archivo no sirve (en ese caso ya se le avisó).
Future<PlannedRoute?> importRouteFile(
  BuildContext context,
  String expeditionId,
) async {
  final services = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  // Sin filtro de tipo: Android no siempre reconoce .gpx ni .kml y los mostraría deshabilitados
  final file = await FilePicker.pickFile(dialogTitle: 'Elige un GPX o KML');
  if (file == null || !context.mounted) return null;

  final ImportedRoute imported;
  try {
    final bytes = await file.readAsBytes();
    imported = parseRouteFile(
      file.name,
      utf8.decode(bytes, allowMalformed: true),
    );
  } on RouteImportException catch (e) {
    say(e.message);
    return null;
  } catch (e) {
    say('No se pudo leer el archivo.');
    return null;
  }
  if (!context.mounted) return null;

  final baseName = file.name.replaceAll(
    RegExp(r'\.(gpx|kml)$', caseSensitive: false),
    '',
  );
  final name = imported.name ?? baseName;
  final profile = await buildProfile(
    line: imported.line,
    elevation: services.terrain.at,
    id: 'route',
    name: name,
    source: imported.origin == RouteOrigin.kml
        ? 'Importada de KML'
        : 'Importada de GPX',
  );
  final route = PlannedRoute(
    expeditionId: expeditionId,
    name: name,
    waypoints: [imported.line.first, imported.line.last],
    // El archivo ya trae el trazo bueno: un solo tramo que se respeta tal cual
    legs: [imported.line],
    snapped: const [true],
    pois: imported.pois,
    profile: profile,
    origin: imported.origin,
  );
  await services.routes.save(route);
  say(
    'Ruta importada: ${fmtKm(profile.totalMeters)} km'
    '${imported.pois.isEmpty ? '' : ' y ${imported.pois.length} puntos de interés'}.',
  );
  return route;
}

/// Comparte la ruta como GPX (Wikiloc, Garmin, Google Earth…).
Future<void> exportRouteGpx(BuildContext context, PlannedRoute route) async {
  final box = context.findRenderObject() as RenderBox?;
  final dir = await getTemporaryDirectory();
  final safe = route.name
      .replaceAll(RegExp(r'[^\w\- áéíóúñÁÉÍÓÚÑ]'), '')
      .trim();
  final file = File('${dir.path}/${safe.isEmpty ? 'ruta' : safe}.gpx');
  await file.writeAsString(routeToGpx(route));
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/gpx+xml')],
      subject: route.name,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

/// Pide el nombre de la ruta al guardarla.
Future<String?> askRouteName(BuildContext context, String initial) => askText(
  context,
  title: 'Nombre de la ruta',
  initial: initial,
  hint: 'Ej. Arista norte',
);
