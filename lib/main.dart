import 'package:flutter/material.dart';

import 'src/app_services.dart';
import 'src/ui/expeditions_screen.dart';
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
  late final Future<AppServices> _boot = AppServices.start();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _boot,
      builder: (context, snap) => MaterialApp(
        title: 'Cresta',
        debugShowCheckedModeBanner: false,
        theme: crestaTheme(Brightness.light, civil: false),
        darkTheme: crestaTheme(Brightness.dark, civil: false),
        // AppScope por encima del Navigator, para que todas las pantallas lo vean
        builder: (context, child) => snap.hasData
            ? AppScope(services: snap.data!, child: child!)
            : child!,
        home: _home(snap),
      ),
    );
  }

  Widget _home(AsyncSnapshot<AppServices> snap) {
    if (snap.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudo preparar la app: ${snap.error}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (!snap.hasData) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparando mapas sin conexión…'),
            ],
          ),
        ),
      );
    }
    return const ExpeditionsScreen();
  }
}
