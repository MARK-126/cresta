import 'dart:async';

import 'package:flutter/material.dart';

import '../tracking/track_recorder.dart';
import 'format.dart';
import 'offline_widgets.dart';
import 'theme.dart';

const recordColor = Color(0xFFD7263D);

/// Datos en vivo mientras se graba: distancia, tiempo, altitud, desnivel, avance y hora límite.
class RecordingPanel extends StatelessWidget {
  const RecordingPanel({
    super.key,
    required this.recorder,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final TrackRecorder recorder;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Row(
            children: [
              _Dot(active: recording),
              const SizedBox(width: 8),
              Text(
                recording ? 'GRABANDO' : 'EN PAUSA',
                style: labelStyle(context)
                    .copyWith(color: recording ? recordColor : null),
              ),
              const Spacer(),
              Text(
                gpsWeak
                    ? (fix == null
                          ? 'Buscando GPS…'
                          : 'GPS débil (±${fix.accuracy.round()} m)')
                    : fix == null
                    ? ''
                    : 'GPS ±${fix.accuracy.round()} m',
                style: dataStyle(
                  context,
                  size: 11.5,
                  color: gpsWeak ? warnColor : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Bajo techo el GPS no logra la precisión mínima y no se guardan puntos:
        // sin este aviso parece que la grabación no arrancó
        if (gpsWeak && r.points.isEmpty)
          const _Banner(
            color: warnColor,
            icon: Icons.satellite_alt_outlined,
            text: 'Esperando una señal GPS precisa. Sal al aire libre para empezar a registrar puntos.',
          ),
        if (r.turnaroundState
            case TurnaroundState.soon || TurnaroundState.passed)
          _Banner(
            color: r.turnaroundState == TurnaroundState.passed
                ? recordColor
                : warnColor,
            icon: Icons.alarm_rounded,
            text: r.turnaroundState == TurnaroundState.passed
                ? 'Pasó tu hora límite (${_hhmm(r.turnaround!)}). Es momento de regresar.'
                : 'Quedan ${_mins(r.turnaroundLeft!)} para tu hora límite de regreso (${_hhmm(r.turnaround!)}).',
          ),
        if (r.progress?.isOffRoute == true)
          _Banner(
            color: warnColor,
            icon: Icons.wrong_location_outlined,
            text:
                'Estás a ${fmtInt(r.progress!.offRoute)} m de la ruta planeada.',
          ),
        Row(
          children: [
            _Big(fmtKm(s.meters, decimals: 2), 'km'),
            _LiveClock(recorder: r),
            _Big(s.altitude == null ? '–' : fmtInt(s.altitude!), 'altitud m'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Big('+${fmtInt(s.gain)}', 'subida m', small: true),
            _Big('−${fmtInt(s.loss)}', 'bajada m', small: true),
            _Big(fmtDuration(s.moving), 'en movimiento', small: true),
            _Big(
              vs == null ? '–' : '${vs >= 0 ? '+' : ''}${fmtInt(vs)}',
              'm/h vertical',
              small: true,
            ),
          ],
        ),
        if (r.progress != null) ...[
          const SizedBox(height: 10),
          Text(
            'Faltan ${fmtKm(r.progress!.remainingMeters)} km y ${fmtInt(r.progress!.remainingGain)} m de subida hasta el final de la ruta.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
        if (r.turnaroundState == TurnaroundState.ok)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Hora límite de regreso: ${_hhmm(r.turnaround!)} (en ${_mins(r.turnaroundLeft!)}).',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: recording
                  ? OutlinedButton.icon(
                      onPressed: onPause,
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Pausar'),
                    )
                  : FilledButton.icon(
                      onPressed: onResume,
                      style: FilledButton.styleFrom(
                        backgroundColor: recordColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.fiber_manual_record_rounded),
                      label: const Text('Reanudar'),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Terminar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  static String _mins(Duration d) =>
      d.inMinutes < 1 ? 'menos de 1 min' : _minsRaw(d);
  static String _minsRaw(Duration d) => d.inMinutes >= 60
      ? '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')} min'
      : '${d.inMinutes} min';
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
        color: widget.active ? recordColor : Colors.grey,
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
  Widget build(BuildContext context) =>
      _Big(fmtClock(widget.recorder.activeTime), 'tiempo');
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label, {this.small = false});
  final String value;
  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: dataStyle(context, size: small ? 16 : 24)),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: .6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
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
              Text('Grabar recorrido', style: signage(context, size: 22)),
              const SizedBox(height: 6),
              Text(
                'Funciona sin señal: el GPS usa satélites. Puedes bloquear la pantalla; la grabación sigue.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final m in RecordingMode.values)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      m == RecordingMode.normal
                          ? Icons.gps_fixed_rounded
                          : Icons.battery_saver_rounded,
                    ),
                    title: Text(m.label),
                    subtitle: Text(m.description),
                    trailing: const Icon(
                      Icons.fiber_manual_record_rounded,
                      color: recordColor,
                    ),
                    onTap: () => Navigator.pop(context, m),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
