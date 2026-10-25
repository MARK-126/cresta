import 'dart:convert';

import 'package:flutter/services.dart';

import 'civil_data.dart';
import 'trail_route.dart';

/// Todo lo que la app necesita al arrancar, leído de `assets/data`.
class AppData {
  AppData({required this.route, required this.civil, required this.peaks});

  final TrailRoute route;
  final CivilData civil;
  final List<Peak> peaks;

  static Future<AppData> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    Future<dynamic> json(String name) async => jsonDecode(await b.loadString('assets/data/$name'));
    final results = await Future.wait([json('arista_del_sol.json'), json('civil_demo.json'), json('peaks.json')]);
    return AppData(
      route: TrailRoute.fromJson(results[0] as Map<String, dynamic>),
      civil: CivilData.fromJson(results[1] as Map<String, dynamic>),
      peaks: [for (final p in results[2] as List) Peak.fromJson(p as Map<String, dynamic>)],
    );
  }
}
