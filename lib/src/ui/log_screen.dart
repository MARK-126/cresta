import 'package:flutter/material.dart';

import '../app_services.dart';
import '../tracking/track.dart';
import 'format.dart';
import 'map_screen.dart';
import 'route_silhouette.dart';
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
                          'Toca «Grabar · Desde aquí» en el inicio, o el botón de grabar en cualquier mapa. Funciona sin señal.',
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
/// Puntos de cada recorrido para su silueta en la lista (se leen una vez por sesión; la
/// clave lleva la cantidad de puntos, así un recorrido que sigue grabando se vuelve a leer).
final _silhouettes = <String, Future<List<(double, double)>>>{};

Future<List<(double, double)>> _silhouetteOf(AppServices services, Track t) =>
    _silhouettes.putIfAbsent('${t.id}:${t.summary.points}', () async {
      final pts = await services.tracks.readPoints(t.id);
      // Con unos 200 puntos basta para la forma
      final step = (pts.length / 200).ceil().clamp(1, 1 << 20);
      return [
        for (var i = 0; i < pts.length; i += step) (pts[i].lng, pts[i].lat),
        if (pts.isNotEmpty) (pts.last.lng, pts.last.lat),
      ];
    });

/// Un recorrido en la lista: la forma del recorrido al lado (lo más reconocible) y los km
/// como protagonista. Sin "Terminado" en cada uno ni la fecha repetida en el nombre.
class LogEntry extends StatelessWidget {
  const LogEntry({super.key, required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final t = track;
    final s = t.summary;
    final expedition = services.expeditions.byId(t.expeditionId);
    final (String? status, Color? color) = switch (t.status) {
      TrackStatus.finished => (null, null),
      TrackStatus.recording => ('GRABANDO', recordColor),
      TrackStatus.paused => ('EN PAUSA', Andes.gold),
    };
    final finished = t.status == TrackStatus.finished;
    final start = t.startedAt.toLocal();
    final meta = [
      fmtDate(start).toUpperCase(),
      fmtTime(start),
      expedition?.name.toUpperCase() ?? 'RECORRIDO LIBRE',
    ].join(' · ');

    return TonalCard(
      accent: color,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => finished
              ? TrackScreen(trackId: t.id)
              : MapScreen(expeditionId: t.expeditionId),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      if (status != null)
                        TextSpan(
                          text: '$status · ',
                          style: TextStyle(color: color),
                        ),
                      TextSpan(text: meta),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle(context).copyWith(fontSize: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  trackTitle(t),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: signage(context, size: 17),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: fmtKm(s.meters, decimals: 1)),
                      TextSpan(
                        text: ' KM',
                        style: display(context, size: 20, color: Andes.cyan),
                      ),
                    ],
                  ),
                  style: display(context, size: 48),
                ),
                const SizedBox(height: 4),
                Text(
                  '+${fmtInt(s.gain)} m  ·  ${fmtDuration(s.moving)} en movimiento'
                  '${s.maxAltitude == null ? '' : '  ·  ${fmtInt(s.maxAltitude!)} m máx.'}',
                  style: dataStyle(
                    context,
                    size: 12,
                    color: Andes.onSurfaceVariant,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (s.points > 1)
            SizedBox(
              width: 64,
              height: 96,
              child: FutureBuilder(
                future: _silhouetteOf(services, t),
                builder: (context, snap) => snap.hasData
                    ? RouteSilhouette(points: snap.data!, strokeWidth: 2.5)
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}
