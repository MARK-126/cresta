import 'package:flutter/material.dart';

import '../app_services.dart';
import '../expeditions/expedition.dart';
import '../offline/offline_region.dart';
import 'area_picker_screen.dart';
import 'expeditions_screen.dart';
import 'format.dart';
import 'map_screen.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'theme.dart';

/// Detalle de una expedición: fecha, notas y sus mapas sin conexión.
class ExpeditionScreen extends StatelessWidget {
  const ExpeditionScreen({super.key, required this.expeditionId});
  final String expeditionId;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.expeditions;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final e = store.byId(expeditionId);
        if (e == null) {
          return const Scaffold(body: SizedBox.shrink()); // se acaba de borrar
        }
        final status = store.statusOf(e);
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(e.name, overflow: TextOverflow.ellipsis),
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: NetworkBanner(maps: services.maps),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 18,
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
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MapScreen(expeditionId: e.id),
                  ),
                ),
                icon: const Icon(Icons.terrain_rounded),
                label: const Text('Abrir mapa'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SectionTitle('Antes de salir'),
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
                  Readiness.noMaps =>
                    'Agrega la zona de la expedición y descárgala con Wi-Fi.',
                },
              ),
              _Check(
                done: e.routeAsset != null,
                title: 'Ruta',
                detail: e.routeAsset != null
                    ? 'Ruta cargada.'
                    : 'El planificador de rutas llega en una próxima versión.',
                pending: e.routeAsset == null,
              ),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Todavía no hay zonas descargadas para esta expedición.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 8),
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
              const SectionTitle('Notas'),
              _Notes(expedition: e),
            ],
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
    final navigator = Navigator.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Borrar "${e.name}"',
      body: 'Se borran la expedición y sus mapas descargados (salvo los que use otra expedición). No se puede deshacer.',
      action: 'Borrar',
    );
    if (!ok) return;
    navigator.pop();
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
  const _Check({
    required this.done,
    required this.title,
    required this.detail,
    this.pending = false,
  });
  final bool done;
  final bool pending;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : (pending
                      ? Icons.schedule_rounded
                      : Icons.radio_button_unchecked_rounded),
            color: done ? okColor : (pending ? muted : warnColor),
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
                    fontWeight: FontWeight.w600,
                    color: pending ? muted : null,
                  ),
                ),
                Text(detail, style: TextStyle(fontSize: 12.5, color: muted)),
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
      border: OutlineInputBorder(),
    ),
  );
}
