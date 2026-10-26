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

  /// Posiciones cada 10 m, solo con la app abierta (para "Mi ubicación").
  Stream<Position> positions() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );

  /// Posiciones para grabar el recorrido, también con la pantalla apagada:
  /// en iOS con el indicador azul de ubicación, en Android con una notificación fija.
  Stream<GpsFix> recording(RecordingMode mode) {
    final saver = mode == RecordingMode.saver;
    final accuracy = saver ? LocationAccuracy.medium : LocationAccuracy.best;
    final filter = saver ? 15 : 3;
    final LocationSettings settings = switch (defaultTargetPlatform) {
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
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Cresta está grabando tu recorrido',
          notificationText: 'Toca para volver al mapa',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
      _ => LocationSettings(accuracy: accuracy, distanceFilter: filter),
    };
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => GpsFix(
        time: p.timestamp.toLocal(), // el GPS la entrega en UTC
        lng: p.longitude,
        lat: p.latitude,
        altitude: p.altitude == 0 && p.altitudeAccuracy == 0
            ? null
            : p.altitude,
        accuracy: p.accuracy,
        speed: p.speed < 0 ? null : p.speed,
      ),
    );
  }
}
