import 'package:flutter/material.dart';

import '../app_services.dart';
import '../tips/tips.dart';
import 'theme.dart';

IconData _icon(String name) => switch (name) {
  'location' => Icons.my_location_rounded,
  'search' => Icons.search_rounded,
  'layers' => Icons.layers_outlined,
  'record' => Icons.fiber_manual_record_rounded,
  'touch' => Icons.touch_app_outlined,
  'terrain' => Icons.terrain_rounded,
  'undo' => Icons.undo_rounded,
  'lock' => Icons.lock_outline_rounded,
  'gps' => Icons.satellite_alt_outlined,
  'battery' => Icons.battery_charging_full_rounded,
  'back' => Icons.u_turn_left_rounded,
  _ => Icons.info_outline_rounded,
};

/// Muestra [tip] si el usuario aún no la vio, y la marca como vista.
Future<void> showTipOnce(BuildContext context, Tip tip) async {
  final tips = AppScope.of(context).tips;
  if (tips.seen(tip)) return;
  await tips.markSeen(tip);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) {
      final muted = Theme.of(context).colorScheme.onSurfaceVariant;
      return AlertDialog(
        title: Text(tip.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (icon, text) in tip.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icon(icon), size: 20, color: Andes.cyan),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(color: muted, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );
}
