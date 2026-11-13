import 'dart:async';

import 'package:flutter/material.dart';

import '../data/trail_route.dart' show naismith;
import '../routes/planned_route.dart' show PoiKind;
import '../sun/sun_times.dart';
import '../tracking/backtrack.dart';
import '../tracking/live_eta.dart';
import '../tracking/live_speed.dart';
import '../tracking/poi_alerts.dart';
import '../tracking/track.dart' show haversine;
import '../tracking/track_recorder.dart';
import 'format.dart';
import 'offline_widgets.dart';
import 'theme.dart';

/// Grabar es una acción "caliente": terracota, el tono de las alertas.
const recordColor = Andes.terracottaContainer;

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
String _mins(Duration d) => d.inMinutes < 1
    ? 'menos de 1 min'
    : d.inMinutes >= 60
    ? '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')} min'
    : '${d.inMinutes} min';

/// Un aviso de la grabación (GPS, hora límite, atardecer, punto cercano, fuera de ruta).
class RecordingAlert {
  const RecordingAlert(this.color, this.icon, this.text);
  final Color color;
  final IconData icon;
  final String text;
}

/// Los avisos que hay que ver ahora, del más urgente al menos. Los usan el panel completo
/// y la tira compacta (que muestra el primero).
List<RecordingAlert> recordingAlerts(TrackRecorder r, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final recording = r.state == RecorderState.recording;
  final fix = r.lastFix;
  final gpsWeak =
      recording && (fix == null || fix.accuracy > TrackRecorder.maxAccuracy);
  final eta = liveEta(progress: r.progress, stats: r.stats, now: t);
  // De regreso importa llegar con luz; el atardecer se calcula sin conexión
  final sunset = r.backtracking && fix != null
      ? sunTimes(date: t, lat: fix.lat, lng: fix.lng).sunset
      : null;
  final near = fix == null ? null : nearPoi(r.pois, fix.lat, fix.lng);
  return [
    // Bajo techo el GPS no logra la precisión mínima y no se guardan puntos:
    // sin este aviso parece que la grabación no arrancó
    if (r.gpsError != null)
      const RecordingAlert(
        recordColor,
        Icons.location_disabled_rounded,
        'El GPS no está entregando tu posición. Revisa que la ubicación del teléfono esté encendida; Cresta vuelve a intentarlo sola.',
      )
    else if (gpsWeak && r.points.isEmpty)
      const RecordingAlert(
        warnColor,
        Icons.satellite_alt_outlined,
        'Esperando una señal GPS precisa. Sal al aire libre para empezar a registrar puntos.',
      ),
    if (r.turnaroundState case TurnaroundState.soon || TurnaroundState.passed)
      RecordingAlert(
        r.turnaroundState == TurnaroundState.passed ? recordColor : warnColor,
        Icons.alarm_rounded,
        r.turnaroundState == TurnaroundState.passed
            ? 'Pasó tu hora límite (${_hhmm(r.turnaround!)}). Es momento de regresar.'
            : 'Quedan ${_mins(r.turnaroundLeft!)} para tu hora límite de regreso (${_hhmm(r.turnaround!)}).',
      ),
    if (eta != null &&
        !r.backtracking &&
        r.turnaroundState == TurnaroundState.ok &&
        eta.arrival.isAfter(r.turnaround!))
      RecordingAlert(
        warnColor,
        Icons.schedule_rounded,
        '${eta.pace == null ? 'Según la regla de Naismith' : 'A tu ritmo'} llegarías al final a las ${_hhmm(eta.arrival)}, después de tu hora límite (${_hhmm(r.turnaround!)}).',
      ),
    if (eta != null && sunset != null && eta.arrival.isAfter(sunset))
      RecordingAlert(
        warnColor,
        Icons.wb_twilight_rounded,
        'Llegarías al inicio a las ${_hhmm(eta.arrival)}, después del atardecer (${_hhmm(sunset)}). Ten lista la linterna.',
      ),
    if (near != null)
      RecordingAlert(
        switch (near.$1.kind) {
          PoiKind.danger || PoiKind.noReturn => recordColor,
          _ => okColor,
        },
        Icons.place_rounded,
        () {
          final (title, body) = poiAlertText(near.$1, near.$2);
          return '$title. $body';
        }(),
      ),
    if (r.progress?.isOffRoute == true)
      RecordingAlert(
        warnColor,
        Icons.wrong_location_outlined,
        r.backtracking
            ? 'Estás a ${fmtInt(r.progress!.offRoute)} m de tu traza. Vuelve a ella para regresar por donde viniste.'
            : 'Estás a ${fmtInt(r.progress!.offRoute)} m de la ruta planeada.',
      ),
  ];
}

