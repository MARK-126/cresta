import 'package:flutter/material.dart';

import 'theme.dart';

/// Arranque cinematográfico (diseño "Cinematic Splash" de Stitch): placas oscuras con un
/// resplandor cian arriba, la placa de vidrio con la montaña y la marca.
///
/// La montaña queda en el centro exacto de la pantalla y del mismo tamaño que la del
/// splash de Android 12+ (`drawable/splash_icon.xml`): así el paso de uno a otro se ve
/// como una sola pantalla que "se enciende".
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const tile = 136.0;
  static const icon = 64.0;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) _c.value = 1;
    // El fondo se enciende primero; la marca aparece después, subiendo un poco
    final glow = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, .7, curve: Curves.easeOut),
    );
    final brand = CurvedAnimation(
      parent: _c,
      curve: const Interval(.35, 1, curve: Curves.easeOutCubic),
    );

    return Scaffold(
      backgroundColor: Andes.surface,
      body: LayoutBuilder(
        builder: (context, box) {
          final center = box.maxHeight / 2;
          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(opacity: glow, child: const _Backdrop()),
              Center(child: _LogoTile(glow: glow)),
              Positioned(
                left: 24,
                right: 24,
                top: center + SplashScreen.tile / 2 + 48,
                child: AnimatedBuilder(
                  animation: brand,
                  builder: (context, child) => Opacity(
                    opacity: brand.value,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - brand.value)),
                      child: child,
                    ),
                  ),
                  child: const _Brand(),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 40 + MediaQuery.paddingOf(context).bottom,
                child: FadeTransition(
                  opacity: brand,
                  child: Column(
                    children: [
                      Text(
                        'PREPARANDO MAPAS SIN CONEXIÓN',
                        style: labelStyle(context).copyWith(
                          fontSize: 9.5,
                          letterSpacing: 3,
                          color: Andes.onSurfaceVariant.withValues(alpha: .7),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.white.withValues(alpha: .08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Placas oscuras + resplandor cian arriba + viñeteado hacia abajo.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => const Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF07090A),
          // Una sola imagen que cubre todo: en mosaico se notaban las costuras
          image: DecorationImage(
            image: AssetImage('assets/images/splash_texture.png'),
            fit: BoxFit.cover,
            opacity: .6,
          ),
        ),
      ),
      // Resplandor: cian intenso en el centro superior que se apaga hacia los bordes
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.5),
            radius: .95,
            colors: [
              Color(0xE600BCD4),
              Color(0x99007C8A),
              Color(0x3300363D),
              Color(0x00000000),
            ],
            stops: [0, .35, .7, 1],
          ),
        ),
      ),
      // Viñeteado: la parte de abajo cae a casi negro
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0x8C050809), Color(0xF2050809)],
            stops: [.35, .7, 1],
          ),
        ),
      ),
    ],
  );
}

/// Placa de vidrio con la montaña y una insignia de ubicación en la esquina.
class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.glow});
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: SplashScreen.tile,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // La placa se enciende alrededor de la montaña que ya dibujó Android
        Positioned.fill(
          child: FadeTransition(
            opacity: glow,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: .14),
                    Colors.white.withValues(alpha: .04),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
            ),
          ),
        ),
        const Center(
          child: Icon(
            Icons.landscape_rounded,
            size: SplashScreen.icon,
            color: Andes.cyan,
          ),
        ),
        Positioned(
          right: -14,
          bottom: -14,
          child: FadeTransition(
            opacity: glow,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Andes.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .1)),
              ),
              child: const Icon(
                Icons.my_location_rounded,
                size: 22,
                color: Andes.cyan,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Dos tonos como en el diseño: la segunda mitad en cian con un leve resplandor
      const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'CRES'),
            TextSpan(
              text: 'TA',
              style: TextStyle(
                color: Andes.cyan,
                shadows: [Shadow(color: Color(0x8046EAE5), blurRadius: 24)],
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 48,
          fontWeight: FontWeight.w900,
          letterSpacing: 5,
          height: 1,
          color: Andes.onSurface,
        ),
      ),
      const SizedBox(height: 18),
      Container(
        width: 150,
        height: 2,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x0046EAE5), Andes.cyan, Color(0x0046EAE5)],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'MAPAS DE MONTAÑA SIN CONEXIÓN',
        textAlign: TextAlign.center,
        style: labelStyle(context).copyWith(
          fontSize: 11,
          letterSpacing: 4,
          fontWeight: FontWeight.w600,
          color: Andes.onSurface.withValues(alpha: .85),
        ),
      ),
    ],
  );
}
