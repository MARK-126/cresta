import 'package:flutter/material.dart';

import 'src/data/asset_repository.dart';
import 'src/map/map_layers.dart';
import 'src/tiles/offline_pack.dart';
import 'src/tiles/tile_server.dart';
import 'src/ui/map_screen.dart';
import 'src/ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CrestaApp());
}

class CrestaApp extends StatefulWidget {
  const CrestaApp({super.key});

  @override
  State<CrestaApp> createState() => _CrestaAppState();
}

class _CrestaAppState extends State<CrestaApp> {
  late final Future<(AppData, TileServer)> _boot = _start();
  AppMode _mode = AppMode.mountain;
  TileServer? _server;

  Future<(AppData, TileServer)> _start() async {
    final (data, pack, cache) = await (AppData.load(), OfflinePack.iztaPopo.install(), tileCacheDir()).wait;
    final server = TileServer(packDirs: [pack], cacheDir: cache);
    await server.start();
    _server = server;
    return (data, server);
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final civil = _mode == AppMode.civil;
    return MaterialApp(
      title: 'Cresta',
      debugShowCheckedModeBanner: false,
      theme: crestaTheme(Brightness.light, civil: civil),
      darkTheme: crestaTheme(Brightness.dark, civil: civil),
      home: FutureBuilder(
        future: _boot,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No se pudo preparar el mapa: ${snap.error}', textAlign: TextAlign.center),
            )));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparando mapa sin conexión…'),
            ])));
          }
          final (data, server) = snap.data!;
          return MapScreen(data: data, baseUri: server.baseUri, mode: _mode, onModeChanged: (m) => setState(() => _mode = m));
        },
      ),
    );
  }
}