/// Una línea con lo más útil cuando no hay avisos: el próximo punto, la llegada o lo que
/// falta; sin ruta, los kilómetros y la subida.
String recordingSummary(TrackRecorder r, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final s = r.stats;
  if (r.state == RecorderState.paused) return 'En pausa';
  final eta = liveEta(progress: r.progress, stats: s, now: t);
  final ahead = r.route == null || r.progress == null
      ? null
      : nextPoiAhead(r.route!, r.pois, r.progress!.metersAlong);
  if (ahead != null) {
    return 'Próximo: ${ahead.poi.name} en ${ahead.meters < 1000 ? '${fmtInt(ahead.meters)} m' : '${fmtKm(ahead.meters)} km'}';
  }
  if (eta != null) {
    return 'Llegas ${r.backtracking ? 'al inicio' : 'al final'} ≈ ${_hhmm(eta.arrival)} · faltan ${fmtKm(r.progress!.remainingMeters)} km';
  }
  return '+${fmtInt(s.gain)} m de subida · ${fmtDuration(s.moving)} en movimiento';
}

/// Datos en vivo mientras se graba: distancia, tiempo, altitud, desnivel, avance y hora límite.
class RecordingPanel extends StatelessWidget {
  const RecordingPanel({
    super.key,
    required this.recorder,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    this.onBacktrack,
  });

  final TrackRecorder recorder;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  /// Empezar o dejar la guía de regreso por la propia traza (null: no se ofrece).
  final VoidCallback? onBacktrack;

