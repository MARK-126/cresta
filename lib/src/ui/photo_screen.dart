import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../photos/photo_store.dart';
import 'format.dart';
import 'offline_widgets.dart' show confirmDialog;
import 'theme.dart';

/// Fotos de un recorrido a pantalla completa (con zoom), deslizando de una a otra.
class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key, required this.trackId, required this.photoId});
  final String trackId;
  final String photoId;

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  PageController? _pages;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pages != null) return;
    final photos = AppScope.of(context).photos.forTrack(widget.trackId);
    _index = photos.indexWhere((p) => p.id == widget.photoId).clamp(0, 1 << 20);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  Future<void> _delete(TrackPhoto p) async {
    final store = AppScope.of(context).photos;
    final navigator = Navigator.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Borrar foto',
      body: 'Se borra del recorrido y del teléfono. No se puede deshacer.',
      action: 'Borrar',
    );
    if (!ok) return;
    await store.delete(p);
    if (store.forTrack(widget.trackId).isEmpty) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).photos;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final photos = store.forTrack(widget.trackId);
        if (photos.isEmpty) return const Scaffold(body: SizedBox.shrink());
        final i = _index.clamp(0, photos.length - 1);
        final p = photos[i];
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              photos.length == 1 ? 'Foto' : 'Foto ${i + 1} de ${photos.length}',
            ),
            actions: [
              IconButton(
                tooltip: 'Compartir',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(files: [XFile(store.fileOf(p).path)]),
                ),
              ),
              IconButton(
                tooltip: 'Borrar',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _delete(p),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: photos.length,
                  onPageChanged: (k) => setState(() => _index = k),
                  itemBuilder: (_, k) => InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: Image.file(
                        store.fileOf(photos[k]),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: Andes.cyan,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${fmtDate(p.time)} · ${fmtTime(p.time)}',
                        style: dataStyle(context),
                      ),
                      const Spacer(),
                      if (p.altitude != null) ...[
                        const Icon(
                          Icons.terrain_rounded,
                          size: 18,
                          color: Andes.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${fmtInt(p.altitude!)} m',
                          style: dataStyle(context),
                        ),
                      ] else if (!p.located)
                        Text(
                          'Sin ubicación',
                          style: dataStyle(
                            context,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
