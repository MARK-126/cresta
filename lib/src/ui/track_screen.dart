import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../data/trail_route.dart';
import '../tracking/gpx.dart';
import '../tracking/share_trim.dart';
import '../tracking/track.dart';
import 'elevation_profile.dart';
import 'format.dart';
import 'map_screen.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'photo_screen.dart';
import 'recording_panel.dart';
import 'route_silhouette.dart';
import 'share_trim_screen.dart';
import 'track_image_screen.dart';
import 'route_destination.dart';
import 'theme.dart';
import 'video_options_sheet.dart';

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
    final expedition = services.expeditions.byId(t.expeditionId);

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'rename' => _rename(t),
              'move' => _move(t),
              _ => _delete(t),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'rename',
                child: Text('Cambiar nombre'),
              ),
              PopupMenuItem(
                value: 'move',
                child: Text(
                  expedition == null
                      ? 'Pasar a una expedición'
                      : 'Cambiar de expedición',
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Borrar recorrido'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          // Metadatos chiquitos arriba (como "OVER-EAR · WIRELESS" en las referencias)
          Text(
            [
              expedition == null
                  ? 'RECORRIDO LIBRE'
                  : expedition.name.toUpperCase(),
              fmtDate(t.startedAt).toUpperCase(),
              '${_hhmm(t.startedAt)}${t.endedAt == null ? '' : '–${_hhmm(t.endedAt!)}'}',
            ].join(' · '),
            style: labelStyle(context, color: Andes.gold),
          ),
          const SizedBox(height: 6),
          Text(trackTitle(t), style: signage(context, size: 28)),
          const SizedBox(height: 12),
          // Protagonista: los km enormes y, al lado, la forma del recorrido
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          fmtKm(s.meters, decimals: 2),
                          style: display(context, size: 132),
                        ),
                      ),
                      Text(
                        'KILÓMETROS',
                        style: labelStyle(
                          context,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_points != null && _points!.length > 1)
                  // Alto fijo: en una fila, sin él la forma salía diminuta
                  SizedBox(
                    width: 96,
                    height: 150,
                    child: RouteSilhouette.ofTrack(_points!, strokeWidth: 3.5),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          // Cuatro cifras en dos filas parejas (el tiempo total ya está arriba, en la hora)
          Row(
            children: [
              Expanded(child: _Figure(fmtDuration(s.moving), 'en movimiento')),
              const SizedBox(width: 8),
              Expanded(
                child: _Figure(
                  s.maxAltitude == null ? '–' : fmtInt(s.maxAltitude!),
                  'altitud máx.',
                  unit: 'm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Figure('+${fmtInt(s.gain)}', 'subida', unit: 'm'),
              ),
              const SizedBox(width: 8),
              Expanded(
                // "−0 m" parecía un error: sin signo cuando no hubo bajada
                child: _Figure(
                  s.loss.round() == 0 ? '0' : '−${fmtInt(s.loss)}',
                  'bajada',
                  unit: 'm',
                ),
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
          const SizedBox(height: 24),
          _Photos(trackId: t.id),
          if (_points != null && _points!.isEmpty) ...[
            TonalCard(
              accent: recordColor,
              child: Text(
                'Este recorrido no tiene ningún punto: el GPS no entregó tu posición mientras '
                'grababa. No hay nada que ver en el mapa ni que exportar. Puedes borrarlo desde el menú.',
                style: TextStyle(color: muted, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
      // Barra fija abajo (como "Add to bag | Free returns"): ver en el mapa y compartir. Antes
      // eran cinco botones grises apilados al final de la pantalla
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: GlowButton(
                  onPressed: _points == null || _points!.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => MapScreen(
                              expeditionId: t.expeditionId,
                              showTrackId: t.id,
                            ),
                          ),
                        ),
                  icon: Icons.map_outlined,
                  label: 'Ver en el mapa',
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton.tonalIcon(
                  onPressed: _points == null || _points!.isEmpty
                      ? null
                      : () => _share(t),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Compartir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Andes.surfaceHighest,
                    foregroundColor: Andes.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Todo lo que sale del teléfono, en un solo lugar: video, imagen, GPX y el recorte que
  /// se aplica a los tres.
  Future<void> _share(Track t) async {
    final pts = _points!;
    final many = pts.length > 1;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        Widget item(
          String id,
          IconData icon,
          String title,
          String subtitle, {
          bool enabled = true,
          Color? subtitleColor,
        }) => ListTile(
          enabled: enabled,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12.5, color: subtitleColor),
          ),
          onTap: () => Navigator.pop(context, id),
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text('COMPARTIR', style: labelStyle(context)),
              ),
              item(
                'video',
                Icons.movie_outlined,
                'Video en 3D',
                'Sobrevuelo del recorrido para historias.',
                enabled: many,
              ),
              item(
                'image',
                Icons.image_outlined,
                'Imagen',
                'La traza con tus cifras, sobre un color, una foto o el mapa.',
                enabled: many,
              ),
              item(
                'gpx',
                Icons.route_outlined,
                'Archivo GPX',
                'Para Wikiloc, Strava, Garmin Connect o Google Earth.',
              ),
              item(
                'trim',
                Icons.content_cut_rounded,
                'Recortar el inicio y el fin',
                t.trimmed
                    ? 'Se ocultan ${fmtDistance(t.hideStart)} al inicio y ${fmtDistance(t.hideEnd)} al final.'
                    : 'Hoy se ve completo, también dónde empieza y termina.',
                enabled: many,
                subtitleColor: t.trimmed ? Andes.cyan : null,
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'video':
        await _makeVideo(t);
      case 'image':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TrackImageScreen(track: t, points: pts),
          ),
        );
      case 'gpx':
        await _exportGpx(t);
      case 'trim':
        await _trim(t);
    }
  }

  Future<void> _exportGpx(Track t) async {
    final box = context.findRenderObject() as RenderBox?;
    final dir = await getTemporaryDirectory();
    final safe = t.name.replaceAll(RegExp(r'[^\w\- áéíóúñÁÉÍÓÚÑ]'), '').trim();
    final file = File('${dir.path}/${safe.isEmpty ? 'recorrido' : safe}.gpx');
    await file.writeAsString(toGpx(t, forSharing(t, _points!)));
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

  /// Elegir qué parte se ve al compartir (sin el inicio ni el fin, p. ej. tu casa).
  Future<void> _trim(Track t) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShareTrimScreen(track: t, points: _points!),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Elegir fondo, capas y velocidad, y abrir el mapa que genera el video.
  Future<void> _makeVideo(Track t) async {
    final store = AppScope.of(context).video;
    final options = await showVideoOptions(context, store.value);
    if (options == null || !mounted) return;
    await store.save(options);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          expeditionId: t.expeditionId,
          showTrackId: t.id,
          video: true,
          videoOptions: options,
        ),
      ),
    );
  }

  Future<void> _rename(Track t) async {
    final name = await askText(
      context,
      title: 'Nombre del recorrido',
      initial: t.name,
    );
    if (name == null || !mounted) return;
    t.name = name;
    await AppScope.of(context).tracks.save();
    setState(() {});
  }

  Future<void> _move(Track t) async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dest = await askTrackDestination(
      context,
      current: t.expeditionId,
      name: t.name,
      // Solo el día, como las demás expediciones
      date: DateUtils.dateOnly(t.startedAt.toLocal()),
    );
    if (dest == null || dest.expeditionId == t.expeditionId) return;
    await services.tracks.moveTo(t.id, dest.expeditionId);
    final e = services.expeditions.byId(dest.expeditionId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e == null
              ? 'Ahora es un recorrido libre.'
              : 'Ahora está en la expedición "${e.name}".',
        ),
      ),
    );
    if (mounted) setState(() {});
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
  const _Figure(this.value, this.label, {this.unit});
  final String value;
  final String label;
  final String? unit;

  // Sin barra de color: un solo acento por pantalla (el de los km)
  @override
  Widget build(BuildContext context) => TonalCard(
    padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Figure(value, label, unit: unit, size: 22),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TonalCard(
                  accent: t.status == TrackStatus.finished
                      ? Theme.of(context).colorScheme.primary
                      : recordColor,
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    leading: Icon(
                      t.status == TrackStatus.finished
                          ? Icons.route_rounded
                          : Icons.fiber_manual_record_rounded,
                      color: t.status == TrackStatus.finished
                          ? Theme.of(context).colorScheme.primary
                          : recordColor,
                    ),
                    title: Text(
                      t.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Fotos del recorrido en miniatura; tocar una la abre a pantalla completa.
class _Photos extends StatelessWidget {
  const _Photos({required this.trackId});
  final String trackId;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).photos;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final photos = store.forTrack(trackId);
        if (photos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('Fotos (${photos.length})'),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = photos[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Material(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PhotoScreen(trackId: trackId, photoId: p.id),
                          ),
                        ),
                        child: Ink.image(
                          image: ResizeImage(
                            FileImage(store.fileOf(p)),
                            width: 300,
                          ),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
