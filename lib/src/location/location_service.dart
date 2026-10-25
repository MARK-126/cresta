import 'package:geolocator/geolocator.dart';

enum LocationStatus { granted, denied, deniedForever, serviceOff }

/// Ubicación del propio teléfono. Solo se pide permiso cuando el usuario toca "Mi ubicación".
class LocationService {
  Future<LocationStatus> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationStatus.serviceOff;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return switch (p) {
      LocationPermission.deniedForever => LocationStatus.deniedForever,
      LocationPermission.denied || LocationPermission.unableToDetermine => LocationStatus.denied,
      _ => LocationStatus.granted,
    };
  }

  /// Posiciones cada 10 m. En montaña conviene precisión alta; el filtro de distancia cuida la batería.
  Stream<Position> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      );
}
