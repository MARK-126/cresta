import 'dart:ui';

import 'package:flutter/material.dart';

/// Paleta "Andes Industrial" (diseño de Stitch): pizarra profunda con acentos
/// Cian Cumbre (acción y rastreo), Oro Inca (lo importante) y Terracota (alertas).
class Andes {
  static const surface = Color(0xFF0E1416);
  static const surfaceLowest = Color(0xFF080F11);
  static const surfaceLow = Color(0xFF161D1F);
  static const surfaceContainer = Color(0xFF1A2123);
  static const surfaceHigh = Color(0xFF242B2D);
  static const surfaceHighest = Color(0xFF2F3638);
  static const surfaceBright = Color(0xFF333A3C);
  static const onSurface = Color(0xFFDDE4E6);
  static const onSurfaceVariant = Color(0xFFBACAC8);
  static const outline = Color(0xFF859492);
  static const outlineVariant = Color(0xFF3B4948);

  static const cyan = Color(0xFF46EAE5);
  static const cyanContainer = Color(0xFF00CEC9);
  static const onCyan = Color(0xFF003735);
  static const gold = Color(0xFFF0BF63);
  static const goldContainer = Color(0xFF7F5A00);
  static const onGold = Color(0xFF412D00);
  static const terracotta = Color(0xFFFFC8BB);
  static const terracottaContainer = Color(0xFFFFA089);
  static const onTerracotta = Color(0xFF611201);
  static const error = Color(0xFFFFB4AB);

  /// Degradado de los botones principales: "iluminado desde dentro".
  static const cyanGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, cyanContainer],
  );
}

const _font = 'Inter';

