import 'package:flutter/material.dart';

/// Paleta del prototipo: magenta de ruta (cartografía alpina) y naranja de protección civil.
class CrestaColors {
  static const route = Color(0xFFD0245A);
  static const routeDark = Color(0xFFFF4F86);
  static const civil = Color(0xFFE07A10);
  static const civilDark = Color(0xFFFF9D3A);
  static const ink = Color(0xFF17232A);
  static const paper = Color(0xFFEEF1EF);
  static const night = Color(0xFF121A1E);
}

ThemeData crestaTheme(Brightness brightness, {required bool civil}) {
  final dark = brightness == Brightness.dark;
  final seed = civil ? (dark ? CrestaColors.civilDark : CrestaColors.civil) : (dark ? CrestaColors.routeDark : CrestaColors.route);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    primary: seed,
    onPrimary: civil ? const Color(0xFF1B1206) : Colors.white,
    surface: dark ? CrestaColors.night : const Color(0xFFFAFBFA),
    onSurface: dark ? const Color(0xFFE6ECEA) : CrestaColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? CrestaColors.night : CrestaColors.paper,
    segmentedButtonTheme: const SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w600)),
      ),
    ),
  );
}

/// Títulos tipo señalética de sendero: condensados y en mayúsculas.
TextStyle signage(BuildContext context, {double size = 20}) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      height: 1.05,
      color: Theme.of(context).colorScheme.onSurface,
    );

TextStyle dataStyle(BuildContext context, {double size = 13, Color? color}) => TextStyle(
      fontSize: size,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontFamily: 'monospace',
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

TextStyle labelStyle(BuildContext context) => TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.0,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
