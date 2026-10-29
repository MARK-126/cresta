import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/asset_repository.dart';
import '../data/trail_route.dart';
import '../expeditions/expedition.dart';
import '../weather/forecast.dart';
import '../weather/weather_service.dart';
import 'format.dart';
import 'theme.dart';

IconData weatherIcon(int code, {bool night = false}) => switch (code) {
  0 || 1 when night => Icons.nightlight_round,
  2 when night => Icons.nights_stay_rounded,
  0 || 1 => Icons.wb_sunny_rounded,
  2 => Icons.wb_cloudy_outlined,
  3 || 45 || 48 => Icons.cloud_rounded,
  >= 95 => Icons.thunderstorm_rounded,
  71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_rounded,
  _ => Icons.water_drop_rounded,
};

/// El día que importa: el de la expedición si cae dentro del pronóstico; si no, hoy.
DateTime focusDay(Expedition e, WeatherSnapshot s) {
  final today = DateTime.now();
  final d = e.date;
  final last = s.lastDay;
  if (d != null &&
      last != null &&
      !d.isAfter(last) &&
      !d.isBefore(DateTime(today.year, today.month, today.day))) {
    return d;
  }
  return today;
}

/// Consulta el clima de la expedición y avisa del resultado.
Future<void> refreshWeather(
  BuildContext context,
  Expedition e,
  TrailRoute? route,
) async {
  final services = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  // La expedición de ejemplo trae su ruta en la app, no guardada
  if (route == null && e.routeAsset != null) {
    (route, _) = await const AssetData().route(e.routeAsset!);
  }
  final points = await weatherPointsFor(
    route: route,
    bounds: services.expeditions.statusOf(e).bounds,
    elevation: services.terrain.at,
  );
  if (points.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Agrega una zona de mapas o una ruta para saber dónde consultar el clima.',
        ),
      ),
    );
    return;
  }
  try {
    await services.weather.refresh(e.id, points);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Clima actualizado y guardado para usarlo sin señal.'),
      ),
    );
  } on WeatherException catch (err) {
    messenger.showSnackBar(SnackBar(content: Text(err.message)));
  }
}

String fmtUpdated(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'hace un momento';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} ${d.inDays == 1 ? 'día' : 'días'}';
}

