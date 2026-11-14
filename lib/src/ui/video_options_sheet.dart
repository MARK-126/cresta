import 'package:flutter/material.dart';

import '../map/map_layers.dart';
import '../map/video_options.dart';
import 'theme.dart';

/// Antes de generar el video: fondo, capas y velocidad. Devuelve null si se cierra.
Future<VideoOptions?> showVideoOptions(
  BuildContext context,
  VideoOptions initial,
) => showModalBottomSheet<VideoOptions>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _VideoOptionsSheet(initial),
);

class _VideoOptionsSheet extends StatefulWidget {
  const _VideoOptionsSheet(this.initial);
  final VideoOptions initial;

  @override
  State<_VideoOptionsSheet> createState() => _VideoOptionsSheetState();
}

class _VideoOptionsSheetState extends State<_VideoOptionsSheet> {
  late VideoOptions _o = widget.initial;

  Widget _switch(
    String title,
    String? subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    value: value,
    onChanged: (v) => setState(() => onChanged(v)),
    title: Text(title, style: const TextStyle(fontSize: 15)),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: Andes.onSurfaceVariant,
            ),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('VIDEO DEL RECORRIDO', style: labelStyle(context)),
            const SizedBox(height: 4),
            Text('Opciones del video', style: signage(context, size: 24)),
            const SizedBox(height: 16),
            Text('FONDO', style: labelStyle(context)),
            const SizedBox(height: 8),
            SegmentedButton<MapBase>(
              segments: [
                for (final b in MapBase.values)
                  ButtonSegment(value: b, label: Text(b.label)),
              ],
              selected: {o.base},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _o = o.copyWith(base: s.first)),
            ),
            if (o.base == MapBase.sat)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'El satélite se ve borroso de cerca: bien para la montaña, no para calles.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Andes.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('VELOCIDAD', style: labelStyle(context)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Normal')),
                ButtonSegment(value: true, label: Text('Rápido')),
              ],
              selected: {o.fast},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _o = o.copyWith(fast: s.first)),
            ),
            const SizedBox(height: 12),
            _switch(
              'Nombres de calles',
              'Solo las que pasan a unas dos cuadras del recorrido.',
              o.streets,
              (v) => _o = o.copyWith(streets: v),
            ),
            _switch(
              'Edificios en 3D',
              'De cerca y donde OpenStreetMap los tiene.',
              o.buildings,
              (v) => _o = o.copyWith(buildings: v),
            ),
            _switch(
              'Senderos y brechas',
              'En la ciudad marcan banquetas y andadores.',
              o.trails,
              (v) => _o = o.copyWith(trails: v),
            ),
            _switch(
              'Curvas de nivel',
              null,
              o.contours,
              (v) => _o = o.copyWith(contours: v),
            ),
            _switch(
              'Título y cifras',
              'Nombre, kilómetros y barra de avance abajo.',
              o.caption,
              (v) => _o = o.copyWith(caption: v),
            ),
            const SizedBox(height: 16),
            GlowButton(
              label: 'Generar video',
              icon: Icons.movie_rounded,
              onPressed: () => Navigator.pop(context, _o),
            ),
          ],
        ),
      ),
    );
  }
}
