import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_services.dart';
import '../map/map_bridge.dart';
import '../map/map_layers.dart';
import '../offline/tile_math.dart';
import '../photos/photo_store.dart';
import '../share/track_image.dart';
import '../tracking/share_trim.dart';
import '../tracking/track.dart';
import 'format.dart';
import 'theme.dart';

/// Imagen para compartir (como las de Strava): la traza y algunas cifras sobre el mapa, una
/// foto, un color o fondo transparente (sticker para historias). PNG o JPG, a la galería.
/// Respeta el recorte para compartir.
class TrackImageScreen extends StatefulWidget {
  const TrackImageScreen({
    super.key,
    required this.track,
    required this.points,
  });
  final Track track;
  final List<TrackPoint> points;

  @override
  State<TrackImageScreen> createState() => _TrackImageScreenState();
}

class _TrackImageScreenState extends State<TrackImageScreen> {
  late final List<TrackPoint> _visible = forSharing(
    widget.track,
    widget.points,
  );
  // De inicio solo la traza sobre un color (pedido del usuario); el mapa es una opción
  ImageBackground _bg = ImageBackground.color;
  ImageAspect _aspect = ImageAspect.story;
  ImageSwatch _swatch = pizarraSwatch;
  ImageFormat _format = ImageFormat.png;
  final _stats = {
    ImageStat.distance,
    ImageStat.gain,
    ImageStat.time,
    ImageStat.date,
  };
  bool _profile = false;
  ui.Image? _photo;

  /// Oscurecer la foto de fondo (0 = tal cual).
  double _dim = .4;
  String? _photoId;
  bool _saving = false;

  /// Lugar o calle junto al inicio y al fin de lo que se ve (del mapa, sin señal).
  String? _from, _to;

  // El mapa de fondo: un WebView del tamaño de la vista previa (se captura tal cual)
  MapBridge? _bridge;
  bool _mapReady = false;
  MapBase _base = MapBase.night;

  /// Capas del mapa de fondo (las elige el usuario; los senderos se veían siempre y en la
  /// ciudad son banquetas). 'places' = íconos de lugares.
  final _mapLayers = {
    'trails': false,
    'contours': false,
    'labels': true,
    'places': false,
  };
  static const _mapLayerNames = {
    'trails': 'Senderos',
    'contours': 'Curvas de nivel',
    'labels': 'Nombres',
    'places': 'Lugares',
  };

  Future<void> _applyMapLayers() async {
    final bridge = _bridge;
    if (bridge == null) return;
    await bridge.setLayers({
      'track': true,
      'trails': _mapLayers['trails']!,
      'contours': _mapLayers['contours']!,
      'labels': _mapLayers['labels']!,
    });
    await bridge.setClean(!_mapLayers['places']!);
  }

