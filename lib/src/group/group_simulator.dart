import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import '../data/trail_route.dart';

class GroupMember {
  GroupMember({required this.id, required this.name, required this.initials, required this.color, required this.meters, required this.speed});

  final String id;
  final String name;
  final String initials;
  final Color color;

  /// Metros recorridos desde el inicio de la ruta.
  double meters;

  /// Velocidad media en metros por segundo (simulación acelerada).
  final double speed;
  int secondsSinceUpdate = 0;
}

/// Simula al grupo avanzando por la ruta. Se reemplazará por ubicaciones reales
/// compartidas a través del backend (ver README, "Siguientes pasos").
class GroupSimulator {
  GroupSimulator(this.route, {math.Random? random}) : _random = random ?? math.Random();

  final TrailRoute route;
  final math.Random _random;
  final _controller = StreamController<List<GroupMember>>.broadcast();
  Timer? _timer;

  late final members = <GroupMember>[
    GroupMember(id: 'ana', name: 'Ana Ruiz', initials: 'AR', color: const Color(0xFF1F7AE0), meters: 7200, speed: 0.55),
    GroupMember(id: 'luis', name: 'Luis Ortega', initials: 'LO', color: const Color(0xFFE0791F), meters: 6900, speed: 0.5),
    GroupMember(id: 'me', name: 'Tú', initials: 'TÚ', color: const Color(0xFFD0245A), meters: 6650, speed: 0.52),
  ];

  Stream<List<GroupMember>> get updates => _controller.stream;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void tick() {
    for (final m in members) {
      m.meters = math.min(route.totalMeters - 30, m.meters + m.speed * (0.7 + _random.nextDouble() * 0.6));
      m.secondsSinceUpdate = 1 + _random.nextInt(4);
    }
    _controller.add(members);
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
