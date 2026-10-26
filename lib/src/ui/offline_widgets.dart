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
      RegionStatus.complete => 'Descargada · ${fmtBytes(r.bytes)}',
      RegionStatus.downloading =>
        'Descargando ${(r.progress * 100).floor()} % · ${fmtBytes(r.bytes)}',
      RegionStatus.queued => r.message ?? 'En espera',
      RegionStatus.paused =>
        '${r.message ?? 'En pausa'} · ${(r.progress * 100).floor()} %',
      RegionStatus.failed => r.message ?? 'Falló la descarga',
    };
    final accent = r.isComplete
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
              r.isComplete ? Icons.check_circle_rounded : Icons.map_outlined,
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
