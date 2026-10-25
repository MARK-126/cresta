import 'package:flutter/material.dart';

enum AppMode { mountain, civil }

enum MapBase {
  topo('Topográfico'),
  sat('Satélite'),
  relief('Relieve');

  const MapBase(this.label);
  final String label;
}

enum LayerGroup { mountain, civil, general }

/// Una capa que el usuario puede encender o apagar. El `id` coincide con `assets/web/map.js`.
class MapLayer {
  const MapLayer(
    this.id,
    this.group,
    this.name,
    this.color, {
    this.note,
    this.needsRoute = false,
  });

  final String id;
  final LayerGroup group;
  final String name;
  final String? note;
  final Color color;

  /// Solo tiene sentido si la expedición tiene ruta.
  final bool needsRoute;
}

const mapLayers = <MapLayer>[
  MapLayer(
    'route',
    LayerGroup.mountain,
    'Ruta de la expedición',
    Color(0xFFD0245A),
    needsRoute: true,
  ),
  MapLayer(
    'trails',
    LayerGroup.mountain,
    'Senderos y brechas',
    Color(0xFFC4342C),
    note: 'OpenStreetMap',
  ),
  MapLayer(
    'contours',
    LayerGroup.mountain,
    'Curvas de nivel',
    Color(0xFFA9825A),
    note: 'calculadas del relieve',
  ),
  MapLayer(
    'labels',
    LayerGroup.mountain,
    'Cumbres y lugares',
    Color(0xFF6B4A2B),
  ),
  MapLayer(
    'members',
    LayerGroup.mountain,
    'Mi grupo',
    Color(0xFF1F7AE0),
    note: 'simulado',
    needsRoute: true,
  ),
  MapLayer(
    'zones',
    LayerGroup.civil,
    'Zonas de peligro volcánico',
    Color(0xFFF28B1B),
    note: 'ilustrativas, no oficiales',
  ),
  MapLayer(
    'ash',
    LayerGroup.civil,
    'Dispersión de ceniza',
    Color(0xFF6D7378),
    note: 'pronóstico de ejemplo',
  ),
  MapLayer(
    'evac',
    LayerGroup.civil,
    'Rutas de evacuación',
    Color(0xFF22C06A),
    note: 'esquemáticas',
  ),
  MapLayer('shelters', LayerGroup.civil, 'Albergues', Color(0xFF1B7F4B)),
  MapLayer(
    'reports',
    LayerGroup.civil,
    'Reportes ciudadanos',
    Color(0xFFB03FD6),
  ),
  MapLayer(
    'regions',
    LayerGroup.general,
    'Zonas descargadas',
    Color(0xFF2E8B57),
    note: 'contorno de los mapas sin conexión',
  ),
  MapLayer(
    'hillshade',
    LayerGroup.general,
    'Sombreado del relieve',
    Color(0xFF3D4A4F),
  ),
];

/// Capas encendidas al entrar a cada modo.
Map<String, bool> layerPreset(AppMode mode) {
  final on = switch (mode) {
    AppMode.mountain => {
      'route',
      'trails',
      'contours',
      'labels',
      'members',
      'regions',
      'hillshade',
    },
    AppMode.civil => {'labels', 'zones', 'ash', 'evac', 'shelters', 'reports'},
  };
  return {for (final l in mapLayers) l.id: on.contains(l.id)};
}