  @override
  Widget build(BuildContext context) {
    final r = recorder;
    final s = r.stats;
    final scheme = Theme.of(context).colorScheme;
    final recording = r.state == RecorderState.recording;
    final fix = r.lastFix;
    final vs = s.verticalSpeed;
    final gpsWeak =
        recording && (fix == null || fix.accuracy > TrackRecorder.maxAccuracy);
    final now = DateTime.now();
    final eta = liveEta(progress: r.progress, stats: s, now: now);
    // De regreso importa llegar con luz; el atardecer se calcula sin conexión
    final sunset = r.backtracking && fix != null
        ? sunTimes(date: now, lat: fix.lat, lng: fix.lng).sunset
        : null;
    final afterSunset =
        eta != null && sunset != null && eta.arrival.isAfter(sunset);
    final near = fix == null ? null : nearPoi(r.pois, fix.lat, fix.lng);
    final ahead = r.route == null || r.progress == null
        ? null
        : nextPoiAhead(r.route!, r.pois, r.progress!.metersAlong);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: Row(
            children: [
              _Dot(active: recording),
              const SizedBox(width: 8),
              Text(
                r.backtracking
                    ? (recording ? 'REGRESANDO' : 'EN PAUSA · REGRESO')
                    : (recording ? 'GRABANDO' : 'EN PAUSA'),
                style: labelStyle(
                  context,
                  color: recording ? recordColor : null,
                ),
              ),
              const Spacer(),
              if (fix != null || gpsWeak)
                _GpsChip(
                  text: gpsWeak
                      ? (fix == null
                            ? 'Buscando GPS'
                            : 'GPS débil ±${fix.accuracy.round()} m')
                      : 'GPS ±${fix!.accuracy.round()} m',
                  color: gpsWeak ? warnColor : okColor,
                ),
            ],
          ),
        ),
        for (final a in recordingAlerts(r, now: now))
          _Banner(color: a.color, icon: a.icon, text: a.text),
        // Las dos cifras protagonistas, grandes para leerlas de un vistazo
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Figure(
                fmtKm(s.meters, decimals: 2),
                'kilómetros',
                size: 52,
                labelColor: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _LiveClock(recorder: r)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _Tile(
                accent: Andes.gold,
                child: Figure(
                  s.altitude == null ? '–' : fmtInt(s.altitude!),
                  'altitud',
                  unit: 'm',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tile(
                accent: scheme.primary,
                child: Figure(
                  '+${fmtInt(s.gain)}',
                  'subida · −${fmtInt(s.loss)} bajada',
                  unit: 'm',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Tile(
                child: Figure(fmtDuration(s.moving), 'en movimiento', size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tile(
                child: Figure(
                  vs == null ? '–' : '${vs >= 0 ? '+' : ''}${fmtInt(vs)}',
                  'vertical',
                  unit: 'm/h',
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        if (r.progress != null || r.turnaroundState == TurnaroundState.ok)
          const SizedBox(height: 12),
        if (r.progress != null)
          Text(
            r.backtracking
                ? 'Faltan ${fmtKm(r.progress!.remainingMeters)} km y ${fmtInt(r.progress!.remainingGain)} m de subida por tu traza hasta el inicio.'
                : 'Faltan ${fmtKm(r.progress!.remainingMeters)} km y ${fmtInt(r.progress!.remainingGain)} m de subida hasta el final de la ruta.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        if (ahead != null && near?.$1 != ahead.poi)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Próximo: ${ahead.poi.name} en ${ahead.meters < 1000 ? '${fmtInt(ahead.meters)} m' : '${fmtKm(ahead.meters)} km'}'
              ' (≈ ${_mins(Duration(seconds: (naismith(ahead.meters, 0).inSeconds * (eta?.pace ?? 1)).round()))}).',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        if (eta != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Llegas ${r.backtracking ? 'al inicio' : 'al final'} ≈ ${_hhmm(eta.arrival)} (en ${_mins(eta.remaining)}), '
              '${eta.pace == null ? 'según la regla de Naismith' : 'a tu ritmo'}, sin contar paradas'
              '${sunset != null && !afterSunset ? '. El sol se pone a las ${_hhmm(sunset)}' : ''}.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        if (r.backtracking && fix != null && r.points.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _toStart(
                fix.lat,
                fix.lng,
                r.points.first.lat,
                r.points.first.lng,
              ),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        if (r.turnaroundState == TurnaroundState.ok)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Hora límite de regreso: ${_hhmm(r.turnaround!)} (en ${_mins(r.turnaroundLeft!)}).',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: recording
                  ? _ActionButton(
                      label: 'Pausar',
                      icon: Icons.pause_rounded,
                      color: Andes.surfaceHighest,
                      foreground: Andes.onSurface,
                      onPressed: onPause,
                    )
                  : _ActionButton(
                      label: 'Reanudar',
                      icon: Icons.fiber_manual_record_rounded,
                      color: recordColor,
                      foreground: Andes.onTerracotta,
                      onPressed: onResume,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: _ActionButton(
                label: 'Terminar',
                icon: Icons.stop_rounded,
                gradient: Andes.cyanGlow,
                foreground: Andes.onCyan,
                onPressed: onStop,
              ),
            ),
          ],
        ),
        if (onBacktrack != null &&
            (r.backtracking || r.points.length >= 2)) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onBacktrack,
              icon: Icon(
                r.backtracking
                    ? Icons.close_rounded
                    : Icons.u_turn_left_rounded,
              ),
              label: Text(
                r.backtracking
                    ? 'Dejar de guiar el regreso'
                    : 'Volver al inicio por mi traza',
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// "El inicio está a 2.3 km en línea recta, rumbo 215° (SO)": sirve sin brújula, con el sol
  /// o el relieve, y para decirlo por radio.
  static String _toStart(double lat, double lng, double sLat, double sLng) {
    final m = haversine(lat, lng, sLat, sLng);
    if (m < 30) return 'Estás en el punto de salida.';
    final deg = bearingDeg(lat, lng, sLat, sLng);
    final dist = m < 1000 ? '${fmtInt(m)} m' : '${fmtKm(m)} km';
    return 'El inicio está a $dist en línea recta, rumbo ${deg.round()}° (${cardinal(deg)}).';
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.active ? recordColor : Andes.outline,
      ),
    );
    if (!widget.active || MediaQuery.disableAnimationsOf(context)) return dot;
    return FadeTransition(
      opacity: Tween(begin: .35, end: 1.0).animate(_c),
      child: dot,
    );
  }
}

/// Tiempo total grabando. Se refresca cada segundo por su cuenta: el grabador
/// solo avisa cuando llega un punto o cada 10 s.
class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.recorder});
  final TrackRecorder recorder;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.recorder.state == RecorderState.recording) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Figure(
    fmtClock(widget.recorder.activeTime),
    'tiempo total',
    size: 34,
    color: Andes.onSurfaceVariant,
  );
}

/// Módulo de telemetría: tono más alto que el panel, con barra de acento opcional.
class _Tile extends StatelessWidget {
  const _Tile({required this.child, this.accent});
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) => TonalCard(
    color: Andes.surfaceHigh,
    accent: accent,
    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
    child: SizedBox(width: double.infinity, child: child),
  );
}

class _GpsChip extends StatelessWidget {
  const _GpsChip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.satellite_alt_rounded, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: labelStyle(
            context,
            color: color,
          ).copyWith(fontSize: 10, letterSpacing: .8),
        ),
      ],
    ),
  );
}

