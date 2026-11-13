import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../tracking/track_recorder.dart';

enum LocationStatus { granted, denied, deniedForever, serviceOff }

/// Ubicación del propio teléfono. Funciona sin señal: el GPS usa satélites, no la red.
/// Solo se pide permiso cuando el usuario toca "Mi ubicación" o "Grabar".
class LocationService {
  Future<LocationStatus> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationStatus.serviceOff;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return switch (p) {
      LocationPermission.deniedForever => LocationStatus.deniedForever,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine => LocationStatus.denied,
      _ => LocationStatus.granted,
    };
  }

  /// Ya hay permiso y la ubicación está encendida (sin preguntar nada).
  Future<bool> isGranted() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.whileInUse ||
          p == LocationPermission.always;
    } on Exception {
      return false;
    }
  }

  static const _permissions = MethodChannel('cresta/permissions');

  /// Android 13+ exige pedir el permiso de notificaciones; sin él no se ve el aviso fijo
  /// de grabación y el sistema puede detenerla con la pantalla bloqueada.
  /// En iOS no hace falta: el indicador azul de ubicación no es una notificación.
  Future<bool> ensureNotifications() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _permissions.invokeMethod<bool>('requestNotifications') ??
          true;
    } on MissingPluginException {
      return true;
    }
  }

  /// La app está fuera de la optimización de batería de Android (no corta la grabación con
  /// la pantalla apagada). En iOS no aplica: siempre true.
  Future<bool> batteryUnrestricted() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _permissions.invokeMethod<bool>('batteryUnrestricted') ??
          true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Abre el diálogo del sistema para quitar la optimización de batería.
  Future<void> requestBatteryUnrestricted() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _permissions.invokeMethod<void>('requestBatteryUnrestricted');
    } on MissingPluginException {
      return;
    }
  }

  /// Abre el ajuste que destraba [status]: la ubicación del teléfono si está
  /// apagada, o los permisos de la app si los negó.
  Future<void> openSettings(LocationStatus status) =>
      status == LocationStatus.serviceOff
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();

  /// Última posición que el teléfono ya conoce, para centrar al instante
  /// mientras llega una lectura nueva del GPS (que en frío tarda).
  Future<Position?> lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } on Exception {
      return null;
    }
  }

  /// Un solo flujo de posiciones para toda la app. El plugin del GPS reutiliza el flujo
  /// que ya esté abierto e ignora la configuración nueva: si el mapa tenía abierto
  /// "Mi ubicación" (sin servicio en primer plano) y luego se empezaba a grabar, la
  /// grabación recibía ese mismo flujo y se cortaba al bloquear la pantalla (tramos
  /// rectos, 12 nov 2026). Por eso aquí se abre uno a la vez, según lo que haga falta.
  late final _watchers = StreamController<GpsFix>.broadcast(
    onListen: _restart,
    onCancel: _restart,
  );
  StreamController<GpsFix>? _recording;
  RecordingMode? _recordingMode;
  StreamSubscription<Position>? _sub;
  Future<void> _switching = Future.value();

  /// Tu posición mientras la app está a la vista (para "Mi ubicación" y el SOS). Si se
  /// está grabando, son las mismas lecturas de la grabación.
  Stream<GpsFix> watch() => _watchers.stream;

  /// Posiciones para grabar el recorrido, también con la pantalla apagada:
  /// en iOS con el indicador azul de ubicación, en Android con una notificación fija.
  /// Mientras alguien escucha este flujo, [watch] recibe las mismas lecturas.
  Stream<GpsFix> recording(RecordingMode mode) {
    final old = _recording;
    _recording = null;
    old?.close();
    late final StreamController<GpsFix> c;
    c = StreamController<GpsFix>(
      onListen: () {
        _recording = c;
        _recordingMode = mode;
        _restart();
      },
      onCancel: () {
        if (_recording == c) {
          _recording = null;
          _recordingMode = null;
          _restart();
        }
      },
    );
    return c.stream;
  }

  /// Cierra el flujo abierto y abre el que corresponde (grabar, mirar o ninguno). En
  /// orden, para que no queden dos abiertos a la vez.
  void _restart() {
    _switching = _switching.then((_) async {
      await _sub?.cancel();
      _sub = null;
      final mode = _recordingMode;
      final settings = mode != null
          ? _recordingSettings(mode)
          : _watchers.hasListener
          ? _watchSettings
          : null;
      if (settings == null) return;
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (p) {
          final f = _fix(p);
          _recording?.add(f);
          if (_watchers.hasListener) _watchers.add(f);
        },
        onError: (Object e) {
          _recording?.addError(e);
          if (_watchers.hasListener) _watchers.addError(e);
        },
      );
    });
  }

  static GpsFix _fix(Position p) => GpsFix(
    time: p.timestamp.toLocal(), // el GPS la entrega en UTC
    lng: p.longitude,
    lat: p.latitude,
    altitude: p.altitude == 0 && p.altitudeAccuracy == 0 ? null : p.altitude,
    accuracy: p.accuracy,
    speed: p.speed < 0 ? null : p.speed,
  );

  /// Con la app a la vista: cada 10 m.
  ///
  /// En Android se usa el GPS directo (LocationManager) y no el "fusionado" de Google:
  /// ese pide encender el Wi-Fi para mejorar la precisión cada vez que se abre, y si se
  /// rechaza, corta las posiciones con un error (12 nov 2026: 28 min grabando sin un solo
  /// punto). En la montaña no hay Wi-Fi ni antenas: el GPS es lo que cuenta.
  static LocationSettings get _watchSettings => switch (defaultTargetPlatform) {
    TargetPlatform.android => AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      forceLocationManager: true,
    ),
    _ => const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  };

  static LocationSettings _recordingSettings(RecordingMode mode) {
    final saver = mode == RecordingMode.saver;
    final accuracy = saver ? LocationAccuracy.medium : LocationAccuracy.best;
    final filter = saver ? 15 : 3;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => AppleSettings(
        accuracy: accuracy,
        distanceFilter: filter,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      ),
      TargetPlatform.android => AndroidSettings(
        accuracy: accuracy,
        distanceFilter: filter,
        intervalDuration: Duration(seconds: saver ? 15 : 3),
        forceLocationManager: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Cresta está grabando tu recorrido',
          notificationText: 'Toca para volver al mapa',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
      _ => LocationSettings(accuracy: accuracy, distanceFilter: filter),
    };
  }
}
