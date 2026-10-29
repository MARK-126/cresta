import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/trail_route.dart';
import '../expeditions/expedition.dart';
import '../sun/sun_times.dart';
import 'format.dart';
import 'theme.dart';

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Dónde está la expedición para calcular el sol: la salida de su primera ruta o, si no hay,
/// el centro de sus zonas de mapa.
LngLat? expeditionLocation(AppServices services, Expedition e) {
  final route = services.routes.forExpedition(e.id);
  if (route != null && route.profile.coordinates.isNotEmpty) {
    return route.profile.coordinates.first;
  }
  final b = services.expeditions.statusOf(e).bounds;
  return b == null ? null : LngLat(b.centerLng, b.centerLat);
}

/// Luz del día de la expedición (sin conexión) y una hora límite que deje luz para bajar.
class SunCard extends StatelessWidget {
  const SunCard({super.key, required this.expedition});
  final Expedition expedition;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final where = expeditionLocation(services, expedition);
    if (where == null) {
      return Text(
        'Agrega una zona de mapas o una ruta para calcular la luz del día.',
        style: TextStyle(color: muted, fontSize: 13),
      );
    }
    final day = expedition.date ?? DateTime.now();
    final sun = sunTimes(date: day, lat: where.lat, lng: where.lng);
    final head =
        '${expedition.date == null ? 'HOY' : 'DÍA DE LA SALIDA'} · ${fmtDate(day).toUpperCase()}';

    if (sun.sunrise == null || sun.sunset == null) {
      return TonalCard(
        accent: Andes.gold,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(head, style: labelStyle(context, color: Andes.gold)),
            const SizedBox(height: 8),
            Text(
              sun.polarDay
                  ? 'El sol no se pone ese día en este lugar.'
                  : 'El sol no sale ese día en este lugar.',
            ),
          ],
        ),
      );
    }

    final last = lastSafeTurnaround(sun)!;
    final lastMinutes = roundDownTo5(last.hour * 60 + last.minute);
    final lastText =
        '${(lastMinutes ~/ 60).toString().padLeft(2, '0')}:${(lastMinutes % 60).toString().padLeft(2, '0')}';
    final deadlineMin = expedition.turnaroundMinutes;
    final deadline = deadlineMin == null
        ? null
        : DateTime(
            day.year,
            day.month,
            day.day,
          ).add(Duration(minutes: deadlineMin));
    final tooLate = deadline != null && deadline.isAfter(last);

    return TonalCard(
      accent: Andes.gold,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head, style: labelStyle(context, color: Andes.gold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Figure(_hhmm(sun.sunrise!), 'amanecer', size: 22),
              ),
              Expanded(
                child: Figure(_hhmm(sun.sunset!), 'atardecer', size: 22),
              ),
              Expanded(
                child: Figure(fmtDuration(sun.daylight!), 'de luz', size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (deadline == null)
            Text(
              'Para bajar con luz, que tu hora límite no pase de las $lastText (el atardecer menos ${descentMargin.inHours} h).',
              style: const TextStyle(fontSize: 13, height: 1.4),
            )
          else if (tooLate)
            Text(
              'Tu hora límite (${_hhmm(deadline)}) deja menos de ${descentMargin.inHours} h de luz antes del atardecer: considera adelantarla a las $lastText.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Andes.terracottaContainer,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              'Tu hora límite (${_hhmm(deadline)}) deja ${fmtDuration(sun.sunset!.difference(deadline))} de luz para bajar.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          if (deadline == null || tooLate)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => services.expeditions.update(
                  expedition,
                  turnaroundMinutes: lastMinutes,
                ),
                child: Text('Usar $lastText como hora límite'),
              ),
            ),
          Text(
            'Horas de la zona horaria de tu teléfono; sin contar sombras de montañas ni la altitud.',
            style: TextStyle(color: muted, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}
