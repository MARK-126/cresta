import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../tracking/track_totals.dart';
import 'format.dart';
import 'log_screen.dart';
import 'theme.dart';

/// Resumen personal con datos reales de los recorridos terminados: sin metas ni rankings.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.tracks,
      builder: (context, _) {
        final s = ActivitySummary(services.tracks.all, now: DateTime.now());
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text('RESUMEN', style: labelStyle(context, color: Andes.gold)),
              const SizedBox(height: 6),
              Text('Tu montaña', style: signage(context, size: 34)),
              const SizedBox(height: 4),
              Text(
                s.all.count == 0
                    ? 'Graba tu primer recorrido para ver tus cifras.'
                    : '${s.all.count} ${s.all.count == 1 ? 'salida' : 'salidas'} · ${fmtKm(s.all.meters)} km en total',
                style: dataStyle(
                  context,
                  color: Andes.onSurfaceVariant,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              TonalCard(
                accent: scheme.primary,
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTA SEMANA · DESDE EL ${fmtDate(s.weekStart).toUpperCase()}',
                      style: labelStyle(context).copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 10),
                    Figure(
                      '+${fmtInt(s.week.gain)}',
                      'metros de desnivel',
                      unit: 'm',
                      size: 48,
                      labelColor: scheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Figure(fmtKm(s.week.meters), 'km', size: 18),
                        ),
                        Expanded(
                          child: Figure(
                            '${s.week.count}',
                            s.week.count == 1 ? 'salida' : 'salidas',
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: Figure(
                            fmtDuration(s.week.moving),
                            'en movimiento',
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TonalCard(
                      child: Figure(
                        '+${fmtInt(s.month.gain)}',
                        'desnivel del mes',
                        unit: 'm',
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TonalCard(
                      child: Figure(
                        fmtKm(s.month.meters),
                        'km del mes',
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TonalCard(
                accent: Andes.gold,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Figure(
                            s.all.maxAltitude == null
                                ? '–'
                                : fmtInt(s.all.maxAltitude!),
                            'altitud máxima alcanzada',
                            unit: 'm',
                            size: 28,
                            labelColor: Andes.gold,
                          ),
                          if (s.all.highest != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${s.all.highest!.name} · ${fmtDate(s.all.highest!.startedAt.toLocal())}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Andes.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.landscape_rounded,
                      color: Andes.gold,
                      size: 36,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('DESNIVEL POR SEMANA', style: labelStyle(context)),
              const SizedBox(height: 12),
              TonalCard(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: _WeeklyBars(summary: s),
              ),
              if (s.recent.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('ÚLTIMAS SALIDAS', style: labelStyle(context)),
                const SizedBox(height: 12),
                for (final t in s.recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LogEntry(track: t),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Barras del desnivel de las últimas semanas; la actual resalta en cian pleno.
class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.summary});
  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final gains = summary.weeklyGain;
    final top = gains.fold<double>(0, math.max);
    final primary = Theme.of(context).colorScheme.primary;
    final first = DateTime(
      summary.weekStart.year,
      summary.weekStart.month,
      summary.weekStart.day - 7 * (gains.length - 1),
    );
    return Semantics(
      label:
          'Desnivel de las últimas ${gains.length} semanas: ${gains.map(fmtInt).join(', ')} metros',
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < gains.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (gains[i] > 0)
                            Text(
                              fmtInt(gains[i]),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              style: dataStyle(
                                context,
                                size: 9,
                                color: i == gains.length - 1
                                    ? primary
                                    : Andes.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            // Una barra mínima para que las semanas sin salidas se vean
                            height: top == 0
                                ? 3
                                : math.max(3, gains[i] / top * 80),
                            decoration: BoxDecoration(
                              color: i == gains.length - 1
                                  ? primary
                                  : primary.withValues(alpha: .35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${first.day} ${fmtMonth(first).split(' ').first.substring(0, 3)}',
                style: labelStyle(context)
                    .copyWith(fontSize: 9.5, letterSpacing: .6),
              ),
              const Spacer(),
              Text(
                'ESTA SEMANA',
                style: labelStyle(
                  context,
                  color: primary,
                ).copyWith(fontSize: 9.5, letterSpacing: .6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
