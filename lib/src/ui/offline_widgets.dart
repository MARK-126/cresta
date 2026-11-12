import 'package:flutter/material.dart';

import '../expeditions/expedition.dart';
import '../offline/map_sources.dart';
import '../offline/offline_maps.dart';
import '../offline/offline_region.dart';
import 'format.dart';
import 'theme.dart';

/// Listo = cian (lo que funciona), pendiente = oro (requiere atención).
const okColor = Andes.cyan;
const warnColor = Andes.gold;

/// Píldora con el estado sin conexión de una expedición.
class ReadinessChip extends StatelessWidget {
  const ReadinessChip(this.status, {super.key});
  final ExpeditionStatus status;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      String text,
      Color color,
    ) = switch (status.readiness) {
      Readiness.ready => (
        Icons.offline_pin_rounded,
        'Lista sin conexión',
        okColor,
      ),
      Readiness.downloading => (
        Icons.downloading_rounded,
        'Descargando ${(status.progress * 100).floor()} %',
        warnColor,
      ),
      Readiness.incomplete => (
        Icons.error_outline_rounded,
        'Mapas incompletos',
        warnColor,
      ),
      Readiness.noMaps => (
        Icons.cloud_off_rounded,
        'Sin mapas descargados',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: labelStyle(
              context,
              color: color,
            ).copyWith(fontSize: 10.5, letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }
}

/// Una zona descargada con su progreso y acciones.
class RegionTile extends StatelessWidget {
  const RegionTile({
    super.key,
    required this.region,
    required this.maps,
    this.subtitle,
    required this.onDelete,
  });

  final OfflineRegion region;
  final OfflineMaps maps;
  final String? subtitle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = region;
    final sources = MapSource.values
        .where(r.sources.contains)
        .map((s) => s.label.split(' ').first)
        .join(' · ');
    final statusText = switch (r.status) {
      RegionStatus.complete when r.bundled =>
        'Incluida en la app · ${fmtBytes(r.bytes)}',
      RegionStatus.complete => 'Descargada · ${fmtBytes(r.bytes)}',
      RegionStatus.downloading when r.isRefreshing =>
        'Actualizando senderos y calles ${(r.progress * 100).floor()} %',
      RegionStatus.downloading =>
        'Descargando ${(r.progress * 100).floor()} % · ${fmtBytes(r.bytes)}',
      RegionStatus.queued => r.message ?? 'En espera',
      RegionStatus.paused =>
        '${r.message ?? 'En pausa'} · ${(r.progress * 100).floor()} %',
      RegionStatus.failed => r.message ?? 'Falló la descarga',
    };
    final now = DateTime.now();
    final stale = r.isStale(now);
    final done = r.status == RegionStatus.complete;
    final accent = done && !stale
        ? okColor
        : (r.status == RegionStatus.failed ? scheme.error : warnColor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TonalCard(
        accent: accent,
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.map_outlined,
              color: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${r.detail.label} · $sources · ${r.bbox.widthKm.round()} × ${r.bbox.heightKm.round()} km',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (r.canRefresh)
                    Text(
                      stale
                          ? 'Senderos y calles ${fmtAge(now.difference(r.topoDate))}: actualízalos con Wi-Fi'
                          : 'Senderos y calles del ${fmtDate(r.topoDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: stale ? FontWeight.w600 : null,
                        color: stale ? warnColor : scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (!done) ...[
                    LinearProgressIndicator(
                      value: r.progress,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    statusText,
                    style: dataStyle(
                      context,
                      size: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (r.status == RegionStatus.downloading ||
                r.status == RegionStatus.queued)
              IconButton(
                tooltip: 'Pausar',
                icon: const Icon(Icons.pause_rounded),
                onPressed: () => maps.pause(r.id),
              )
            else if (!done)
              IconButton(
                tooltip: 'Reanudar',
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: () => maps.resume(r.id),
              )
            else if (r.canRefresh)
              IconButton(
                tooltip: 'Actualizar senderos y calles',
                icon: Icon(Icons.sync_rounded, color: stale ? warnColor : null),
                onPressed: () => maps.refresh(r.id),
              ),
            // Los mapas incluidos viven en la app: borrarlos casi no libera
            // espacio y dejaría al ejemplo sin mapas.
            if (!r.bundled)
              IconButton(
                tooltip: 'Borrar mapas',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

/// Aviso de conexión: sin red, o esperando Wi-Fi para descargar.
class NetworkBanner extends StatelessWidget {
  const NetworkBanner({super.key, required this.maps});
  final OfflineMaps maps;

  @override
  Widget build(BuildContext context) {
    final reason = maps.blockedReason;
    if (reason == null) return const SizedBox.shrink();
    final offline = maps.network == NetworkKind.none;
    final color = offline ? Andes.onSurfaceVariant : warnColor;
    return Material(
      color: color.withValues(alpha: .1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off_rounded : Icons.wifi_off_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                offline
                    ? 'Sin conexión. Los mapas descargados funcionan normalmente.'
                    : 'Con datos móviles. Las descargas esperan a que haya Wi-Fi.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Con Wi-Fi y zonas de mapas viejas, ofrece actualizarlas (se revisa al abrir la app y
/// cada vez que vuelve el Wi-Fi). "Ahora no" lo oculta hasta que se vuelva a abrir.
class StaleMapsBanner extends StatefulWidget {
  const StaleMapsBanner({super.key, required this.maps});
  final OfflineMaps maps;

  @override
  State<StaleMapsBanner> createState() => _StaleMapsBannerState();
}

class _StaleMapsBannerState extends State<StaleMapsBanner> {
  static var _dismissed = false; // por sesión, en todas las pantallas

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.maps,
    builder: (context, _) {
      final maps = widget.maps;
      final stale = maps.stale();
      if (_dismissed || maps.network != NetworkKind.wifi || stale.isEmpty) {
        return const SizedBox.shrink();
      }
      final oldest = stale
          .map((r) => r.topoDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      return Material(
        color: warnColor.withValues(alpha: .1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.sync_rounded, size: 18, color: warnColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  stale.length == 1
                      ? '"${stale.single.name}" tiene senderos y calles ${fmtAge(DateTime.now().difference(oldest))}.'
                      : '${stale.length} zonas tienen senderos y calles de hace más de 3 meses.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: warnColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _dismissed = true),
                child: const Text('Ahora no'),
              ),
              TextButton(
                onPressed: maps.refreshStale,
                child: const Text('Actualizar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Avisos arriba del contenido (sin conexión, grabando…). Van en el cuerpo y no en la barra
/// superior para que tengan su altura real y no se desborden.
class WithBanners extends StatelessWidget {
  const WithBanners({super.key, required this.banners, required this.child});
  final List<Widget> banners;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ...banners,
      Expanded(child: child),
    ],
  );
}

/// Pide un texto (p. ej. un nombre). El controlador vive en el estado del diálogo y se
/// libera cuando el diálogo termina de cerrarse, no antes: liberarlo al volver de
/// `showDialog` rompe la animación de salida.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String initial,
  String? hint,
  String action = 'Guardar',
}) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) =>
        _TextDialog(title: title, initial: initial, hint: hint, action: action),
  );
  final t = text?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.action,
  });
  final String title;
  final String initial;
  final String? hint;
  final String action;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _ctrl,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: widget.hint),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _ctrl.text),
        child: Text(widget.action),
      ),
    ],
  );
}
