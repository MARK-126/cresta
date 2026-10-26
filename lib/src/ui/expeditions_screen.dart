import 'package:flutter/material.dart';

import '../app_services.dart';
import '../expeditions/expedition.dart';
import 'expedition_screen.dart';
import 'format.dart';
import 'offline_widgets.dart';
import '../tracking/track_recorder.dart';
import 'map_screen.dart';
import 'recording_panel.dart';
import 'theme.dart';

/// Inicio: la lista de expediciones.
class ExpeditionsScreen extends StatelessWidget {
  const ExpeditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.expeditions;
    return ListenableBuilder(
      listenable: Listenable.merge([store, services.recorder]),
      builder: (context, _) {
        final items = store.all;
        final ready = items
            .where((e) => store.statusOf(e).readiness == Readiness.ready)
            .length;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 24,
            title: const CrestaWordmark(size: 24),
          ),
          body: WithBanners(
            banners: [NetworkBanner(maps: services.maps)],
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text('BITÁCORA DE MONTAÑA', style: labelStyle(context)),
                const SizedBox(height: 6),
                Text(
                  items.isEmpty ? 'Tu primera cumbre' : 'Expediciones',
                  style: signage(context, size: 34),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${items.length} en total · $ready ${ready == 1 ? 'lista' : 'listas'} sin conexión',
                    style: dataStyle(
                      context,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (services.recorder.isActive) ...[
                  _RecordingBanner(services: services),
                  const SizedBox(height: 12),
                ],
                _NewExpeditionCard(onTap: () => _create(context)),
                const SizedBox(height: 28),
                if (items.isEmpty)
                  const _Empty()
                else ...[
                  Text('TUS EXPEDICIONES', style: labelStyle(context)),
                  const SizedBox(height: 12),
                  for (final e in items) ...[
                    _ExpeditionCard(expedition: e),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _create(BuildContext context) async {
    final result = await showModalBottomSheet<(String, DateTime?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ExpeditionForm(),
    );
    if (result == null || !context.mounted) return;
    final e = await AppScope.of(context).expeditions
        .create(name: result.$1, date: result.$2);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ExpeditionScreen(expeditionId: e.id),
      ),
    );
  }
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
class _NewExpeditionCard extends StatelessWidget {
  const _NewExpeditionCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: Andes.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF203A3C), Andes.surfaceContainer],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 18, 22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLANEA TU SALIDA',
                      style: labelStyle(context, color: Andes.gold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'NUEVA\nEXPEDICIÓN',
                      style: signage(
                        context,
                        size: 28,
                      ).copyWith(fontWeight: FontWeight.w900, height: 1.0),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Elige la zona y descarga sus mapas con Wi-Fi para usarlos sin señal.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Andes.gold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_location_alt_rounded,
                  color: Andes.onGold,
                  size: 28,
                ),
              ),
            ],
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
      onTap: e == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => MapScreen(expeditionId: e.id),
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
                  '${e?.name ?? 'Una expedición'} · ${fmtKm(r.stats.meters)} km',
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