/// Solo tema oscuro: en modo protección civil el acento pasa a Oro Inca.
ThemeData crestaTheme({bool civil = false}) {
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: civil ? Andes.gold : Andes.cyan,
    onPrimary: civil ? Andes.onGold : Andes.onCyan,
    primaryContainer: civil ? Andes.goldContainer : Andes.cyanContainer,
    onPrimaryContainer: civil ? const Color(0xFFFFD790) : Andes.onCyan,
    secondary: Andes.gold,
    onSecondary: Andes.onGold,
    secondaryContainer: Andes.goldContainer,
    onSecondaryContainer: const Color(0xFFFFD790),
    tertiary: Andes.terracotta,
    onTertiary: Andes.onTerracotta,
    tertiaryContainer: Andes.terracottaContainer,
    onTertiaryContainer: const Color(0xFF842B16),
    error: Andes.error,
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: Andes.surface,
    onSurface: Andes.onSurface,
    onSurfaceVariant: Andes.onSurfaceVariant,
    surfaceDim: Andes.surface,
    surfaceBright: Andes.surfaceBright,
    surfaceContainerLowest: Andes.surfaceLowest,
    surfaceContainerLow: Andes.surfaceLow,
    surfaceContainer: Andes.surfaceContainer,
    surfaceContainerHigh: Andes.surfaceHigh,
    surfaceContainerHighest: Andes.surfaceHighest,
    outline: Andes.outline,
    outlineVariant: Andes.outlineVariant,
    inverseSurface: Andes.onSurface,
    onInverseSurface: const Color(0xFF2B3234),
    inversePrimary: const Color(0xFF006A67),
    surfaceTint: Colors.transparent,
  );
  final rounded12 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  const buttonText = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w700,
    fontSize: 14.5,
    letterSpacing: .4,
  );
  // Sin bordes de 1 px: los límites se marcan con cambios de tono
  final noBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: _font,
  );
  return base.copyWith(
    scaffoldBackgroundColor: Andes.surface,
    textTheme: base.textTheme.apply(
      fontFamily: _font,
      bodyColor: Andes.onSurface,
      displayColor: Andes.onSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Andes.surface,
      foregroundColor: Andes.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -.2,
        color: Andes.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: Andes.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: rounded12,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: rounded12,
        foregroundColor: Andes.onSurface,
        textStyle: buttonText,
        // "Borde fantasma": se siente, no se ve
        side: BorderSide(color: Andes.outline.withValues(alpha: .35)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Andes.gold,
        textStyle: buttonText,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Andes.surfaceHigh,
      border: noBorder,
      enabledBorder: noBorder,
      focusedBorder: noBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary),
      ),
      labelStyle: const TextStyle(color: Andes.onSurfaceVariant),
      hintStyle: TextStyle(color: Andes.onSurfaceVariant.withValues(alpha: .6)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Andes.surfaceLow,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Andes.outlineVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Andes.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontFamily: _font,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Andes.onSurface,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Andes.surfaceHighest,
      contentTextStyle: const TextStyle(
        fontFamily: _font,
        color: Andes.onSurface,
        fontSize: 14,
      ),
      actionTextColor: Andes.gold,
      shape: rounded12,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Andes.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: rounded12,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Andes.onSurfaceVariant,
      subtitleTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 12.5,
        color: Andes.onSurfaceVariant,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: Andes.surfaceHighest,
      circularTrackColor: Colors.transparent,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: Andes.surfaceHighest,
      thumbColor: scheme.primary,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? scheme.primary
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      side: const BorderSide(color: Andes.outline, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: _font, fontWeight: FontWeight.w700),
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(rounded12),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: .18)
              : Andes.surfaceHigh,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : Andes.onSurfaceVariant,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? scheme.onPrimary : Andes.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? scheme.primary
            : Andes.surfaceHighest,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Andes.surfaceHigh,
      selectedColor: scheme.primary.withValues(alpha: .18),
      checkmarkColor: scheme.primary,
      side: BorderSide.none,
      shape: rounded12,
      labelStyle: const TextStyle(
        fontFamily: _font,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: Andes.outlineVariant.withValues(alpha: .5),
      thickness: 1,
      space: 1,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionHandleColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: .3),
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: Andes.surfaceHigh,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: Andes.surfaceHigh,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

/// Títulos de impacto: negritas y un poco comprimidas, como estampado industrial.
TextStyle signage(BuildContext context, {double size = 20}) => TextStyle(
  fontFamily: _font,
  fontSize: size,
  fontWeight: FontWeight.w800,
  letterSpacing: -size * .02,
  height: 1.08,
  color: Theme.of(context).colorScheme.onSurface,
);

/// Cifras: Inter con números tabulares para que no "bailen" al cambiar.
TextStyle dataStyle(
  BuildContext context, {
  double size = 13,
  Color? color,
  FontWeight weight = FontWeight.w600,
}) => TextStyle(
  fontFamily: _font,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: size >= 24 ? -size * .03 : 0,
  height: size >= 24 ? 1.0 : null,
  fontFeatures: const [FontFeature.tabularFigures()],
  color: color ?? Theme.of(context).colorScheme.onSurface,
);

/// Etiquetas de metadatos: pequeñas, espaciadas y en mayúsculas (el texto lo pone quien llama).
TextStyle labelStyle(BuildContext context, {Color? color}) => TextStyle(
  fontFamily: _font,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
  color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
);

/// Marca de la app: CRESTA en negras con el punto en cian.
class CrestaWordmark extends StatelessWidget {
  const CrestaWordmark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'CRESTA'),
        TextSpan(
          text: '.',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ],
    ),
    style: signage(context, size: size).copyWith(fontWeight: FontWeight.w900),
  );
}

/// Bloque tonal: la forma básica del diseño. Sin bordes ni sombras; se separa del
/// fondo por el tono. `accent` dibuja la barra lateral que marca estado o prioridad.
class TonalCard extends StatelessWidget {
  const TonalCard({
    super.key,
    required this.child,
    this.accent,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color? accent;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(padding: padding, child: child);
    if (accent != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent!, width: 3)),
        ),
        child: body,
      );
    }
    return Material(
      color: color ?? Andes.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// Dato con su etiqueta debajo (telemetría). Las cifras de 24 o más son las protagonistas.
class Figure extends StatelessWidget {
  const Figure(
    this.value,
    this.label, {
    super.key,
    this.unit,
    this.size = 22,
    this.color,
    this.labelColor,
  });

  final String value;
  final String label;
  final String? unit;
  final double size;
  final Color? color;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: value),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: size * .5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: dataStyle(
            context,
            size: size,
            weight: size >= 24 ? FontWeight.w900 : FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: labelStyle(context, color: labelColor).copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

/// Botón principal de una pantalla: degradado cian, alto, en mayúsculas espaciadas.
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: Material(
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: Andes.cyanGlow),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Andes.onCyan, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: _font,
                      color: Andes.onCyan,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Capa de vidrio para lo que flota sobre el mapa: deja ver el terreno debajo.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 16,
    this.opacity = .72,
  });

  final Widget child;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: ColoredBox(
        color: Andes.surfaceContainer.withValues(alpha: opacity),
        child: child,
      ),
    ),
  );
}
