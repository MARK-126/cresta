import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../expeditions/expedition.dart';
import 'compare_screen.dart';
import 'expedition_screen.dart';
import 'format.dart';
import 'offline_widgets.dart';
import '../tracking/track_recorder.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'recording_panel.dart';
import 'sos_screen.dart';
import 'theme.dart';

/// Inicio: qué hacer (grabar, explorar, trazar, planear) y las expediciones.
class ExpeditionsScreen extends StatelessWidget {
  const ExpeditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.expeditions;
    return ListenableBuilder(
      listenable: Listenable.merge([store, services.recorder, services.routes]),
      builder: (context, _) {
        final items = store.all;
        final ready = items
            .where((e) => store.statusOf(e).readiness == Readiness.ready)
            .length;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 24,
            title: const CrestaWordmark(size: 24),
            actions: [
              IconButton(
                tooltip: 'Perfil de emergencia',
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => openProfile(context),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 4),
                child: _SosButton(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const SosScreen()),
                  ),
                ),
              ),
            ],
          ),
          body: WithBanners(
            banners: [
              NetworkBanner(maps: services.maps),
              StaleMapsBanner(maps: services.maps),
            ],
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Arriba solo la fecha (decía "Bitácora de montaña", que es otra pestaña)
                Text(
                  fmtDate(DateTime.now()).toUpperCase(),
                  style: labelStyle(context),
                ),
                const SizedBox(height: 12),
                if (services.recorder.isActive) ...[
                  _RecordingBanner(services: services),
                  const SizedBox(height: 12),
                ],
                _Actions(services: services),
                const SizedBox(height: 28),
                if (items.isEmpty)
                  const _Empty()
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('TUS EXPEDICIONES', style: labelStyle(context)),
                      const Spacer(),
                      // Solo se avisa lo que falta: "lista sin conexión" en cada una era ruido
                      Text(
                        ready == items.length
                            ? '${items.length}'
                            : '${items.length} · ${items.length - ready} sin mapas listos',
                        style: dataStyle(
                          context,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final e in items) ...[
                    _ExpeditionCard(expedition: e),
                    const SizedBox(height: 10),
                  ],
                ],
                ..._looseRoutes(context, services),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pide nombre y fecha y crea la expedición; null si el usuario cancela.
/// [name] y [date] llenan el formulario de antemano (p. ej. con los de un recorrido).
Future<Expedition?> askNewExpedition(
  BuildContext context, {
  String? name,
  DateTime? date,
}) async {
  final result = await showModalBottomSheet<(String, DateTime?)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ExpeditionForm(initialName: name, initialDate: date),
  );
  if (result == null || !context.mounted) return null;
  return AppScope.of(context).expeditions
      .create(name: result.$1, date: result.$2);
}

/// Crea una expedición y abre su pantalla. Con [replace] reemplaza la pantalla actual
/// (p. ej. el mapa libre) en lugar de apilarse sobre ella.
Future<void> startNewExpedition(
  BuildContext context, {
  bool replace = false,
}) async {
  final e = await askNewExpedition(context);
  if (e == null || !context.mounted) return;
  final route = MaterialPageRoute<void>(
    builder: (_) => ExpeditionScreen(expeditionId: e.id),
  );
  if (replace) {
    Navigator.pushReplacement(context, route);
  } else {
    Navigator.push(context, route);
  }
}

/// Rutas guardadas que no pertenecen a ninguna expedición.
List<Widget> _looseRoutes(BuildContext context, AppServices services) {
  final loose = [
    for (final r in services.routes.all)
      if (r.expeditionId == null) r,
  ];
  final canCompare = services.routes.all.length >= 2;
  if (loose.isEmpty && !canCompare) return const [];
  return [
    const SizedBox(height: 18),
    Row(
      children: [
        Expanded(
          child: Text(
            loose.isEmpty ? 'RUTAS' : 'RUTAS GUARDADAS',
            style: labelStyle(context),
          ),
        ),
        if (canCompare)
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CompareScreen()),
            ),
            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
            label: const Text('Comparar'),
          ),
      ],
    ),
    const SizedBox(height: 6),
    for (final r in loose)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RouteSummaryCard(routeId: r.id),
      ),
  ];
}

class _ExpeditionCard extends StatelessWidget {
  const _ExpeditionCard({required this.expedition});
  final Expedition expedition;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final status = services.expeditions.statusOf(expedition);
    final scheme = Theme.of(context).colorScheme;
    final e = expedition;
    final tracks = services.tracks.forExpedition(e.id).length;
    return TonalCard(
      accent: switch (status.readiness) {
        Readiness.downloading || Readiness.incomplete => warnColor,
        Readiness.ready || Readiness.noMaps => null,
      },
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ExpeditionScreen(expeditionId: e.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(e.name, style: signage(context, size: 21))),
              if (e.sample)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: _Tag('Ejemplo'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            e.date == null
                ? 'Sin fecha'
                : '${fmtDate(e.date!)} · ${fmtRelativeDay(e.date!)}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          if (status.readiness != Readiness.ready || tracks > 0) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (status.readiness != Readiness.ready) ReadinessChip(status),
                if (tracks > 0)
                  _Telemetry(
                    '$tracks ${tracks == 1 ? 'recorrido' : 'recorridos'}',
                  ),
              ],
            ),
          ],
          if (status.readiness == Readiness.downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: status.progress,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip de telemetría: dato pequeño y denso sobre el tono más alto.
class _Telemetry extends StatelessWidget {
  const _Telemetry(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Andes.surfaceHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text.toUpperCase(),
      style: labelStyle(context).copyWith(fontSize: 10.5, letterSpacing: 1.0),
    ),
  );
}

