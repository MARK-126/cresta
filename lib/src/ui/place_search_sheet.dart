import 'package:flutter/material.dart';

import '../app_services.dart';
import '../places/places.dart';
import '../search/place_search.dart';
import '../tracking/backtrack.dart' show bearingDeg, cardinal;
import 'format.dart';
import 'theme.dart';

IconData placeIcon(PlaceKind k) => switch (k) {
  PlaceKind.peak || PlaceKind.saddle => Icons.landscape_rounded,
  PlaceKind.volcano => Icons.volcano_rounded,
  PlaceKind.hut => Icons.house_siding_rounded,
  PlaceKind.water => Icons.water_drop_rounded,
  PlaceKind.lake => Icons.water_rounded,
  PlaceKind.camp => Icons.cabin_outlined,
  PlaceKind.viewpoint => Icons.visibility_outlined,
  PlaceKind.town || PlaceKind.hamlet => Icons.holiday_village_outlined,
  PlaceKind.trail => Icons.hiking_rounded,
  PlaceKind.river => Icons.waves_rounded,
  PlaceKind.park => Icons.park_outlined,
  PlaceKind.police => Icons.local_police_outlined,
  PlaceKind.health => Icons.medical_services_outlined,
  PlaceKind.parking => Icons.local_parking_rounded,
  PlaceKind.other => Icons.place_outlined,
};

/// "Cumbre · 3,460 m".
String placeDetail(MapPlace p) =>
    p.ele == null ? p.kind.label : '${p.kind.label} · ${fmtInt(p.ele!)} m';

/// "7.7 km al NO" desde donde estás (o desde el centro del mapa).
String placeDistance(MapPlace p, double meters, double lat, double lng) {
  final dist = meters < 1000 ? '${fmtInt(meters)} m' : '${fmtKm(meters)} km';
  return '$dist al ${cardinal(bearingDeg(lat, lng, p.lat, p.lng))}';
}

/// Busca en los mapas descargados (sin señal). [lat], [lng]: desde dónde medir distancias
/// ([fromMe]: tu posición; si no, el centro del mapa). Devuelve el lugar elegido.
///
/// Para trazar rutas: [title] cambia el encabezado, [offerMe] agrega "Tu ubicación" como
/// primera opción (si [fromMe]) y [online] permite buscar en todo el mundo con conexión.
Future<MapPlace?> showPlaceSearch(
  BuildContext context, {
  double? lat,
  double? lng,
  bool fromMe = false,
  String title = 'Buscar en tus mapas',
  bool offerMe = false,
  bool online = false,
}) => showModalBottomSheet<MapPlace>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PlaceSearch(
    lat: lat,
    lng: lng,
    fromMe: fromMe,
    title: title,
    offerMe: offerMe && fromMe && lat != null && lng != null,
    online: online,
  ),
);

/// Convierte un resultado de la búsqueda en línea (Nominatim).
MapPlace _fromOnline(Place p) => MapPlace(
  p.name,
  switch (p.kind) {
    'Cumbre' => PlaceKind.peak,
    'Volcán' => PlaceKind.volcano,
    'Refugio' => PlaceKind.hut,
    _ => PlaceKind.other,
  },
  p.lng,
  p.lat,
);

class _PlaceSearch extends StatefulWidget {
  const _PlaceSearch({
    this.lat,
    this.lng,
    required this.fromMe,
    required this.title,
    required this.offerMe,
    required this.online,
  });
  final double? lat;
  final double? lng;
  final bool fromMe;
  final String title;
  final bool offerMe;
  final bool online;