/// Botón grande de la grabación: se usa con guantes, así que es alto y ancho.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.onPressed,
    this.color,
    this.gradient,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(gradient: gradient),
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: foreground.withValues(alpha: .14),
                ),
                child: Icon(icon, color: foreground, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TonalCard(
      color: color.withValues(alpha: .1),
      accent: color,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Elegir el modo antes de empezar a grabar.
Future<RecordingMode?> askRecordingMode(BuildContext context) =>
    showModalBottomSheet<RecordingMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('NUEVO RECORRIDO', style: labelStyle(context)),
              const SizedBox(height: 4),
              Text('Grabar recorrido', style: signage(context, size: 26)),
              const SizedBox(height: 6),
              Text(
                'Funciona sin señal: el GPS usa satélites. Puedes bloquear la pantalla; la grabación sigue.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              // Lo que más gasta en la montaña es buscar señal celular y la pantalla
              Text(
                'Para que dure la batería: modo avión (el GPS sigue funcionando) y la pantalla apagada o con poco brillo.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (final m in RecordingMode.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TonalCard(
                    color: Andes.surfaceHigh,
                    accent: m == RecordingMode.normal ? Andes.cyan : Andes.gold,
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                    onTap: () => Navigator.pop(context, m),
                    child: Row(
                      children: [
                        Icon(
                          m == RecordingMode.normal
                              ? Icons.gps_fixed_rounded
                              : Icons.battery_saver_rounded,
                          color: m == RecordingMode.normal
                              ? Andes.cyan
                              : Andes.gold,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                m.description,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Andes.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.fiber_manual_record_rounded,
                          color: recordColor,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

/// Barra de datos arriba del mapa mientras se graba (como Gaia): altitud, velocidad y
/// distancia siempre a la vista, aunque el panel de abajo esté bajado. Tocarla abre el panel.
class RecordingBar extends StatelessWidget {
  const RecordingBar({super.key, required this.recorder, this.onTap});
  final TrackRecorder recorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = recorder;
    final s = r.stats;
    final paused = r.state == RecorderState.paused;
    final kmh = paused
        ? null
        : liveSpeedKmh(r.lastFix, r.points, DateTime.now());
    final alt = s.altitude ?? r.lastFix?.altitude;
    return Glass(
      opacity: .9,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            child: Row(
              children: [
                // Grabando (rojo) o en pausa (oro)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: paused ? Andes.gold : recordColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BarValue(
                    alt == null ? '–' : fmtInt(alt),
                    'm',
                    'ALTITUD',
                  ),
                ),
                Expanded(
                  child: _BarValue(
                    kmh == null ? '–' : kmh.toStringAsFixed(1),
                    'km/h',
                    paused ? 'EN PAUSA' : 'VELOCIDAD',
                  ),
                ),
                Expanded(
                  child: _BarValue(
                    fmtKm(s.meters, decimals: 2),
                    'km',
                    'DISTANCIA',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarValue extends StatelessWidget {
  const _BarValue(this.value, this.unit, this.label);
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: labelStyle(context).copyWith(fontSize: 9, letterSpacing: 1),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: dataStyle(context, size: 19, weight: FontWeight.w800),
                ),
                TextSpan(
                  text: ' $unit',
                  style: dataStyle(context, size: 11, color: muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tira compacta de abajo mientras se graba: el tiempo, el aviso más urgente (o lo más útil
/// si no hay avisos) y los controles. Lo demás está en [onMore] (el panel completo); así el
/// mapa queda casi entero a la vista.
class RecordingStrip extends StatefulWidget {
  const RecordingStrip({
    super.key,
    required this.recorder,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onPhoto,
    required this.onMore,
  });
  final TrackRecorder recorder;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onPhoto;
  final VoidCallback onMore;

  @override
  State<RecordingStrip> createState() => _RecordingStripState();
}

class _RecordingStripState extends State<RecordingStrip> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.recorder.state == RecorderState.recording) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recorder;
    final recording = r.state == RecorderState.recording;
    final alerts = recordingAlerts(r);
    final alert = alerts.isEmpty ? null : alerts.first;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Glass(
      opacity: .94,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: widget.onMore,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      fmtClock(r.activeTime),
                      style: dataStyle(
                        context,
                        size: 17,
                        weight: FontWeight.w800,
                        color: recording ? null : Andes.gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (alert != null) ...[
                      Icon(alert.icon, size: 18, color: alert.color),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        alert?.text ?? recordingSummary(r),
                        maxLines: alert == null ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: alert?.color ?? muted,
                          fontWeight: alert == null ? null : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: recording
                      ? _StripButton(
                          label: 'Pausar',
                          icon: Icons.pause_rounded,
                          color: Andes.surfaceHighest,
                          foreground: Andes.onSurface,
                          onPressed: widget.onPause,
                        )
                      : _StripButton(
                          label: 'Reanudar',
                          icon: Icons.fiber_manual_record_rounded,
                          color: recordColor,
                          foreground: Andes.onTerracotta,
                          onPressed: widget.onResume,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: _StripButton(
                    label: 'Terminar',
                    icon: Icons.stop_rounded,
                    gradient: Andes.cyanGlow,
                    foreground: Andes.onCyan,
                    onPressed: widget.onStop,
                  ),
                ),
                const SizedBox(width: 8),
                _StripIcon(
                  icon: Icons.photo_camera_outlined,
                  tooltip: 'Tomar una foto aquí',
                  onPressed: widget.onPhoto,
                ),
                const SizedBox(width: 6),
                _StripIcon(
                  icon: Icons.expand_less_rounded,
                  tooltip: 'Más datos y opciones',
                  onPressed: widget.onMore,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StripButton extends StatelessWidget {
  const _StripButton({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.onPressed,
    this.color,
    this.gradient,
  });
  final String label;
  final IconData icon;
  final Color foreground;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Colors.transparent,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(gradient: gradient),
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StripIcon extends StatelessWidget {
  const _StripIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Andes.surfaceHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: Andes.onSurface, size: 22),
        ),
      ),
    ),
  );
}
