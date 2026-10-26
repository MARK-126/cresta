import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app_services.dart';
import 'src/ui/home_shell.dart';
import 'src/ui/splash_screen.dart';
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
        // Diálogos del sistema (fecha, hora, Cancelar/Aceptar) en español
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Solo oscuro: pensado para leerse con poca luz y ahorrar batería en pantallas OLED
        theme: crestaTheme(),
        themeMode: ThemeMode.dark,
        // AppScope por encima del Navigator, para que todas las pantallas lo vean
        builder: (context, child) => snap.hasData
            ? AppScope(services: snap.data!, child: child!)
            : child!,
        // Del splash al inicio con un fundido, no de golpe
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: _home(snap),
        ),
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
    if (!snap.hasData) return const SplashScreen();
    return const HomeShell();
  }
}
