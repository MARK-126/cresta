import 'package:flutter/material.dart';

enum AppMode { mountain, civil }

enum LayerGroup { mountain, civil, general }

/// Una capa que el usuario puede encender o apagar. El `id` coincide con `assets/web/map.js`.
class MapLayer {
  const MapLayer(this.id, this.group, this.name, this.color, {this.note});

  final String id;
  final LayerGroup group;
  final String name;
  final String? note;
  final Color color;
}

const mapLayers = <MapLayer>[
  MapLayer('route', LayerGroup.mountain, 'Ruta seleccionada', Color(0xFFD0245A), note: 'La Arista del Sol'),
  MapLayer('trails', LayerGroup.mountain, 'Senderos', Color(0xFFFFD23F), note: 'OpenStreetMap'),
  MapLayer('contours', LayerGroup.mountain, 'Curvas de nivel', Color(0xFFD9C79A), note: 'cada 100 m, maestras cada 500 m'),
  MapLayer('peaks', LayerGroup.mountain, 'Cumbres y refugios', Color(0xFFFFFFFF)),
  MapLayer('members', LayerGroup.mountain, 'Mi grupo', Color(0xFF1F7AE0), note: 'ubicación en vivo'),
  MapLayer('zones', LayerGroup.civil, 'Zonas de peligro volcánico', Color(0xFFF28B1B), note: 'ilustrativas, no oficiales'),
  MapLayer('ash', LayerGroup.civil, 'Dispersión de ceniza', Color(0xFF6D7378), note: 'pronóstico de ejemplo'),
  MapLayer('evac', LayerGroup.civil, 'Rutas de evacuación', Color(0xFF22C06A), note: 'esquemáticas'),
  MapLayer('shelters', LayerGroup.civil, 'Albergues', Color(0xFF1B7F4B)),
  MapLayer('reports', LayerGroup.civil, 'Reportes ciudadanos', Color(0xFFB03FD6)),
  MapLayer('hillshade', LayerGroup.general, 'Sombreado del relieve', Color(0xFF2B3A40)),
];

/// Capas encendidas al entrar a cada modo.
Map<String, bool> layerPreset(AppMode mode) {
  final on = switch (mode) {
    AppMode.mountain => {'route', 'trails', 'contours', 'peaks', 'members'},
    AppMode.civil => {'peaks', 'zones', 'ash', 'evac', 'shelters', 'reports'},
  };
  return {for (final l in mapLayers) l.id: on.contains(l.id)};
}