  Size? _box;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bridge != null) return;
    final services = AppScope.of(context);
    _base = services.mapBase.value == MapBase.relief
        ? MapBase.night
        : services.mapBase.value;
    final bridge = _bridge = MapBridge();
    bridge.load(services.server.baseUri);
    bridge.ready.then((_) async {
      if (!mounted) return;
      await bridge.setBase(_base);
      await bridge.set3d(false);
      await _applyMapLayers();
      await bridge.setTrack(_visible, showEnd: true);
      // Primero los nombres (mueve la cámara, aún tapada) y después el encuadre
      final names = await bridge.findNames([_visible.first, _visible.last]);
      if (!mounted) return;
      _from = names[0];
      _to = names[1];
      await _frame();
      if (mounted) setState(() => _mapReady = true);
    });
  }

  @override
  void dispose() {
    _bridge?.dispose();
    super.dispose();
  }

  /// Encuadra la traza en el hueco que dejan el título arriba y las cifras abajo.
  /// Ancho (lógico) al que se dibuja el mapa de fondo: el de un teléfono, para que los
  /// nombres y las calles tengan el tamaño de siempre en la imagen.
  static const _mapWidth = 400.0;

  Future<void> _frame() async {
    final box = _box, bridge = _bridge;
    if (box == null || bridge == null) return;
    final u = _mapWidth / 1080;
    await bridge.setPadding(
      top: 130 * u, // ya sin título arriba
      bottom: (300 + (_profile ? 170 : 0)) * u,
      left: 70 * u,
      right: 70 * u,
    );
    await bridge.fitBounds(_bounds(_visible));
  }

  BBox _bounds(List<TrackPoint> pts) {
    var w = pts.first.lng, e = w, s = pts.first.lat, n = s;
    for (final p in pts) {
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
    }
    return BBox(w, s, e == w ? e + 0.001 : e, n == s ? n + 0.001 : n);
  }

  TrackImageData get _data {
    final t = widget.track, s = t.summary;
    final figures = <(String, String)>[
      for (final st in ImageStat.values)
        if (_stats.contains(st) && st.isFigure)
          if (_figure(st, s) case final v?) (st.label, v),
    ];
    return TrackImageData(
      date: fmtDate(t.startedAt),
      figures: figures,
      points: _visible,
      from: _from,
      to: _to,
    );
  }

  String? _figure(ImageStat st, TrackSummary s) => switch (st) {
    ImageStat.distance => '${fmtKm(s.meters, decimals: 2)} km',
    ImageStat.gain => '+${fmtInt(s.gain)} m',
    ImageStat.time => fmtDuration(s.moving),
    ImageStat.maxAltitude =>
      s.maxAltitude == null ? null : '${fmtInt(s.maxAltitude!)} m',
    _ => null,
  };

  TrackImagePainter _painter({ui.Image? background, bool preview = true}) =>
      TrackImagePainter(
        data: _data,
        background: _bg,
        swatch: _swatch,
        showDate: _stats.contains(ImageStat.date),
        showProfile: _profile,
        dim: _dim,
        backgroundImage:
            background ?? (_bg == ImageBackground.photo ? _photo : null),
        // En la vista previa con mapa, el mapa vivo va debajo
        paintBackground: !(preview && _bg == ImageBackground.map),
      );

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
    return (await codec.getNextFrame()).image;
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final image = await _decode(await x.readAsBytes());
    if (!mounted) return;
    setState(() {
      _photo = image;
      _photoId = null;
      _bg = ImageBackground.photo;
    });
  }

  Future<void> _useTrackPhoto(File f, String id) async {
    final image = await _decode(await f.readAsBytes());
    if (!mounted) return;
    setState(() {
      _photo = image;
      _photoId = id;
      _bg = ImageBackground.photo;
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final size = _aspect.pixels;
      ui.Image? bg;
      if (_bg == ImageBackground.map) {
        final png = await _bridge?.snapshot(size.width.round());
        if (png == null) throw Exception('no se pudo capturar el mapa');
        bg = await _decode(png);
      }
      final image = await renderTrackImage(
        _painter(background: bg, preview: false),
        size,
      );
      final jpg =
          _format == ImageFormat.jpg && _bg != ImageBackground.transparent;
      late final Uint8List bytes;
      if (jpg) {
        final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        bytes = await compute(_encodeJpg, (
          image.width,
          image.height,
          raw!.buffer.asUint8List(),
        ));
      } else {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = png!.buffer.asUint8List();
      }
      final dir = await getTemporaryDirectory();
      final safe = widget.track.name
          .replaceAll(RegExp(r'[^\w\- áéíóúñÁÉÍÓÚÑ]'), '')
          .trim();
      // Con la hora: con el mismo nombre la galería no guardaba la segunda imagen
      final now = DateTime.now();
      final stamp = [
        now.hour,
        now.minute,
        now.second,
      ].map((n) => n.toString().padLeft(2, '0')).join();
      final file = File(
        '${dir.path}/${safe.isEmpty ? 'recorrido' : safe} $stamp.${jpg ? 'jpg' : 'png'}',
      );
      await file.writeAsBytes(bytes, flush: true);
      String? galleryError;
      try {
        if (!await Gal.hasPermission(toAlbum: true)) {
          await Gal.requestPermission(toAlbum: true);
        }
        await Gal.putImage(file.path, album: 'Cresta');
      } on GalException catch (e) {
        galleryError = e.type == GalExceptionType.permissionDenied
            ? 'Sin permiso para guardar en la galería.'
            : 'No se pudo guardar en la galería.';
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            galleryError ?? 'Guardada en tu galería, álbum Cresta.',
          ),
          action: SnackBarAction(
            label: 'Compartir',
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                files: [
                  XFile(file.path, mimeType: jpg ? 'image/jpeg' : 'image/png'),
                ],
                subject: widget.track.name,
              ),
            ),
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo crear la imagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = AppScope.of(context).photos;
    final trackPhotos = photos.forTrack(widget.track.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Imagen del recorrido')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = math.min(c.maxWidth, c.maxHeight * _aspect.ratio);
                  final box = Size(w, w / _aspect.ratio);
                  if (_box != box) {
                    _box = box;
                    // Al cambiar el tamaño del recuadro, se vuelve a encuadrar
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _frame(),
                    );
                  }
                  return Center(
                    child: SizedBox.fromSize(
                      size: box,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // El mapa siempre montado (para no recargarlo); oculto si el
                            // fondo es otro
                            // El mapa se dibuja al ancho de un teléfono y se reduce: al
                            // tamaño del recuadro los nombres salían enormes en la imagen.
                            // Siempre cargado (los nombres de los extremos salen de él); con
                            // otro fondo queda tapado
                            ClipRect(
                              child: FittedBox(
                                child: SizedBox.fromSize(
                                  size: box * (_mapWidth / box.width),
                                  child: WebViewWidget(
                                    controller: _bridge!.controller,
                                  ),
                                ),
                              ),
                            ),
                            if (_bg == ImageBackground.transparent)
                              const CustomPaint(painter: _Checker()),
                            if (_bg == ImageBackground.photo && _photo == null)
                              const ColoredBox(
                                color: Andes.surfaceHigh,
                                child: Center(
                                  child: Text('Elige una foto abajo'),
                                ),
                              ),
                            IgnorePointer(
                              child: CustomPaint(painter: _painter()),
                            ),
                            if (_bg == ImageBackground.map && !_mapReady)
                              const ColoredBox(
                                color: Andes.surface,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * .4,
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  _label('FONDO'),
                  SegmentedButton<ImageBackground>(
                    segments: [
                      for (final b in ImageBackground.values)
                        ButtonSegment(
                          value: b,
                          label: Text(
                            b == ImageBackground.transparent
                                ? 'Sin fondo'
                                : b.label,
                          ),
                        ),
                    ],
                    selected: {_bg},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) {
                      setState(() => _bg = s.first);
                      if (s.first == ImageBackground.map) _frame();
                    },
                  ),
                  const SizedBox(height: 10),
                  ..._backgroundOptions(trackPhotos, photos.fileOf),
                  _label('TAMAÑO'),
                  SegmentedButton<ImageAspect>(
                    segments: [
                      for (final a in ImageAspect.values)
                        ButtonSegment(value: a, label: Text(a.label)),
                    ],
                    selected: {_aspect},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _aspect = s.first),
                  ),
                  _label('DATOS'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final st in ImageStat.values)
                        FilterChip(
                          label: Text(st.label),
                          selected: _stats.contains(st),
                          onSelected: (on) => setState(
                            () => on ? _stats.add(st) : _stats.remove(st),
                          ),
                        ),
                      FilterChip(
                        label: const Text('Perfil de altura'),
                        selected: _profile,
                        onSelected: (on) {
                          setState(() => _profile = on);
                          _frame();
                        },
                      ),
                    ],
                  ),
                  _label('FORMATO'),
                  SegmentedButton<ImageFormat>(
                    segments: [
                      const ButtonSegment(
                        value: ImageFormat.png,
                        label: Text('PNG'),
                      ),
                      ButtonSegment(
                        value: ImageFormat.jpg,
                        label: const Text('JPG'),
                        // JPG no guarda transparencia
                        enabled: _bg != ImageBackground.transparent,
                      ),
                    ],
                    selected: {
                      _bg == ImageBackground.transparent
                          ? ImageFormat.png
                          : _format,
                    },
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _format = s.first),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _bg == ImageBackground.transparent
                          ? 'Sin fondo solo en PNG: pégala como sticker en una historia.'
                          : 'PNG se ve más nítido; JPG pesa menos.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Andes.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (widget.track.trimmed)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Con tu recorte: no se ven ${fmtDistance(widget.track.hideStart)} del inicio ni ${fmtDistance(widget.track.hideEnd)} del final.',
                        style: const TextStyle(fontSize: 12, color: Andes.cyan),
                      ),
                    ),
                  const SizedBox(height: 16),
                  GlowButton(
                    label: _saving ? 'Creando…' : 'Guardar imagen',
                    icon: Icons.image_rounded,
                    onPressed:
                        _saving ||
                            (_bg == ImageBackground.photo && _photo == null) ||
                            (_bg == ImageBackground.map && !_mapReady)
                        ? null
                        : _save,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(s, style: labelStyle(context)),
  );

  List<Widget> _backgroundOptions(
    List<TrackPhoto> trackPhotos,
    File Function(TrackPhoto) fileOf,
  ) => switch (_bg) {
    ImageBackground.map => [
      Wrap(
        spacing: 8,
        children: [
          for (final b in [MapBase.night, MapBase.topo, MapBase.sat])
            ChoiceChip(
              label: Text(b.label),
              selected: _base == b,
              showCheckmark: false,
              onSelected: (_) {
                setState(() => _base = b);
                _bridge?.setBase(b);
              },
            ),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final e in _mapLayerNames.entries)
            FilterChip(
              label: Text(e.value),
              selected: _mapLayers[e.key]!,
              onSelected: (on) {
                setState(() => _mapLayers[e.key] = on);
                _applyMapLayers();
              },
            ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          'Mueve y acerca el mapa con los dedos para encuadrarlo.',
          style: TextStyle(fontSize: 12, color: Andes.onSurfaceVariant),
        ),
      ),
    ],
    ImageBackground.photo => [
      SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galería'),
            ),
            for (final p in trackPhotos)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => _useTrackPhoto(fileOf(p), p.id),
                  child: Opacity(
                    opacity: _photoId == p.id ? 1 : .7,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        fileOf(p),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (trackPhotos.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Las fotos de la derecha son las de este recorrido.',
            style: TextStyle(fontSize: 12, color: Andes.onSurfaceVariant),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Text(
              'Oscurecer ${(_dim * 100).round()} %',
              style: const TextStyle(fontSize: 13),
            ),
            Expanded(
              child: Slider(
                value: _dim,
                max: .8,
                divisions: 8,
                onChanged: (v) => setState(() => _dim = v),
              ),
            ),
          ],
        ),
      ),
    ],
    ImageBackground.color => [
      Wrap(
        spacing: 8,
        children: [
          for (final s in imageSwatches)
            ChoiceChip(
              avatar: CircleAvatar(backgroundColor: s.color, radius: 9),
              label: Text(s.name),
              selected: _swatch == s,
              showCheckmark: false,
              onSelected: (_) => setState(() => _swatch = s),
            ),
        ],
      ),
    ],
    ImageBackground.transparent => const [],
  };
}

/// JPG en otro hilo (en Dart puro tarda ~1 s en 1,080 × 1,920).
Uint8List _encodeJpg((int, int, Uint8List) a) {
  final (w, h, rgba) = a;
  final image = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: 90);
}

/// Cuadros grises: así se ve en la vista previa que no hay fondo.
class _Checker extends CustomPainter {
  const _Checker();

  @override
  void paint(Canvas canvas, Size size) {
    const s = 14.0;
    final a = Paint()..color = const Color(0xFF242B2D);
    final b = Paint()..color = const Color(0xFF1A2123);
    for (var y = 0.0; y < size.height; y += s) {
      for (var x = 0.0; x < size.width; x += s) {
        final odd = ((x / s).floor() + (y / s).floor()).isOdd;
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), odd ? a : b);
      }
    }
  }

  @override
  bool shouldRepaint(_Checker old) => false;
}
