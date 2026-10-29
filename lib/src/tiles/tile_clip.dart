/// Los mosaicos vectoriales traen un margen que se pasa de su borde, así que un mismo sendero sale
/// duplicado en dos mosaicos vecinos con vértices distintos. Recortar cada línea al cuadro
/// [0, extent] deja una sola copia, cortada justo en el borde (donde las dos mitades coinciden).
List<List<(double, double)>> clipLineToTile(List<(int, int)> line, int extent) {
  final out = <List<(double, double)>>[];
  List<(double, double)>? run;
  final e = extent.toDouble();
  for (var i = 1; i < line.length; i++) {
    final x0 = line[i - 1].$1.toDouble(), y0 = line[i - 1].$2.toDouble();
    final x1 = line[i].$1.toDouble(), y1 = line[i].$2.toDouble();
    final dx = x1 - x0, dy = y1 - y0;
    // Liang–Barsky: parte del segmento que cae dentro del cuadro
    var t0 = 0.0, t1 = 1.0;
    var visible = true;
    for (final (p, q) in [(-dx, x0), (dx, e - x0), (-dy, y0), (dy, e - y0)]) {
      if (p == 0) {
        if (q < 0) visible = false;
      } else {
        final r = q / p;
        if (p < 0) {
          if (r > t1) {
            visible = false;
          } else if (r > t0) {
            t0 = r;
          }
        } else {
          if (r < t0) {
            visible = false;
          } else if (r < t1) {
            t1 = r;
          }
        }
      }
    }
    if (!visible || t0 > t1) {
      run = null;
      continue;
    }
    // Lo que cae en el borde se deja exactamente en él (sin error de coma flotante)
    double snap(double v) => v.abs() < 1e-6
        ? 0
        : (v - e).abs() < 1e-6
        ? e
        : v;
    final a = (snap(x0 + t0 * dx), snap(y0 + t0 * dy));
    final b = (snap(x0 + t1 * dx), snap(y0 + t1 * dy));
    if (run == null || t0 > 0) {
      run = [a];
      out.add(run);
    }
    run.add(b);
    if (t1 < 1) run = null;
  }
  return out;
}
