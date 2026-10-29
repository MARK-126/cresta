import 'package:flutter/material.dart';

import '../app_services.dart';
import '../weather/weather_service.dart' show routeWeatherKey;
import '../expeditions/expedition.dart';
import '../offline/offline_region.dart';
import 'area_picker_screen.dart';
import 'expeditions_screen.dart';
import 'gear_screen.dart';
import 'format.dart';
import 'map_screen.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'references_section.dart';
import 'route_actions.dart';
import 'route_screen.dart';
import 'compare_screen.dart';
import 'sun_card.dart';
import 'weather_widgets.dart';
import 'theme.dart';
import 'track_screen.dart';

/// Detalle de una expedición: fecha, notas y sus mapas sin conexión.
class ExpeditionScreen extends StatelessWidget {
  const ExpeditionScreen({super.key, required this.expeditionId});
  final String expeditionId;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.expeditions;
    return ListenableBuilder(
      listenable: Listenable.merge([
        store,
        services.routes,
        services.weather,
        services.gear,
      ]),
      builder: (context, _) {
        final e = store.byId(expeditionId);
        if (e == null) {
          return const Scaffold(body: SizedBox.shrink()); // se acaba de borrar
        }
        final status = store.statusOf(e);
        final routes = services.routes.of(e.id);
        final route = routes.firstOrNull;
        final hasRoute = route != null || e.routeAsset != null;
        final weather = services.weather.forExpedition(e.id);
        final gear = services.gear.forExpedition(e.id);
        final packed = gear.where((i) => i.packed).length;
        // Un pronóstico de hace más de 2 días ya no sirve para decidir
        final weatherFresh =
            weather != null &&
            DateTime.now().difference(weather.fetchedAt) <
                const Duration(hours: 48);
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) =>
                    v == 'edit' ? _edit(context, e) : _delete(context, e),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar nombre y fecha'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Borrar expedición'),
                  ),
                ],
              ),
            ],
          ),
          body: WithBanners(
            banners: [NetworkBanner(maps: services.maps)],
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                Text(
                  e.sample ? 'EXPEDICIÓN DE EJEMPLO' : 'EXPEDICIÓN',
                  style: labelStyle(context, color: Andes.gold),
                ),
                const SizedBox(height: 6),
                Text(e.name, style: signage(context, size: 32)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.date == null
                          ? 'Sin fecha de salida'
                          : '${fmtDate(e.date!)} · ${fmtRelativeDay(e.date!)}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GlowButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MapScreen(expeditionId: e.id),
                    ),
                  ),
                  icon: Icons.terrain_rounded,
                  label: 'Abrir mapa',
                ),
                const SectionTitle('Antes de salir'),
                TonalCard(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                  child: Column(
                    children: [
                      _Check(
                        done: status.readiness == Readiness.ready,
                        title: 'Mapas sin conexión',
                        detail: switch (status.readiness) {
                          Readiness.ready =>
                            'Todo descargado (${fmtBytes(status.bytes)}). Funciona sin señal.',
                          Readiness.downloading =>
                            'Descargando: ${(status.progress * 100).floor()} %. Mantén la app abierta.',
                          Readiness.incomplete =>
                            'Hay zonas a medias. Reanúdalas con conexión.',
                          Readiness.noMaps => 'Agrega la zona de la expedición y descárgala con Wi-Fi.',
                        },
                      ),
                      _Check(
                        done: hasRoute,
                        title: 'Ruta',
                        detail: route != null
                            ? '${route.name}: ${route.profile.summary}.'
                            : hasRoute
                            ? 'Ruta de ejemplo cargada.'
                            : 'Planéala en el mapa o importa un GPX o KML.',
                      ),
                      _Check(
                        done: weatherFresh,
                        title: 'Clima',
                        detail: weather == null
                            ? 'Consúltalo con conexión: queda guardado para la montaña.'
                            : weatherFresh
                            ? 'Pronóstico guardado ${fmtUpdated(weather.fetchedAt)}.'
                            : 'Consultado ${fmtUpdated(weather.fetchedAt)}: actualízalo antes de salir.',
                      ),
                      _Check(
                        done: gear.isNotEmpty && packed == gear.length,
                        title: 'Equipo',
                        detail: gear.isEmpty
                            ? 'Arma la lista desde una plantilla.'
                            : packed == gear.length
                            ? 'Todo empacado (${gear.length} objetos).'
                            : 'Faltan ${gear.length - packed} de ${gear.length} por empacar.',
                      ),
                      _TurnaroundCheck(expedition: e),
                    ],
                  ),
                ),
                const SectionTitle('Luz del día'),
                SunCard(expedition: e),
                const SectionTitle('Ruta'),
                if (routes.isNotEmpty)
                  for (final r in routes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RouteSummaryCard(routeId: r.id),
                    )
                else
                  Text(
                    e.routeAsset != null
                        ? 'Esta expedición usa la ruta de ejemplo. Puedes ajustarla en el mapa o reemplazarla con un GPX o KML.'
                        : 'Toca el mapa para trazarla (sigue los senderos descargados) o importa la de Wikiloc, Garmin, Google Earth…',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                if (routes.length >= 2)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CompareScreen(
                            initial: [for (final r in routes) r.id],
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                      label: const Text('Comparar rutas'),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                MapScreen(expeditionId: e.id, plan: true),
                          ),
                        ),
                        icon: const Icon(Icons.edit_road_rounded),
                        label: Text(hasRoute ? 'Editar' : 'Planear'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => importRouteFile(context, e.id),
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('GPX o KML'),
                      ),
                    ),
                  ],
                ),
                const SectionTitle('Equipo'),
                GearCard(expeditionId: e.id),
                const SectionTitle('Clima'),
                WeatherCard(expedition: e, route: route?.profile),
                SectionTitle(
                  'Mapas sin conexión',
                  trailing: status.bytes > 0
                      ? Text(
                          fmtBytes(status.bytes),
                          style: dataStyle(context, size: 11),
                        )
                      : null,
                ),
                for (final r in status.regions)
                  RegionTile(
                    region: r,
                    maps: services.maps,
                    onDelete: () => _removeRegion(context, e, r),
                  ),
                if (status.regions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Todavía no hay zonas descargadas para esta expedición.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AreaPickerScreen(expeditionId: e.id),
                    ),
                  ),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Agregar zona de mapas'),
                ),
                const SectionTitle('Recorridos grabados'),
                TrackList(expeditionId: e.id),
                const SectionTitle('Referencias'),
                ReferencesSection(expeditionId: e.id),
                const SectionTitle('Notas'),
                _Notes(expedition: e),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, Expedition e) async {
    final store = AppScope.of(context).expeditions;
    final result = await showModalBottomSheet<(String, DateTime?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExpeditionForm(initialName: e.name, initialDate: e.date),
    );
    if (result == null) return;
    await store.update(
      e,
      name: result.$1,
      date: result.$2,
      clearDate: result.$2 == null,
    );
  }

  Future<void> _delete(BuildContext context, Expedition e) async {
    final store = AppScope.of(context).expeditions;
    final services = AppScope.of(context);
    final navigator = Navigator.of(context);
    if (services.recorder.track?.expeditionId == e.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Termina el recorrido en curso antes de borrar la expedición.',
          ),
        ),
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Borrar "${e.name}"',
      body: 'Se borran la expedición, su ruta, su clima, su equipo, sus referencias, sus recorridos grabados y sus mapas descargados (salvo los que use otra expedición). No se puede deshacer.',
      action: 'Borrar',
    );
    if (!ok) return;
    navigator.pop();
    await services.tracks.deleteForExpedition(e.id);
    for (final r in services.routes.of(e.id)) {
      await services.weather.delete(routeWeatherKey(r.id));
    }
    await services.routes.deleteOf(e.id);
    await services.weather.delete(e.id);
    await services.gear.deleteExpedition(e.id);
    await services.references.deleteExpedition(e.id);
    await store.delete(e, deleteMaps: true);
  }

  Future<void> _removeRegion(
    BuildContext context,
    Expedition e,
    OfflineRegion r,
  ) async {
    final store = AppScope.of(context).expeditions;
    final others = store.usingRegion(r.id).where((x) => x.id != e.id).length;
    final ok = await confirmDialog(
      context,
      title: 'Quitar "${r.name}"',
      body: others > 0
          ? 'La zona se quita de esta expedición. Sus mapas se conservan porque los usa otra expedición.'
          : 'Se borran sus mapas del teléfono (${fmtBytes(r.bytes)}). Para volver a tenerlos hay que descargarlos de nuevo.',
      action: 'Quitar',
    );
    if (ok) await store.detachRegion(e, r.id);
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.done, required this.title, required this.detail});
  final bool done;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? okColor : warnColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: done ? null : warnColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(fontSize: 12.5, color: muted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notes extends StatefulWidget {
  const _Notes({required this.expedition});
  final Expedition expedition;

  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  late final _ctrl = TextEditingController(text: widget.expedition.notes);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  void _save() {
    if (_ctrl.text != widget.expedition.notes) {
      AppScope.of(context).expeditions
          .update(widget.expedition, notes: _ctrl.text);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    focusNode: _focus,
    minLines: 3,
    maxLines: 8,
    textCapitalization: TextCapitalization.sentences,
    decoration: const InputDecoration(
      hintText: 'Permisos, punto de encuentro, teléfonos útiles…',
    ),
  );
}

/// Hora límite de retorno: si a esa hora no llegaste a la cumbre, se regresa.
class _TurnaroundCheck extends StatelessWidget {
  const _TurnaroundCheck({required this.expedition});
  final Expedition expedition;

  @override
  Widget build(BuildContext context) {
    final m = expedition.turnaroundMinutes;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final text = m == null
        ? null
        : '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final store = AppScope.of(context).expeditions;
        final picked = await showTimePicker(
          context: context,
          helpText: 'Hora límite para regresar',
          initialTime: TimeOfDay(
            hour: m == null ? 11 : m ~/ 60,
            minute: m == null ? 0 : m % 60,
          ),
        );
        if (picked != null) {
          await store.update(
            expedition,
            turnaroundMinutes: picked.hour * 60 + picked.minute,
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              m == null
                  ? Icons.radio_button_unchecked_rounded
                  : Icons.check_circle_rounded,
              color: m == null ? warnColor : okColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hora límite de retorno',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: m == null ? warnColor : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text == null
                        ? 'Toca para fijarla. Si a esa hora no llegaste, regresas; la app te avisa mientras grabas.'
                        : 'A las $text, aunque no hayas llegado a la cumbre. Toca para cambiarla.',
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                ],
              ),
            ),
            if (text != null)
              Text(
                text,
                style: dataStyle(
                  context,
                  size: 20,
                  weight: FontWeight.w800,
                  color: Andes.gold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Resumen de una ruta guardada; abre su detalle.
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({super.key, required this.routeId});
  final String routeId;

  @override
  Widget build(BuildContext context) {
    final route = AppScope.of(context).routes.byId(routeId);
    if (route == null) return const SizedBox.shrink();
    final r = route.profile;
    return TonalCard(
      accent: Andes.gold,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => RouteScreen(routeId: routeId)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(route.name, style: signage(context, size: 19)),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Figure(fmtKm(r.totalMeters), 'km', size: 18)),
              Expanded(
                child: Figure(
                  '+${fmtInt(r.gain)}',
                  'desnivel',
                  unit: 'm',
                  size: 18,
                ),
              ),
              Expanded(
                child: Figure(
                  fmtDuration(r.estimatedTime),
                  'estimado',
                  size: 18,
                ),
              ),
            ],
          ),
          if (route.pois.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${route.pois.length} ${route.pois.length == 1 ? 'punto de interés' : 'puntos de interés'}',
              style: labelStyle(context).copyWith(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
