import 'package:flutter/material.dart';

enum AppMode { mountain, civil }

enum MapBase {
  /// El topográfico con colores oscuros (mismos datos; nada que descargar). El de inicio.
  night('Noche'),

  /// El topográfico claro.
  topo('Claro'),
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
    this.legend = const [],
  });

  final String id;
  final LayerGroup group;
  final String name;
  final String? note;
  final Color color;

  /// Solo tiene sentido si la expedición tiene ruta.
  final bool needsRoute;

  /// Colores y su significado, que se muestran con la capa encendida.
  final List<(Color, String)> legend;
}

const mapLayers = <MapLayer>[
  MapLayer(
    'route',
    LayerGroup.mountain,
    'Ruta de la expedición',
    Color(0xFFF0BF63),
    needsRoute: true,
  ),
  MapLayer(
    'track',
    LayerGroup.mountain,
    'Recorrido grabado',
    Color(0xFF46EAE5),
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
  // Calculadas en el teléfono del relieve (mismos colores que SLOPE_CLASSES de map.js)
  MapLayer(
    'slope',
    LayerGroup.mountain,
    'Pendiente del terreno',
    Color(0xFFF58C32),
    note: 'calculada del relieve (~30 m por píxel)',
    legend: [
      (Color(0xFF4CAF50), '< 10°'),
      (Color(0xFFF0C83C), '10–20°'),
      (Color(0xFFF58C32), '20–30°'),
      (Color(0xFFDC3C32), '30–40°'),
      (Color(0xFF78328C), '> 40°'),
    ],
  ),
  MapLayer(
    'flat',
    LayerGroup.mountain,
    'Zonas planas',
    Color(0xFF46EAE5),
    note: 'para acampar o descansar; revísalas en el lugar',
    legend: [(Color(0xFF46EAE5), 'menos de 5°'), (Color(0xFF2A8C89), '5–10°')],
  ),
  MapLayer(
    'labels',
    LayerGroup.mountain,
    'Nombres',
    Color(0xFF6B4A2B),
    note: 'cumbres, lugares, calles y límites',
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
    Color(0xFF00A8A3),
    note: 'contorno de los mapas sin conexión',
  ),
  MapLayer(
    'hillshade',
    LayerGroup.general,
    'Sombreado del relieve',
    Color(0xFF3D4A4F),
  ),
  MapLayer(
    'buildings3d',
    LayerGroup.general,
    'Edificios en 3D',
    Color(0xFFDDD3C5),
    note: 'de cerca; altura de OpenStreetMap',
  ),
];

/// Capas encendidas al entrar a cada modo.
Map<String, bool> layerPreset(AppMode mode) {
  final on = switch (mode) {
    AppMode.mountain => {
      'route',
      'track',
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
