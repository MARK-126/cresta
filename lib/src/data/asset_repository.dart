import 'dart:convert';

import 'package:flutter/services.dart';

import 'civil_data.dart';
import 'trail_route.dart';

/// Datos incluidos en `assets/data`.
class AssetData {
  const AssetData([this._bundle]);

  final AssetBundle? _bundle;

  Future<Map<String, dynamic>> _json(String key) async =>
      jsonDecode(await (_bundle ?? rootBundle).loadString(key))
          as Map<String, dynamic>;

  /// Devuelve la ruta y el JSON original (que se pasa tal cual al mapa).
  Future<(TrailRoute, Map<String, dynamic>)> route(String asset) async {
    final json = await _json(asset);
    return (TrailRoute.fromJson(json), json);
  }

  Future<(CivilData, Map<String, dynamic>)> civil() async {
    final json = await _json('assets/data/civil_demo.json');
    return (CivilData.fromJson(json), json);
  }
}