  @override
  State<_PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<_PlaceSearch> {
  final _query = TextEditingController();
  Future<List<MapPlace>>? _places;

  // Búsqueda en todo el mundo (solo con conexión y al confirmar: lo pide Nominatim)
  final _search = PlaceSearch();
  List<Place>? _onlineHits;
  String? _onlineQuery;
  String? _onlineError;
  bool _onlineBusy = false;

  Future<void> _searchOnline() async {
    final q = _query.text.trim();
    if (q.isEmpty || _onlineBusy) return;
    setState(() {
      _onlineBusy = true;
      _onlineError = null;
    });
    try {
      final hits = await _search.search(q);
      if (!mounted) return;
      setState(() {
        _onlineHits = hits;
        _onlineQuery = q;
      });
    } on Object {
      if (mounted) {
        setState(
          () => _onlineError = 'No se pudo buscar en línea. ¿Hay conexión?',
        );
      }
    } finally {
      if (mounted) setState(() => _onlineBusy = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _places ??= AppScope.of(context).places.places();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(widget.title, style: signage(context, size: 24)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Cumbres, refugios, agua, pueblos y senderos de tus zonas descargadas. Funciona sin señal.',
                style: TextStyle(color: muted, fontSize: 13, height: 1.35),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: widget.online ? (_) => _searchOnline() : null,
                decoration: InputDecoration(
                  hintText: 'Cerro, refugio, agua…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_query.clear),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<MapPlace>>(
                future: _places,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _Message(
                      'No se pudieron leer tus mapas.',
                      '${snap.error}',
                    );
                  }
                  if (!snap.hasData) {
                    return const _Message(
                      'Preparando la búsqueda…',
                      'Solo la primera vez y cuando descargas o actualizas una zona.',
                      busy: true,
                    );
                  }
                  final all = snap.data!;
                  if (all.isEmpty && !widget.online && !widget.offerMe) {
                    return const _Message(
                      'Aún no hay mapas descargados.',
                      'Descarga una zona (pestaña Mapas o desde una expedición) y aquí podrás buscar en ella sin señal.',
                    );
                  }
                  return _results(context, all);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(BuildContext context, List<MapPlace> all) {
    final q = _query.text.trim();
    final hits = searchPlaces(all, q, lat: widget.lat, lng: widget.lng);
    final online = widget.online && q.isNotEmpty;
    final extras = <Widget>[
      if (widget.offerMe && q.isEmpty)
        ListTile(
          leading: const Icon(Icons.my_location_rounded, color: Andes.cyan),
          title: const Text('Tu ubicación'),
          subtitle: const Text('Donde estás ahora'),
          onTap: () => Navigator.pop(
            context,
            MapPlace('Tu ubicación', PlaceKind.other, widget.lng!, widget.lat!),
          ),
        ),
      if (online) ..._onlineSection(context, q),
    ];
    if (hits.isEmpty && extras.isEmpty) {
      return _Message(
        q.isEmpty ? 'Nada cerca.' : 'Sin resultados para "$q".',
        all.isEmpty
            ? 'Descarga una zona (pestaña Mapas o desde una expedición) para buscar en ella sin señal.'
            : 'Solo se busca en tus zonas descargadas.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      children: [
        if (q.isEmpty) ...extras,
        if (hits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Text(
              q.isNotEmpty
                  ? '${hits.length} ${hits.length == 1 ? 'LUGAR' : 'LUGARES'}'
                  : widget.fromMe
                  ? 'CERCA DE TI'
                  : 'CERCA DEL CENTRO DEL MAPA',
              style: labelStyle(context),
            ),
          ),
        if (q.isNotEmpty && hits.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Text(
              'Nada en tus mapas descargados.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final h in hits)
          ListTile(
            leading: Icon(placeIcon(h.place.kind)),
            title: Text(h.place.name),
            subtitle: Text(
              [
                placeDetail(h.place),
                if (h.meters != null)
                  placeDistance(h.place, h.meters!, widget.lat!, widget.lng!),
              ].join(' · '),
            ),
            onTap: () => Navigator.pop(context, h.place),
          ),
        if (q.isNotEmpty) ...extras,
      ],
    );
  }

  /// "Buscar en todo el mundo" y sus resultados (con conexión).
  List<Widget> _onlineSection(BuildContext context, String q) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final hits = _onlineQuery == q ? _onlineHits : null;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
        child: Text('EN TODO EL MUNDO', style: labelStyle(context)),
      ),
      if (hits == null)
        ListTile(
          leading: _onlineBusy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.public_rounded),
          title: Text('Buscar "$q" en línea'),
          subtitle: Text(_onlineError ?? 'Necesita conexión'),
          onTap: _searchOnline,
        )
      else if (hits.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Text(
            'Sin resultados en línea.',
            style: TextStyle(color: muted),
          ),
        )
      else
        for (final p in hits)
          ListTile(
            leading: const Icon(Icons.public_rounded),
            title: Text(p.name),
            subtitle: Text(
              [p.kind, p.detail].where((s) => s.isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.pop(context, _fromOnline(p)),
          ),
    ];
  }
}

class _Message extends StatelessWidget {
  const _Message(this.title, this.body, {this.busy = false});
  final String title;
  final String body;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          if (busy) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}
