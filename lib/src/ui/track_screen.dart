import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../data/trail_route.dart';
import '../tracking/gpx.dart';
import '../tracking/track.dart';
import 'elevation_profile.dart';
import 'format.dart';
import 'map_screen.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'theme.dart';

/// Detalle de un recorrido grabado: cifras, perfil de elevación, ver en el mapa y exportar GPX.
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key, required this.trackId});
  final String trackId;

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  List<TrackPoint>? _points;
  double? _cursor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_points == null) {
      AppScope.of(context).tracks.readPoints(widget.trackId).then((p) {
        if (mounted) setState(() => _points = p);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final t = services.tracks.byId(widget.trackId);
    if (t == null) return const Scaffold(body: SizedBox.shrink());
    final s = t.summary;
    final profile = _points == null ? null : profileOf(_points!);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.name, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'rename' ? _rename(t) : _delete(t),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Cambiar nombre')),
              PopupMenuItem(value: 'delete', child: Text('Borrar recorrido')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '${fmtDate(t.startedAt)} · ${_hhmm(t.startedAt)}${t.endedAt == null ? '' : '–${_hhmm(t.endedAt!)}'}',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 14,
            children: [
              _Figure(fmtKm(s.meters, decimals: 2), 'km'),
              _Figure(fmtDuration(s.moving), 'en movimiento'),
              _Figure(fmtDuration(s.elapsed), 'total'),
              _Figure('+${fmtInt(s.gain)}', 'subida m'),
              _Figure('−${fmtInt(s.loss)}', 'bajada m'),
              _Figure(
                s.maxAltitude == null ? '–' : fmtInt(s.maxAltitude!),
                'altitud máx. m',
              ),
            ],
          ),
          const SectionTitle('Perfil de elevación'),
          if (_points == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (profile == null)
            Text(
              'Este recorrido no tiene datos de altitud suficientes.',
              style: TextStyle(color: muted),
            )
          else ...[
            ElevationProfile(
              route: profile,
              cursorMeters: _cursor,
              onScrub: (m) => setState(() => _cursor = m),
              onScrubEnd: () {},
            ),
            if (_cursor != null)
              Text(
                'km ${fmtKm(_cursor!, decimals: 2)} · ${fmtInt(profile.along(_cursor!).elevation)} m',
                style: dataStyle(context, size: 12, color: muted),
              ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    MapScreen(expeditionId: t.expeditionId, showTrackId: t.id),
              ),
            ),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Ver en el mapa'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _points == null || _points!.isEmpty
                ? null
                : () => _exportGpx(t),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Exportar GPX'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'El GPX se abre en Wikiloc, Strava, Garmin Connect o Google Earth.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportGpx(Track t) async {
    final box = context.findRenderObject() as RenderBox?;
    final dir = await getTemporaryDirectory();
    final safe = t.name.replaceAll(RegExp(r'[^\w\- áéíóúñÁÉÍÓÚÑ]'), '').trim();
    final file = File('${dir.path}/${safe.isEmpty ? 'recorrido' : safe}.gpx');
    await file.writeAsString(toGpx(t, _points!));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/gpx+xml')],
        subject: t.name,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _rename(Track t) async {
    final ctrl = TextEditingController(text: t.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre del recorrido'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    t.name = name;
    await AppScope.of(context).tracks.save();
    setState(() {});
  }

  Future<void> _delete(Track t) async {
    final tracks = AppScope.of(context).tracks;
    final navigator = Navigator.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Borrar "${t.name}"',
      body: 'Se borra el recorrido grabado. No se puede deshacer.',
      action: 'Borrar',
    );
    if (!ok) return;
    navigator.pop();
    await tracks.delete(t.id);
  }

  static String _hhmm(DateTime utcOrLocal) => _hhmmLocal(utcOrLocal.toLocal());
  static String _hhmmLocal(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Convierte un recorrido en "ruta" para reutilizar el perfil de elevación.
TrailRoute? profileOf(List<TrackPoint> points) {
  final withAlt = points.where((p) => p.altitude != null).toList();
  if (withAlt.length < 2) return null;
  final dist = <double>[0];
  for (var i = 1; i < withAlt.length; i++) {
    final a = withAlt[i - 1], b = withAlt[i];
    dist.add(
      dist.last +
          (a.segment == b.segment ? haversine(a.lat, a.lng, b.lat, b.lng) : 0),
    );
  }
  if (dist.last < 10) return null;
  return TrailRoute(
    id: 'track',
    name: '',
    summary: '',
    coordinates: [for (final p in withAlt) LngLat(p.lng, p.lat)],
    distances: dist,
    elevations: [for (final p in withAlt) p.altitude!],
    gain: 0,
    source: '',
  );
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: dataStyle(context, size: 18)),
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

/// Lista de recorridos de una expedición.
class TrackList extends StatelessWidget {
  const TrackList({super.key, required this.expeditionId});
  final String expeditionId;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: services.tracks,
      builder: (context, _) {
        final tracks = services.tracks.forExpedition(expeditionId);
        if (tracks.isEmpty) {
          return Text(
            'Aún no hay recorridos. Abre el mapa y toca el botón rojo para grabar.',
            style: TextStyle(color: muted),
          );
        }
        return Column(
          children: [
            for (final t in tracks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  t.status == TrackStatus.finished
                      ? Icons.route_rounded
                      : Icons.fiber_manual_record_rounded,
                  color: t.status == TrackStatus.finished
                      ? const Color(0xFF1F6FD6)
                      : const Color(0xFFD7263D),
                ),
                title: Text(t.name),
                subtitle: Text(
                  t.status == TrackStatus.finished
                      ? '${fmtDate(t.startedAt)} · ${fmtKm(t.summary.meters)} km · +${fmtInt(t.summary.gain)} m · ${fmtDuration(t.summary.moving)}'
                      : 'En curso · ${fmtKm(t.summary.meters)} km',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: t.status == TrackStatus.finished
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TrackScreen(trackId: t.id),
                        ),
                      )
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MapScreen(expeditionId: t.expeditionId),
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }
}