/// Resumen del clima en la pantalla de la expedición.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key, required this.expedition, required this.route});
  final Expedition expedition;
  final TrailRoute? route;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    await refreshWeather(context, widget.expedition, widget.route);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: services.weather,
      builder: (context, _) {
        final snap = services.weather.forExpedition(widget.expedition.id);
        final refreshButton = OutlinedButton.icon(
          onPressed: _busy ? null : _refresh,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(snap == null ? 'Consultar clima' : 'Actualizar'),
        );
        if (snap == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Consúltalo con conexión antes de salir: queda guardado y lo ves en la montaña sin señal. Pronóstico de 16 días por altitud (Open-Meteo).',
                style: TextStyle(color: muted, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 10),
              refreshButton,
            ],
          );
        }
        final day = focusDay(widget.expedition, snap);
        final isExpDay =
            widget.expedition.date != null &&
            DateUtils.isSameDay(day, widget.expedition.date);
        final storm = snap.points.any((p) => isStorm(p.dayOf(day)?.code ?? 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TonalCard(
              accent: storm ? Andes.terracottaContainer : Andes.cyan,
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WeatherScreen(
                    expeditionId: widget.expedition.id,
                    subject: widget.expedition,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${isExpDay ? 'DÍA DE LA SALIDA' : 'HOY'} · ${fmtDate(day).toUpperCase()}',
                          style: labelStyle(
                            context,
                            color: Andes.gold,
                          ).copyWith(fontSize: 10),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  if (storm) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Pronóstico de tormenta eléctrica: en la montaña es motivo para no salir o bajar temprano.',
                      style: TextStyle(
                        color: Andes.terracottaContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  for (final p in snap.points)
                    if (p.dayOf(day) case final d?)
                      _PointSummary(forecast: p, day: d),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Actualizado ${fmtUpdated(snap.fetchedAt)}',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
                refreshButton,
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PointSummary extends StatelessWidget {
  const _PointSummary({required this.forecast, required this.day});
  final PointForecast forecast;
  final DayWeather day;

  @override
  Widget build(BuildContext context) {
    final p = forecast.point;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${p.label.toUpperCase()}${p.elevation == null ? '' : ' · ${fmtInt(p.elevation!)} M'}',
            style: labelStyle(context).copyWith(fontSize: 10),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                weatherIcon(day.displayCode),
                color: isStorm(day.code)
                    ? Andes.terracottaContainer
                    : Andes.cyan,
              ),
              const SizedBox(width: 10),
              Text(
                '${day.min.round()}° / ${day.max.round()}°',
                style: dataStyle(context, size: 22, weight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  weatherLabel(day.displayCode),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                Icons.air_rounded,
                'Ráfagas ${day.gustMax.round()} km/h',
                warn: day.gustMax >= 60,
              ),
              _Chip(
                Icons.umbrella_rounded,
                '${day.precipitationChance} % · ${day.precipitation.toStringAsFixed(1)} mm',
              ),
              if (day.snowLikely)
                const _Chip(
                  Icons.ac_unit_rounded,
                  'Nieve probable',
                  warn: true,
                ),
              if (day.freezingLevelMin != null)
                _Chip(
                  Icons.thermostat_rounded,
                  '0 °C a ${fmtInt(day.freezingLevelMin!)} m',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text, {this.warn = false});
  final IconData icon;
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? Andes.gold : Andes.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: warn ? Andes.gold.withValues(alpha: .12) : Andes.surfaceHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: dataStyle(
              context,
              size: 11.5,
              color: color,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pronóstico completo: 16 días por punto y, para el día elegido, cada 3 horas.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key, required this.expeditionId, this.subject});
  final String expeditionId;

  /// De quién es el clima cuando no es una expedición guardada (el de una ruta).
  final Expedition? subject;

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  int _point = 0;
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final e = services.expeditions.byId(widget.expeditionId) ?? widget.subject;
    return ListenableBuilder(
      listenable: services.weather,
      builder: (context, _) {
        final snap = services.weather.forExpedition(widget.expeditionId);
        if (e == null || snap == null || snap.points.isEmpty) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final point = snap.points[_point.clamp(0, snap.points.length - 1)];
        final day = _day ?? focusDay(e, snap);
        final hours = point
            .hoursOf(day)
            .where((h) => h.time.hour % 3 == 0)
            .toList();
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        return Scaffold(
          appBar: AppBar(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                'CLIMA · ${e.name.toUpperCase()}',
                style: labelStyle(context, color: Andes.gold),
              ),
              const SizedBox(height: 6),
              Text('Pronóstico', style: signage(context, size: 32)),
              const SizedBox(height: 4),
              Text(
                'Actualizado ${fmtUpdated(snap.fetchedAt)} · Open-Meteo',
                style: TextStyle(color: muted, fontSize: 12.5),
              ),
              if (snap.points.length > 1) ...[
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: [
                    for (var i = 0; i < snap.points.length; i++)
                      ButtonSegment(
                        value: i,
                        label: Text(
                          '${snap.points[i].point.label} · ${fmtInt(snap.points[i].point.elevation ?? 0)} m',
                        ),
                      ),
                  ],
                  selected: {_point},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _point = s.first),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                '${fmtDate(day).toUpperCase()} · CADA 3 HORAS',
                style: labelStyle(context),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: hours.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final h = hours[i];
                    final d = point.dayOf(h.time);
                    // De noche, despejado es luna, no sol
                    final night =
                        d?.sunrise != null &&
                        d?.sunset != null &&
                        (h.time.isBefore(d!.sunrise!) ||
                            h.time.isAfter(d.sunset!));
                    return _HourTile(hour: h, night: night);
                  },
                ),
              ),
              const SizedBox(height: 22),
              Text('16 DÍAS', style: labelStyle(context)),
              const SizedBox(height: 10),
              for (final d in point.days)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DayRow(
                    day: d,
                    selected: DateUtils.isSameDay(d.date, day),
                    isExpedition:
                        e.date != null && DateUtils.isSameDay(d.date, e.date),
                    onTap: () => setState(() => _day = d.date),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'La temperatura se ajusta a la altitud del punto. El viento es el del modelo (celdas de 1 a 11 km): en crestas y cumbres expuestas suele ser más fuerte.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile({required this.hour, this.night = false});
  final HourWeather hour;
  final bool night;

  @override
  Widget build(BuildContext context) => Container(
    width: 78,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: Andes.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          '${hour.time.hour.toString().padLeft(2, '0')}:00',
          style: labelStyle(context).copyWith(fontSize: 10, letterSpacing: .6),
        ),
        const SizedBox(height: 6),
        Icon(
          weatherIcon(hour.displayCode, night: night),
          size: 20,
          color: isStorm(hour.code) ? Andes.terracottaContainer : Andes.cyan,
        ),
        const SizedBox(height: 6),
        Text(
          '${hour.temperature.round()}°',
          style: dataStyle(context, size: 17, weight: FontWeight.w800),
        ),
        Text(
          'sens. ${hour.feelsLike.round()}°',
          style: dataStyle(
            context,
            size: 10,
            color: Andes.onSurfaceVariant,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${hour.gusts.round()} km/h',
          style: dataStyle(
            context,
            size: 10,
            color: hour.gusts >= 60 ? Andes.gold : Andes.onSurfaceVariant,
            weight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.selected,
    required this.isExpedition,
    required this.onTap,
  });
  final DayWeather day;
  final bool selected;
  final bool isExpedition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return TonalCard(
      accent: isExpedition ? Andes.gold : (selected ? Andes.cyan : null),
      color: selected ? Andes.surfaceHigh : null,
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmtDate(day.date).split(' ').take(3).join(' '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (isExpedition)
                  Text(
                    'SALIDA',
                    style: labelStyle(
                      context,
                      color: Andes.gold,
                    ).copyWith(fontSize: 9),
                  ),
              ],
            ),
          ),
          Icon(
            weatherIcon(day.displayCode),
            size: 20,
            color: isStorm(day.code) ? Andes.terracottaContainer : Andes.cyan,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              '${day.min.round()}° / ${day.max.round()}°',
              style: dataStyle(context, size: 14, weight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              '${day.gustMax.round()} km/h · ${day.precipitationChance} %${day.snowLikely ? ' · nieve' : ''}',
              textAlign: TextAlign.right,
              style: dataStyle(
                context,
                size: 11.5,
                color: day.gustMax >= 60 || day.snowLikely ? Andes.gold : muted,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
