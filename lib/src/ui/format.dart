/// Formatos numéricos de México: 5,207 m · 12.1 km.
String fmtInt(num n) {
  final s = n.round().abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

String fmtKm(double meters, {int decimals = 1}) => (meters / 1000).toStringAsFixed(decimals);

String fmtDuration(Duration d) => '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')}';

String fmtAgo(int minutes) => minutes < 60 ? 'hace $minutes min' : 'hace ${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
