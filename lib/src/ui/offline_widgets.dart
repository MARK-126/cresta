import 'package:flutter/material.dart';

import '../expeditions/expedition.dart';
import '../offline/map_sources.dart';
import '../offline/offline_maps.dart';
import '../offline/offline_region.dart';
import 'format.dart';
import 'theme.dart';

const okColor = Color(0xFF2E8B57);
const warnColor = Color(0xFFE07A10);

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
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
      RegionStatus.complete => 'Descargada · ${fmtBytes(r.bytes)}',
      RegionStatus.downloading =>
        'Descargando ${(r.progress * 100).floor()} % · ${fmtBytes(r.bytes)}',
      RegionStatus.queued => r.message ?? 'En espera',
      RegionStatus.paused =>
        '${r.message ?? 'En pausa'} · ${(r.progress * 100).floor()} %',
      RegionStatus.failed => r.message ?? 'Falló la descarga',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            r.isComplete ? Icons.check_circle_rounded : Icons.map_outlined,
            color: r.isComplete
                ? okColor
                : (r.status == RegionStatus.failed ? scheme.error : warnColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                const SizedBox(height: 6),
                if (!r.isComplete) ...[
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
          else if (!r.isComplete)
            IconButton(
              tooltip: 'Reanudar',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => maps.resume(r.id),
            ),
          IconButton(
            tooltip: 'Borrar mapas',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onDelete,
          ),
        ],
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
    return Material(
      color: (offline ? Colors.blueGrey : warnColor).withValues(alpha: .15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off_rounded : Icons.wifi_off_rounded,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                offline
                    ? 'Sin conexión. Los mapas descargados funcionan normalmente.'
                    : 'Con datos móviles. Las descargas esperan a que haya Wi-Fi.',
                style: const TextStyle(fontSize: 12.5),
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
