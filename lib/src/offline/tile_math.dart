import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Rectángulo geográfico en grados (oeste, sur, este, norte).
@immutable
class BBox {
  const BBox(this.west, this.south, this.east, this.north)
    : assert(west < east && south < north);

  factory BBox.fromJson(List json) => BBox(
    (json[0] as num).toDouble(),
    (json[1] as num).toDouble(),
    (json[2] as num).toDouble(),
    (json[3] as num).toDouble(),
  );

  final double west, south, east, north;

  List<double> toJson() => [west, south, east, north];

  double get centerLng => (west + east) / 2;
  double get centerLat => (south + north) / 2;

  /// Ancho y alto aproximados en km.
  double get widthKm =>
      (east - west) * 111.32 * math.cos(centerLat * math.pi / 180);
  double get heightKm => (north - south) * 110.57;

  /// Agranda la caja [km] kilómetros por cada lado.
  BBox expandKm(double km) {
    final dLat = km / 110.57;
    final dLng = km / (111.32 * math.cos(centerLat * math.pi / 180));
    return BBox(
      west - dLng,
      (south - dLat).clamp(-85, 85),
      east + dLng,
      (north + dLat).clamp(-85, 85),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BBox &&
      other.west == west &&
      other.south == south &&
      other.east == east &&
      other.north == north;

  @override
  int get hashCode => Object.hash(west, south, east, north);

  @override
  String toString() => 'BBox($west, $south, $east, $north)';
}

/// Rango de mosaicos (inclusive) de un nivel de zoom.
@immutable
class TileRange {
  const TileRange(this.z, this.minX, this.minY, this.maxX, this.maxY);

  final int z, minX, minY, maxX, maxY;

  int get count => (maxX - minX + 1) * (maxY - minY + 1);

  bool contains(int x, int y) =>
      x >= minX && x <= maxX && y >= minY && y <= maxY;

  Iterable<(int, int)> get tiles sync* {
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        yield (x, y);
      }
    }
  }
}

const _maxLat = 85.05112878;

int lngToTileX(double lng, int z) =>
    (((lng + 180) / 360) * (1 << z)).floor().clamp(0, (1 << z) - 1);

int latToTileY(double lat, int z) {
  final r = lat.clamp(-_maxLat, _maxLat) * math.pi / 180;
  final y =
      (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * (1 << z);
  return y.floor().clamp(0, (1 << z) - 1);
}

TileRange tileRange(BBox b, int z) => TileRange(
  z,
  lngToTileX(b.west, z),
  latToTileY(b.north, z),
  lngToTileX(b.east, z),
  latToTileY(b.south, z),
);

/// Cantidad de mosaicos que cubren [b] entre [minZoom] y [maxZoom].
int countTiles(BBox b, int minZoom, int maxZoom) {
  var n = 0;
  for (var z = minZoom; z <= maxZoom; z++) {
    n += tileRange(b, z).count;
  }
  return n;
}
