import 'package:flutter/material.dart';

import '../app_services.dart';
import '../expeditions/expedition.dart';
import 'downloads_screen.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: Listenable.merge([store, services.recorder]),
      builder: (context, _) {
        final items = store.all;
        return Scaffold(
          appBar: AppBar(
            title: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'CRESTA', style: signage(context, size: 24)),
                  TextSpan(
                    text: '.',
                    style: signage(
                      context,
                      size: 24,
                    ).copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Mapas descargados',
                icon: const Icon(Icons.download_for_offline_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DownloadsScreen(),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva expedición'),
          ),
          body: WithBanners(
            banners: [
              NetworkBanner(maps: services.maps),
              if (services.recorder.isActive)
                _RecordingBanner(services: services),
            ],
            child: items.isEmpty
                ? const _Empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _ExpeditionCard(expedition: items[i]),
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
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ExpeditionScreen(expeditionId: e.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(e.name, style: signage(context, size: 20)),
                  ),
                  if (e.sample)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: _Tag('Ejemplo'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                e.date == null
                    ? 'Sin fecha'
                    : '${fmtDate(e.date!)} · ${fmtRelativeDay(e.date!)}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ReadinessChip(status),
                  const Spacer(),
                  if (status.bytes > 0)
                    Text(
                      fmtBytes(status.bytes),
                      style: dataStyle(
                        context,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (status.readiness == Readiness.downloading) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: status.progress,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terrain_rounded, size: 56, color: muted),
            const SizedBox(height: 12),
            Text(
              'Aún no tienes expediciones',
              style: signage(context, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea una, elige la zona en el mapa y descarga sus mapas con Wi-Fi para usarlos sin señal en la montaña.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          ],
        ),
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
              border: OutlineInputBorder(),
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
    return Material(
      color: recordColor.withValues(alpha: .12),
      child: InkWell(
        onTap: e == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MapScreen(expeditionId: e.id),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                paused
                    ? Icons.pause_circle_outline_rounded
                    : Icons.fiber_manual_record_rounded,
                color: recordColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${paused ? 'Recorrido en pausa' : 'Grabando'} en ${e?.name ?? 'una expedición'} · ${fmtKm(r.stats.meters)} km',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
