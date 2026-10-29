import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Un elemento de una capa de un mosaico vectorial (formato Mapbox Vector Tile, sin comprimir).
class MvtFeature {
  MvtFeature(this.type, this.props, this.parts);

  /// 1 punto, 2 línea, 3 polígono.
  final int type;
  final Map<String, Object?> props;

  /// Líneas (o anillos) con coordenadas enteras del mosaico, de 0 a `extent`.
  final List<List<(int, int)>> parts;
}

class MvtLayer {
  MvtLayer(this.name, this.extent, this.features);
  final String name;
  final int extent;
  final List<MvtFeature> features;
}

/// Decodifica un mosaico vectorial y devuelve sus capas. Solo lo necesario para leer senderos.
List<MvtLayer> decodeMvt(Uint8List bytes) {
  final r = _Reader(bytes);
  final layers = <MvtLayer>[];
  while (r.more) {
    final tag = r.varint();
    if (tag >> 3 == 3 && tag & 7 == 2) {
      final len = r.varint();
      layers.add(_layer(_Reader(bytes, r.pos, r.pos + len)));
      r.pos += len;
    } else {
      r.skip(tag & 7);
    }
  }
  return layers;
}

MvtLayer _layer(_Reader r) {
  var name = '';
  var extent = 4096;
  final keys = <String>[];
  final values = <Object?>[];
  final rawFeatures = <_Reader>[];
  while (r.more) {
    final tag = r.varint();
    final field = tag >> 3, wire = tag & 7;
    if (wire == 2) {
      final len = r.varint();
      final sub = _Reader(r.b, r.pos, r.pos + len);
      r.pos += len;
      switch (field) {
        case 1:
          name = utf8.decode(r.b.sublist(sub.pos, sub.end));
        case 2:
          rawFeatures.add(sub);
        case 3:
          keys.add(utf8.decode(r.b.sublist(sub.pos, sub.end)));
        case 4:
          values.add(_value(sub));
      }
    } else if (wire == 0) {
      final v = r.varint();
      if (field == 5) extent = v;
    } else {
      r.skip(wire);
    }
  }
  return MvtLayer(name, extent, [
    for (final f in rawFeatures) _feature(f, keys, values),
  ]);
}

Object? _value(_Reader r) {
  Object? out;
  while (r.more) {
    final tag = r.varint();
    final field = tag >> 3, wire = tag & 7;
    switch (wire) {
      case 2:
        final len = r.varint();
        out = utf8.decode(r.b.sublist(r.pos, r.pos + len));
        r.pos += len;
      case 5:
        out = ByteData.sublistView(
          r.b,
          r.pos,
          r.pos + 4,
        ).getFloat32(0, Endian.little);
        r.pos += 4;
      case 1:
        out = ByteData.sublistView(
          r.b,
          r.pos,
          r.pos + 8,
        ).getFloat64(0, Endian.little);
        r.pos += 8;
      case 0:
        final v = r.varint();
        out = switch (field) {
          6 => (v >> 1) ^ -(v & 1), // sint
          7 => v != 0,
          _ => v,
        };
      default:
        r.skip(wire);
    }
  }
  return out;
}

MvtFeature _feature(_Reader r, List<String> keys, List<Object?> values) {
  var type = 0;
  final tags = <int>[];
  final geometry = <int>[];
  while (r.more) {
    final tag = r.varint();
    final field = tag >> 3, wire = tag & 7;
    if (wire == 2 && (field == 2 || field == 4)) {
      final len = r.varint();
      final end = r.pos + len;
      final into = field == 2 ? tags : geometry;
      while (r.pos < end) {
        into.add(r.varint());
      }
    } else if (wire == 0) {
      final v = r.varint();
      if (field == 3) type = v;
    } else {
      r.skip(wire);
    }
  }
  final props = <String, Object?>{
    for (var i = 0; i + 1 < tags.length; i += 2)
      if (tags[i] < keys.length && tags[i + 1] < values.length)
        keys[tags[i]]: values[tags[i + 1]],
  };
  return MvtFeature(type, props, _parts(geometry, closeRings: type == 3));
}

int _unzig(int v) => (v >> 1) ^ -(v & 1);

List<List<(int, int)>> _parts(List<int> g, {required bool closeRings}) {
  final out = <List<(int, int)>>[];
  var x = 0, y = 0, i = 0;
  List<(int, int)>? cur;
  while (i < g.length) {
    final cmd = g[i++];
    final id = cmd & 7, count = cmd >> 3;
    if (id == 7) {
      if (closeRings && cur != null && cur.isNotEmpty) cur.add(cur.first);
      continue;
    }
    for (var k = 0; k < count && i + 1 < g.length; k++) {
      x += _unzig(g[i++]);
      y += _unzig(g[i++]);
      if (id == 1) {
        cur = [(x, y)];
        out.add(cur);
      } else {
        cur?.add((x, y));
      }
    }
  }
  return out;
}

class _Reader {
  _Reader(this.b, [this.pos = 0, int? end]) : end = end ?? b.length;
  final Uint8List b;
  int pos;
  final int end;

  bool get more => pos < end;

  int varint() {
    var result = 0, shift = 0;
    while (true) {
      final byte = b[pos++];
      result |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
    }
  }

  void skip(int wire) {
    switch (wire) {
      case 0:
        varint();
      case 1:
        pos += 8;
      case 2:
        pos += varint();
      case 5:
        pos += 4;
      default:
        throw FormatException('tipo de campo desconocido: $wire');
    }
  }
}

/// Longitud y latitud (en grados) de un punto de un mosaico `z/x/y` (proyección Web Mercator).
(double, double) tilePointToLngLat(
  int z,
  int x,
  int y,
  num px,
  num py,
  int extent,
) {
  final n = 1 << z;
  final fx = (x + px / extent) / n;
  final fy = (y + py / extent) / n;
  final t = math.pi * (1 - 2 * fy);
  final sinh = (math.exp(t) - math.exp(-t)) / 2;
  return (fx * 360 - 180, math.atan(sinh) * 180 / math.pi);
}
