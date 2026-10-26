import 'package:flutter/material.dart';

import 'theme.dart';

/// Arranque: resplandor cian, montaña y la marca mientras se preparan los mapas.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.35),
                  radius: 1.05,
                  colors: [Color(0xFF0B6E79), Color(0xFF0D2F35), Andes.surface],
                  stops: [0, .45, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 5),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Andes.surfaceHigh.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.landscape_rounded,
                          size: 60,
                          color: Andes.cyan,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(text: 'CRESTA'),
                            TextSpan(
                              text: '.',
                              style: TextStyle(color: Andes.cyan),
                            ),
                          ],
                        ),
                        style: signage(context, size: 44).copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 10,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 120,
                        height: 2,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Andes.cyan,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'MAPAS DE MONTAÑA SIN CONEXIÓN',
                        style: labelStyle(context)
                            .copyWith(letterSpacing: 3.2, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 6),
                Text(
                  'PREPARANDO MAPAS',
                  style: labelStyle(context)
                      .copyWith(letterSpacing: 3, fontSize: 10),
                ),
                const SizedBox(height: 14),
                const SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
