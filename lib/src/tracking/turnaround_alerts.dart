import 'dart:async';

import 'package:flutter/services.dart';

import 'track_recorder.dart';

/// Dónde se publican los avisos de la hora límite.
abstract class AlertSink {
  Future<void> show(int id, String title, String body);
  Future<void> cancel(int id);
}

/// Notificaciones del sistema, por el canal nativo `cresta/notify` (solo Android: en iOS no hay
/// código nativo todavía y las llamadas no hacen nada).
class SystemAlertSink implements AlertSink {
  const SystemAlertSink();

  static const _channel = MethodChannel('cresta/notify');

  @override
  Future<void> show(int id, String title, String body) =>
      _call('show', {'id': id, 'title': title, 'body': body});

  @override
  Future<void> cancel(int id) => _call('cancel', {'id': id});

  Future<void> _call(String method, Map<String, Object> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Plataforma sin canal nativo.
    } on PlatformException {
      // Sin permiso de notificaciones: el aviso dentro de la app sigue funcionando.
    }
  }
}

/// Avisa con una notificación cuando falta poco para la hora límite de regreso y cuando llega,
/// mientras hay un recorrido en curso (grabando o en pausa). La app sigue viva por el servicio en
/// primer plano de la grabación, así que bastan temporizadores.
class TurnaroundAlerts {
  TurnaroundAlerts({
    required this.recorder,
    required this.sink,
    this.warnBefore = const Duration(minutes: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const warnId = 7101;
  static const dueId = 7102;

  final TrackRecorder recorder;
  final AlertSink sink;
  final Duration warnBefore;
  final DateTime Function() _clock;

  String? _key;
  Timer? _warn;
  Timer? _due;

  void attach() {
    recorder.addListener(_sync);
    _sync();
  }

  void dispose() {
    recorder.removeListener(_sync);
    _cancelTimers();
  }

  void _cancelTimers() {
    _warn?.cancel();
    _due?.cancel();
    _warn = _due = null;
  }

  /// El recorder avisa en cada lectura del GPS: solo se reprograma si cambió el recorrido o la
  /// hora límite (también se fija tarde, al reabrir el mapa tras recuperar un recorrido).
  void _sync() {
    final t = recorder.turnaround;
    final id = recorder.track?.id;
    final key = recorder.isActive && t != null && id != null
        ? '$id@${t.millisecondsSinceEpoch}'
        : null;
    if (key == _key) return;
    _key = key;
    _cancelTimers();
    sink.cancel(warnId);
    sink.cancel(dueId);
    if (key == null || t == null) return;
    final now = _clock();
    final hhmm = _hhmm(t);
    // Lo que ya pasó no se avisa: el panel de grabación ya lo muestra.
    final warnAt = t.subtract(warnBefore);
    if (warnAt.isAfter(now)) {
      _warn = Timer(warnAt.difference(now), () {
        if (_key != key) return;
        sink.show(
          warnId,
          'Hora límite en ${warnBefore.inMinutes} min',
          'Tu hora límite de regreso es a las $hhmm. Ve pensando en volver.',
        );
      });
    }
    if (t.isAfter(now)) {
      _due = Timer(t.difference(now), () {
        if (_key != key) return;
        sink.show(
          dueId,
          'Es tu hora límite de regreso',
          'Son las $hhmm. Es momento de regresar.',
        );
      });
    }
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
