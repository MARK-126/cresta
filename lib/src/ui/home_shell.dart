import 'package:flutter/material.dart';

import 'downloads_screen.dart';
import 'expeditions_screen.dart';
import 'log_screen.dart';
import 'summary_screen.dart';

/// Pantalla raíz: pestañas abajo. Las pantallas de detalle se abren encima y la ocultan.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    // IndexedStack conserva cada pestaña (scroll, estado) al cambiar entre ellas
    body: IndexedStack(
      index: _tab,
      children: const [
        ExpeditionsScreen(),
        LogScreen(),
        SummaryScreen(),
        DownloadsScreen(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.terrain_outlined),
          selectedIcon: Icon(Icons.terrain_rounded),
          label: 'Expediciones',
        ),
        NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route_rounded),
          label: 'Bitácora',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights_rounded),
          label: 'Resumen',
        ),
        NavigationDestination(
          icon: Icon(Icons.download_for_offline_outlined),
          selectedIcon: Icon(Icons.download_for_offline_rounded),
          label: 'Mapas',
        ),
      ],
    ),
  );
}
