import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_services.dart';
import '../data/trail_route.dart' show naismith;
import '../expeditions/expedition.dart';
import '../profile/emergency_profile.dart';
import '../profile/sos.dart' show spokenBloodType;
import '../routes/planned_route.dart';
import '../routes/route_export.dart';
import 'format.dart';
import 'offline_widgets.dart' show warnColor;
import 'theme.dart';

/// Horarios del plan de salida.
class TripTimes {
  const TripTimes(this.start, this.back, this.alarm);

  /// A qué hora sales.
  final DateTime start;

  /// A qué hora piensas estar de vuelta.
  final DateTime back;

  /// Si a esta hora no diste señales, tu contacto avisa a emergencias.
  final DateTime alarm;
}

/// Margen entre el regreso previsto y la alarma: en la montaña uno se retrasa y puede no
/// haber señal para avisar.
const alarmMargin = Duration(hours: 2);

DateTime _roundUp15(DateTime t) {
  final m = (t.minute / 15).ceil() * 15;
  return DateTime(t.year, t.month, t.day, t.hour).add(Duration(minutes: m));
}

/// Horarios sugeridos: salida a las 7:00 del día de la expedición (o en media hora si es hoy
/// o no tiene fecha), regreso según la ruta (Naismith + 30 % de descansos; sin ruta, 6 h) y
/// la alarma 2 h después del regreso.
TripTimes suggestTripTimes({
  required DateTime now,
  DateTime? day,
  PlannedRoute? route,
}) {
  final today = DateTime(now.year, now.month, now.day);
  var start = day != null && day.isAfter(today)
      ? DateTime(day.year, day.month, day.day, 7)
      : _roundUp15(now.add(const Duration(minutes: 30)));
  if (start.isBefore(now)) start = _roundUp15(now);
  final walk = route == null
      ? const Duration(hours: 6)
      : naismith(route.profile.distances.last, route.profile.gain) * 1.3;
  final back = _roundUp15(start.add(walk));
  return TripTimes(start, back, back.add(alarmMargin));
}

/// El mensaje para tu contacto: a dónde vas, por dónde, cuándo vuelves y qué hacer si no.
String tripPlanMessage({
  required EmergencyProfile profile,
  required String place,
  required TripTimes times,
  PlannedRoute? route,
  DateTime? turnaround,
}) {
  final who = profile.name.isNotEmpty ? profile.name : null;
  final b = StringBuffer(
    who == null ? 'Plan de salida a la montaña' : 'Plan de salida de $who',
  )..writeln(' (Cresta)');
  b.writeln('Voy a: $place, ${fmtDate(times.start)}.');
  b.writeln(
    'Salgo a las ${fmtTime(times.start)} y pienso volver a las ${fmtTime(times.back)}'
    '${_sameDay(times.start, times.back) ? '' : ' del ${fmtDate(times.back)}'}.',
  );
  if (route != null) {
    final r = route.profile;
    final walk = naismith(r.distances.last, r.gain);
    b.writeln(
      'Ruta: ${route.name}, ${fmtKm(r.distances.last)} km, +${fmtInt(r.gain)} m, '
      'unas ${fmtDuration(walk)} de marcha. Te mando el GPX para que la veas en un mapa.',
    );
    final s = r.coordinates.first;
    b.writeln(
      'Punto de partida: https://maps.google.com/?q=${s.lat.toStringAsFixed(5)},${s.lng.toStringAsFixed(5)}',
    );
  }
  if (turnaround != null) {
    b.writeln(
      'Hora límite para darme la vuelta: ${fmtTime(turnaround)}, aunque no llegue.',
    );
  }
  b.writeln(
    'En la montaña puede no haber señal: no te preocupes antes de las ${fmtTime(times.alarm)}. '
    'Si a esa hora no te escribí, llama al ${profile.emergencyNumber} y dales esta información.',
  );
  final health = [
    if (profile.bloodType.isNotEmpty)
      'sangre ${spokenBloodType(profile.bloodType)}',
    if (profile.allergies.isNotEmpty) 'alergias: ${profile.allergies}',
    if (profile.conditions.isNotEmpty) profile.conditions,
  ];
  if (health.isNotEmpty) b.writeln('Mis datos médicos: ${health.join('; ')}.');
  return b.toString().trim();
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Hoja para revisar el plan de salida y mandarlo a los contactos (SMS) o por otra app.
Future<void> showTripPlanSheet(BuildContext context, Expedition e) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TripPlanSheet(expedition: e),
    );

class _TripPlanSheet extends StatefulWidget {
  const _TripPlanSheet({required this.expedition});
  final Expedition expedition;

  @override
  State<_TripPlanSheet> createState() => _TripPlanSheetState();
}

