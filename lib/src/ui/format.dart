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

String fmtKm(double meters, {int decimals = 1}) =>
    (meters / 1000).toStringAsFixed(decimals);

String fmtDuration(Duration d) =>
    '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')}';

/// Reloj con segundos para la grabación en vivo: 1:05:09.
String fmtClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

String fmtAgo(int minutes) => minutes < 60
    ? 'hace $minutes min'
    : 'hace ${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';

String fmtBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(bytes < 10 * 1024 * 1024 ? 1 : 0)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

const _days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "sáb 15 nov 2026"
String fmtDate(DateTime d) =>
    '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';

const _monthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "noviembre 2026"
String fmtMonth(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

/// "07:42"
String fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "en 21 días", "mañana", "hoy", "hace 3 días"
String fmtRelativeDay(DateTime d, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final diff = _dateOnly(d).difference(today).inDays;
  return switch (diff) {
    0 => 'hoy',
    1 => 'mañana',
    -1 => 'ayer',
    > 1 => 'en $diff días',
    _ => 'hace ${-diff} días',
  };
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
