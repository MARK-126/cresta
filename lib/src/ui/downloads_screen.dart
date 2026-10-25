import 'package:flutter/material.dart';

import '../app_services.dart';
import '../offline/offline_region.dart';
import 'format.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'theme.dart';

/// Todas las zonas descargadas, el espacio que ocupan y las opciones de descarga.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int? _cacheBytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measureCache();
  }

  Future<void> _measureCache() async {
    final bytes = await AppScope.of(context).cache.sizeOnDisk();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final maps = services.maps;
    return ListenableBuilder(
      listenable: services.expeditions,
      builder: (context, _) {
        final regions = maps.regions;
        final total = regions.fold(0, (s, r) => s + r.bytes);
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mapas descargados'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: NetworkBanner(maps: maps),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Figure(
                      fmtBytes(total),
                      'en ${regions.length} ${regions.length == 1 ? 'zona' : 'zonas'}',
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      _cacheBytes == null ? '…' : fmtBytes(_cacheBytes!),
                      'caché de navegación',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: maps.wifiOnly,
                onChanged: maps.setWifiOnly,
                title: const Text('Descargar solo con Wi-Fi'),
                subtitle: const Text(
                  'Con datos móviles las descargas esperan en la cola.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Borrar caché de navegación'),
                subtitle: const Text(
                  'Lo que se vio con conexión pero no se descargó. Las zonas descargadas no se tocan.',
                ),
                trailing: TextButton(
                  onPressed: (_cacheBytes ?? 0) == 0
                      ? null
                      : () async {
                          await services.cache.clear();
                          _measureCache();
                        },
                  child: const Text('Borrar'),
                ),
              ),
              const SectionTitle('Zonas'),
              if (regions.isEmpty)
                Text(
                  'No hay zonas descargadas. Agrégalas desde una expedición.',
                  style: TextStyle(color: muted),
                ),
              for (final r in regions)
                RegionTile(
                  region: r,
                  maps: maps,
                  subtitle: _usedBy(context, r),
                  onDelete: () => _delete(context, r),
                ),
            ],
          ),
        );
      },
    );
  }

  String? _usedBy(BuildContext context, OfflineRegion r) {
    final names = AppScope.of(context).expeditions
        .usingRegion(r.id)
        .map((e) => e.name)
        .toList();
    return names.isEmpty ? 'Sin expedición' : 'En: ${names.join(', ')}';
  }

  Future<void> _delete(BuildContext context, OfflineRegion r) async {
    final services = AppScope.of(context);
    final using = services.expeditions.usingRegion(r.id);
    final ok = await confirmDialog(
      context,
      title: 'Borrar "${r.name}"',
      body: using.isEmpty
          ? 'Se liberan ${fmtBytes(r.bytes)}.'
          : 'La usan: ${using.map((e) => e.name).join(', ')}. Esas expediciones se quedarán sin estos mapas.',
      action: 'Borrar',
    );
    if (!ok) return;
    for (final e in using) {
      await services.expeditions.detachRegion(e, r.id);
    }
    if (services.maps.byId(r.id) != null) await services.maps.remove(r.id);
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: signage(context, size: 26)),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