class _TripPlanSheetState extends State<_TripPlanSheet> {
  late TripTimes _times;
  PlannedRoute? _route;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final services = AppScope.of(context);
    _route = services.routes.forExpedition(widget.expedition.id);
    _times = suggestTripTimes(
      now: DateTime.now(),
      day: widget.expedition.date,
      route: _route,
    );
  }

  DateTime? get _turnaround => widget.expedition.turnaroundOn(_times.start);

  Future<void> _pick(int which) async {
    final current = [_times.start, _times.back, _times.alarm][which];
    final picked = await showTimePicker(
      context: context,
      helpText: [
        'Hora de salida',
        'Regreso previsto',
        'Avisar si no vuelvo a las',
      ][which],
      // El modo teclado del selector falla con el tema de la app: solo reloj
      initialEntryMode: TimePickerEntryMode.dialOnly,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    // Mismo día que la salida; si queda antes, es del día siguiente
    DateTime at(DateTime base) {
      var t = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      if (which > 0 && t.isBefore(_times.start)) {
        t = t.add(const Duration(days: 1));
      }
      return t;
    }

    setState(() {
      switch (which) {
        case 0:
          final start = at(_times.start);
          final shift = start.difference(_times.start);
          _times = TripTimes(
            start,
            _times.back.add(shift),
            _times.alarm.add(shift),
          );
        case 1:
          final back = at(_times.start);
          _times = TripTimes(_times.start, back, back.add(alarmMargin));
        default:
          var alarm = at(_times.start);
          if (alarm.isBefore(_times.back)) alarm = _times.back.add(alarmMargin);
          _times = TripTimes(_times.start, _times.back, alarm);
      }
    });
  }

  String _message(EmergencyProfile profile) => tripPlanMessage(
    profile: profile,
    place: widget.expedition.name,
    times: _times,
    route: _route,
    turnaround: _turnaround,
  );

  Future<void> _sent() async {
    await AppScope.of(context).expeditions
        .update(widget.expedition, tripPlanAt: DateTime.now());
  }

  Future<void> _sms(EmergencyProfile profile) async {
    final messenger = ScaffoldMessenger.of(context);
    final phones = profile.contacts
        .map((c) => c.phone.replaceAll(' ', ''))
        .join(',');
    // Codificado a mano: con queryParameters los espacios salen como "+" en algunas apps
    final uri = Uri.parse(
      'sms:$phones?body=${Uri.encodeComponent(_message(profile))}',
    );
    final ok = await launchUrl(uri).catchError((_) => false);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir los mensajes.')),
      );
      return;
    }
    await _sent();
  }

  /// Por WhatsApp u otra app, con el GPX de la ruta si hay.
  Future<void> _share(EmergencyProfile profile) async {
    final box = context.findRenderObject() as RenderBox?;
    final files = <XFile>[];
    final route = _route;
    if (route != null) {
      final dir = await getTemporaryDirectory();
      final safe = route.name
          .replaceAll(RegExp(r'[^\w\- áéíóúñÁÉÍÓÚÑ]'), '')
          .trim();
      final f = File('${dir.path}/${safe.isEmpty ? 'ruta' : safe}.gpx');
      await f.writeAsString(routeToGpx(route));
      files.add(XFile(f.path, mimeType: 'application/gpx+xml'));
    }
    final result = await SharePlus.instance.share(
      ShareParams(
        text: _message(profile),
        files: files.isEmpty ? null : files,
        subject: 'Plan de salida: ${widget.expedition.name}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    if (result.status != ShareResultStatus.dismissed) await _sent();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final profile = services.profile.profile;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final contacts = profile.contacts.where((c) => c.phone.isNotEmpty).toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text('Plan de salida', style: signage(context, size: 24)),
            const SizedBox(height: 4),
            Text(
              'Dile a alguien a dónde vas y cuándo vuelves. Si no das señales a la hora '
              'de la alarma, sabrá que debe avisar a emergencias y con qué datos.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 14),
            _TimeRow(
              icon: Icons.directions_walk_rounded,
              label: 'Salida',
              time: _times.start,
              onTap: () => _pick(0),
            ),
            _TimeRow(
              icon: Icons.home_outlined,
              label: 'Regreso previsto',
              time: _times.back,
              onTap: () => _pick(1),
            ),
            _TimeRow(
              icon: Icons.notifications_active_outlined,
              label: 'Avisar si no vuelvo a las',
              time: _times.alarm,
              color: Andes.terracottaContainer,
              onTap: () => _pick(2),
            ),
            const SizedBox(height: 14),
            Text('EL MENSAJE', style: labelStyle(context)),
            const SizedBox(height: 6),
            TonalCard(
              padding: const EdgeInsets.all(14),
              child: Text(
                _message(profile),
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
            ),
            if (_route == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sin ruta guardada en esta expedición: el mensaje no dice por dónde vas. '
                  'Trázala o impórtala para mandarla también.',
                  style: TextStyle(color: warnColor, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 16),
            GlowButton(
              icon: Icons.sms_outlined,
              label: contacts.isEmpty
                  ? 'Sin contactos de emergencia'
                  : contacts.length == 1
                  ? 'Mandar SMS a ${contacts.first.name}'
                  : 'Mandar SMS a tus ${contacts.length} contactos',
              onPressed: contacts.isEmpty ? null : () => _sms(profile),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _share(profile),
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(
                _route == null
                    ? 'Compartir (WhatsApp…)'
                    : 'Compartir con la ruta (WhatsApp…)',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Agrega tus contactos en el perfil de emergencia para mandarles el SMS directo.',
                  style: TextStyle(color: muted, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final DateTime time;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? Andes.cyan),
      title: Text(label),
      subtitle: Text(fmtDate(time)),
      trailing: Text(
        fmtTime(time),
        style: dataStyle(
          context,
          size: 22,
          weight: FontWeight.w800,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
