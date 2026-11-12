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
                icon: const Icon(Icons.badge_outlined),
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
            banners: [NetworkBanner(maps: services.maps)],
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text('BITÁCORA DE MONTAÑA', style: labelStyle(context)),
                const SizedBox(height: 6),
                Text('¿Qué quieres hacer?', style: signage(context, size: 30)),
                const SizedBox(height: 20),
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
                      Text(
                        '${items.length} · $ready ${ready == 1 ? 'lista' : 'listas'} sin conexión',
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
Future<Expedition?> askNewExpedition(BuildContext context) async {
  final result = await showModalBottomSheet<(String, DateTime?)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ExpeditionForm(),
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
        Readiness.ready => okColor,
        Readiness.downloading || Readiness.incomplete => warnColor,
        Readiness.noMaps => null,
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ReadinessChip(status),
              if (status.bytes > 0) _Telemetry(fmtBytes(status.bytes)),
              if (tracks > 0)
                _Telemetry(
                  '$tracks ${tracks == 1 ? 'recorrido' : 'recorridos'}',
                ),
            ],
          ),
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

/// La acción principal del inicio, como la tarjeta "Start new route" del diseño.
/// Abre el mapa sin expedición, para navegarlo y verlo en 2D o 3D.
/// Las cuatro cosas que se pueden hacer desde el inicio, de lo inmediato a lo planeado.
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
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.fiber_manual_record_rounded,
                color: recordColor,
                onColor: Andes.onTerracotta,
                label: 'Grabar',
                title: 'Desde aquí',
                body: 'Graba tu recorrido ya, sin preparar nada.',
                // Con uno en curso, el banner de arriba lleva a él
                onTap: recording
                    ? null
                    : () => _openMap(context, const MapScreen(record: true)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.map_rounded,
                color: Andes.cyan,
                onColor: Andes.onCyan,
                label: 'Explorar',
                title: 'Mapa libre',
                body: 'Navega en 2D o 3D y mira tus mapas descargados.',
                onTap: () => _openMap(context, const MapScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.route_rounded,
                color: Andes.gold,
                onColor: Andes.onGold,
                label: 'Trazar ruta',
                title: 'De A a B',
                body: 'Marca puntos en el mapa; se ajusta a los senderos.',
                onTap: recording
                    ? null
                    : () => _openMap(context, const MapScreen(plan: true)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.add_location_alt_rounded,
                color: Andes.cyanContainer,
                onColor: Andes.onCyan,
                label: 'Planear',
                title: 'Expedición',
                body: 'Zona, mapas sin señal, clima, equipo y hora límite.',
                onTap: () => startNewExpedition(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.onColor,
    required this.label,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final Color onColor;
  final String label;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        color: Andes.surfaceContainer,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: onColor, size: 22),
                ),
                const SizedBox(height: 14),
                Text(
                  label.toUpperCase(),
                  style: labelStyle(context, color: color),
                ),
                const SizedBox(height: 2),
                Text(title, style: signage(context, size: 19)),
                const SizedBox(height: 6),
                SizedBox(
                  // Misma altura en las cuatro aunque el texto ocupe 2 o 3 líneas
                  height: 52,
                  child: Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  const ExpeditionForm({super.key, this.initialName, this.initialDate});
  final String? initialName;
  final DateTime? initialDate;

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
    final editing = widget.initialName != null;
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
                firstDate: DateTime(now.year - 1),
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
