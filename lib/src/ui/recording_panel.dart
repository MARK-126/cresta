import 'dart:async';

import 'package:flutter/material.dart';

import '../tracking/track_recorder.dart';
import 'format.dart';
import 'offline_widgets.dart';
import 'theme.dart';

/// Grabar es una acción "caliente": terracota, el tono de las alertas.
const recordColor = Andes.terracottaContainer;

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
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: Row(
            children: [
              _Dot(active: recording),
              const SizedBox(width: 8),
              Text(
                recording ? 'GRABANDO' : 'EN PAUSA',
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
            'Faltan ${fmtKm(r.progress!.remainingMeters)} km y ${fmtInt(r.progress!.remainingGain)} m de subida hasta el final de la ruta.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
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