/// Lo que se puede hacer desde el inicio. Grabar es la protagonista (es lo que se usa en
/// el terreno), enorme y en terracota; las otras tres, chicas y sin frases de ayuda.
class _Actions extends StatelessWidget {
  const _Actions({required this.services});
  final AppServices services;

  void _openMap(BuildContext context, MapScreen screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final recording = services.recorder.isActive;
    return Column(
      children: [
        _RecordHero(
          // Con uno en curso, el banner de arriba lleva a él
          onTap: recording
              ? null
              : () => _openMap(context, const MapScreen(record: true)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.map_rounded,
                label: 'Explorar',
                onTap: () => _openMap(context, const MapScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.route_rounded,
                label: 'Trazar ruta',
                onTap: recording
                    ? null
                    : () => _openMap(context, const MapScreen(plan: true)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.add_location_alt_rounded,
                label: 'Expedición',
                onTap: () => startNewExpedition(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "GRABAR" en grande sobre terracota, como el botón de llamar del SOS.
class _RecordHero extends StatelessWidget {
  const _RecordHero({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .45 : 1,
    child: Semantics(
      button: true,
      label: 'Grabar recorrido desde aquí',
      child: Material(
        color: recordColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GRABAR',
                        style: display(
                          context,
                          size: 76,
                          color: Andes.onTerracotta,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DESDE AQUÍ · SIN SEÑAL',
                        style: labelStyle(
                          context,
                          color: Andes.onTerracotta.withValues(alpha: .75),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Andes.onTerracotta,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fiber_manual_record_rounded,
                    color: recordColor,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap != null ? 1 : .45,
    child: Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: Andes.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Andes.cyan, size: 26),
              const SizedBox(height: 12),
              Text(label, style: signage(context, size: 16)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: .6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return TonalCard(
      color: Andes.surfaceLow,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.terrain_rounded, size: 32, color: muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aún no tienes expediciones',
                  style: signage(context, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Crea una, elige la zona en el mapa y descarga sus mapas con Wi-Fi para usarlos sin señal en la montaña.',
                  style: TextStyle(color: muted, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulario para crear o editar el nombre y la fecha de una expedición.
class ExpeditionForm extends StatefulWidget {
  const ExpeditionForm({
    super.key,
    this.initialName,
    this.initialDate,
    this.editing = false,
  });
  final String? initialName;
  final DateTime? initialDate;

  /// Edita una expedición que ya existe (no solo llena el formulario de antemano).
  final bool editing;

  @override
  State<ExpeditionForm> createState() => _ExpeditionFormState();
}

class _ExpeditionFormState extends State<ExpeditionForm> {
  late final _name = TextEditingController(text: widget.initialName);
  late DateTime? _date = widget.initialDate;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name, _date));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing ? 'Editar expedición' : 'Nueva expedición',
            style: signage(context, size: 22),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Nevado de Toluca, 2 días',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.event_rounded),
            label: Text(
              _date == null ? 'Agregar fecha de salida' : fmtDate(_date!),
            ),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? now,
                // Un recorrido viejo pasado a una expedición trae su propia fecha
                firstDate: DateTime(
                  math.min(now.year - 1, _date?.year ?? now.year),
                ),
                lastDate: DateTime(now.year + 3),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: _name,
            builder: (context, _) => FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : _submit,
              child: Text(editing ? 'Guardar' : 'Crear expedición'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recordatorio de que hay un recorrido grabándose (o en pausa); lleva de vuelta al mapa.
class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner({required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final r = services.recorder;
    final e = services.expeditions.byId(r.track!.expeditionId);
    final paused = r.state == RecorderState.paused;
    return TonalCard(
      accent: recordColor,
      color: recordColor.withValues(alpha: .1),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          // Sin expedición: el recorrido libre se sigue en el mapa libre
          builder: (_) => MapScreen(expeditionId: e?.id),
        ),
      ),
      child: Row(
        children: [
          Icon(
            paused
                ? Icons.pause_circle_outline_rounded
                : Icons.fiber_manual_record_rounded,
            color: recordColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paused ? 'RECORRIDO EN PAUSA' : 'GRABANDO',
                  style: labelStyle(context, color: recordColor),
                ),
                const SizedBox(height: 2),
                Text(
                  '${e?.name ?? 'Recorrido libre'} · ${fmtKm(r.stats.meters)} km',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

/// Acceso rápido a la pantalla de auxilio.
class _SosButton extends StatelessWidget {
  const _SosButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Andes.terracottaContainer.withValues(alpha: .16),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          'SOS',
          style: labelStyle(
            context,
            color: Andes.terracottaContainer,
          ).copyWith(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
    ),
  );
}
