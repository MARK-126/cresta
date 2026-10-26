import 'package:flutter/material.dart';

import '../app_services.dart';
import '../tracking/track.dart';
import 'format.dart';
import 'map_screen.dart';
import 'recording_panel.dart';
import 'theme.dart';
import 'track_screen.dart';

/// Bitácora: todos los recorridos de todas las expediciones, del más reciente al más antiguo.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([services.tracks, services.expeditions]),
      builder: (context, _) {
        final tracks = [...services.tracks.all]
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        final children = <Widget>[];
        String? month;
        for (final t in tracks) {
          final m = fmtMonth(t.startedAt.toLocal());
          if (m != month) {
            month = m;
            children.add(
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Text(m.toUpperCase(), style: labelStyle(context)),
              ),
            );
          }
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LogEntry(track: t),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text('BITÁCORA', style: labelStyle(context, color: Andes.gold)),
              const SizedBox(height: 6),
              Text('Recorridos', style: signage(context, size: 34)),
              const SizedBox(height: 4),
              Text(
                tracks.isEmpty
                    ? 'Aquí aparecerá cada recorrido que grabes.'
                    : '${tracks.length} ${tracks.length == 1 ? 'recorrido grabado' : 'recorridos grabados'}',
                style: dataStyle(
                  context,
                  color: Andes.onSurfaceVariant,
                  weight: FontWeight.w500,
                ),
              ),
              if (tracks.isEmpty) ...[
                const SizedBox(height: 24),
                TonalCard(
                  color: Andes.surfaceLow,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 32,
                        color: Andes.onSurfaceVariant,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Abre el mapa de una expedición y toca el botón de grabar. Funciona sin señal.',
                          style: TextStyle(
                            color: Andes.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              ...children,
            ],
          ),
        );
      },
    );
  }
}

/// Una entrada de la bitácora: estado, expedición, nombre y sus cifras.
class LogEntry extends StatelessWidget {
  const LogEntry({super.key, required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final t = track;
    final s = t.summary;
    final expedition = services.expeditions.byId(t.expeditionId);
    final (String status, Color color, IconData icon) = switch (t.status) {
      TrackStatus.finished => ('Terminado', Andes.cyan, Icons.check_rounded),
      TrackStatus.recording => (
        'Grabando',
        recordColor,
        Icons.fiber_manual_record_rounded,
      ),
      TrackStatus.paused => ('En pausa', Andes.gold, Icons.pause_rounded),
    };
    final finished = t.status == TrackStatus.finished;
    final start = t.startedAt.toLocal();

    return TonalCard(
      accent: color,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => finished
              ? TrackScreen(trackId: t.id)
              : MapScreen(expeditionId: t.expeditionId),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .16),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                status.toUpperCase(),
                style: labelStyle(context, color: color).copyWith(fontSize: 10),
              ),
              if (expedition != null)
                Expanded(
                  child: Text(
                    '  ·  ${expedition.name.toUpperCase()}',
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle(context).copyWith(fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(t.name, style: signage(context, size: 18)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Figure(fmtKm(s.meters, decimals: 1), 'km', size: 18),
              ),
              Expanded(
                child: Figure(
                  '+${fmtInt(s.gain)}',
                  'desnivel',
                  unit: 'm',
                  size: 18,
                ),
              ),
              Expanded(
                child: Figure(fmtDuration(s.moving), 'en movimiento', size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: Andes.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${fmtDate(start)} · ${fmtTime(start)}',
                style: dataStyle(
                  context,
                  size: 12,
                  color: Andes.onSurfaceVariant,
                  weight: FontWeight.w500,
                ),
              ),
              if (s.maxAltitude != null) ...[
                const Spacer(),
                const Icon(
                  Icons.landscape_rounded,
                  size: 14,
                  color: Andes.gold,
                ),
                const SizedBox(width: 4),
                Text(
                  '${fmtInt(s.maxAltitude!)} m',
                  style: dataStyle(
                    context,
                    size: 12,
                    color: Andes.gold,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
