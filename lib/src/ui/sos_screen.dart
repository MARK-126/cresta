import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_services.dart';
import '../location/location_service.dart';
import '../profile/emergency_profile.dart';
import '../profile/sos.dart';
import 'format.dart';
import 'panels.dart';
import 'profile_screen.dart';
import 'theme.dart';

/// Pantalla de auxilio: tu posición en todos los formatos que piden los rescatistas, tus
/// datos médicos y botones para llamar, mandar SMS y compartir. El GPS funciona sin señal.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key, this.expeditionName});

  /// Para el mensaje de auxilio (si se abrió desde una expedición).
  final String? expeditionName;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _Fix {
  const _Fix(this.lat, this.lng, this.altitude, this.accuracy, this.at);
  final double lat, lng;
  final double? altitude;
  final double accuracy;
  final DateTime at;
}

class _SosScreenState extends State<SosScreen> {
  late final AppServices _services = AppScope.of(context);
  StreamSubscription<dynamic>? _sub;
  Timer? _tick;
  _Fix? _fix;
  double? _ground;
  String? _problem;
  bool _wasAwake = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _start();
  }

  Future<void> _start() async {
    // La pantalla no se apaga mientras está abierta: hay que poder leer las coordenadas
    _wasAwake = await WakelockPlus.enabled.catchError((_) => false);
    unawaited(WakelockPlus.enable().catchError((_) {}));
    // "hace N s" avanza aunque no lleguen lecturas nuevas
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });

    // Lo último que tenga el grabador sirve mientras llega una lectura nueva
    final last = _services.recorder.lastFix;
    if (last != null) {
      _setFix(
        _Fix(last.lat, last.lng, last.altitude, last.accuracy, last.time),
      );
    }
    await _listenGps();
  }

  /// Pide permiso y escucha el GPS. Se puede repetir si el usuario enciende la ubicación.
  Future<void> _listenGps() async {
    setState(() => _problem = null);
    final status = await _services.location.ensurePermission();
    if (!mounted) return;
    if (status != LocationStatus.granted) {
      setState(
        () => _problem = status == LocationStatus.serviceOff
            ? 'La ubicación del teléfono está apagada. Actívala en los ajustes rápidos.'
            : 'Cresta no tiene permiso de ubicación. Actívalo en Ajustes → Apps → Cresta → Permisos.',
      );
      return;
    }
    await _sub?.cancel();
    _sub = _services.location.positions().listen(
      (p) => _setFix(
        _Fix(
          p.latitude,
          p.longitude,
          p.altitude == 0 && p.altitudeAccuracy == 0 ? null : p.altitude,
          p.accuracy,
          p.timestamp.toLocal(),
        ),
      ),
      onError: (_) {},
    );
  }

  Future<void> _setFix(_Fix f) async {
    setState(() {
      _fix = f;
      _problem = null;
    });
    // La altitud del relieve descargado es más confiable que la del GPS
    final ground = await _services.terrain.at(f.lng, f.lat);
    if (mounted) setState(() => _ground = ground);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    // Si una descarga de mapas ya la tenía encendida, se respeta
    if (!_wasAwake && !_services.maps.isDownloading) {
      WakelockPlus.disable().catchError((_) {});
    }
    super.dispose();
  }

  String _message(EmergencyProfile profile) {
    final f = _fix!;
    return sosMessage(
      lat: f.lat,
      lng: f.lng,
      altitude: _ground ?? f.altitude,
      accuracy: f.accuracy,
      at: f.at,
      profile: profile,
      expedition: widget.expeditionName,
    );
  }

  Future<void> _launch(Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(uri).catchError((_) => false);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la app del teléfono.')),
      );
    }
  }

  void _call(String number) =>
      _launch(Uri(scheme: 'tel', path: number.replaceAll(' ', '')));

  void _sms(EmergencyProfile profile) {
    final phones = profile.contacts
        .map((c) => c.phone.replaceAll(' ', ''))
        .join(',');
    // Codificado a mano: con queryParameters los espacios salen como "+" en algunas apps
    _launch(
      Uri.parse('sms:$phones?body=${Uri.encodeComponent(_message(profile))}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _services.profile,
      builder: (context, _) {
        final profile = _services.profile.profile;
        final f = _fix;
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        final age = f == null ? null : DateTime.now().difference(f.at);
        final altitude = _ground ?? f?.altitude;

        return Scaffold(
          appBar: AppBar(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                'EMERGENCIA',
                style: labelStyle(context, color: Andes.terracottaContainer),
              ),
              const SizedBox(height: 6),
              Text('SOS', style: signage(context, size: 40)),
              const SizedBox(height: 4),
              Text(
                'El GPS funciona sin señal. Dicta estas coordenadas por teléfono o radio.',
                style: TextStyle(color: muted, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 18),
              _CallButton(
                number: profile.emergencyNumber,
                onTap: () => _call(profile.emergencyNumber),
              ),
              const SizedBox(height: 8),
              Text(
                'Las llamadas de emergencia suelen entrar por cualquier red disponible, aunque no sea la de tu compañía.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SectionTitle('Tu posición'),
              if (f == null)
                TonalCard(
                  accent: _problem == null ? Andes.gold : Andes.error,
                  child: Row(
                    children: [
                      if (_problem == null) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          _problem ?? 'Buscando GPS… Al aire libre tarda unos segundos.',
                          style: TextStyle(
                            color: _problem == null ? Andes.gold : Andes.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_problem != null)
                        TextButton(
                          onPressed: _listenGps,
                          child: const Text('Reintentar'),
                        ),
                    ],
                  ),
                )
              else
                TonalCard(
                  accent: Andes.terracottaContainer,
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        formatDecimal(f.lat, f.lng),
                        style: dataStyle(
                          context,
                          size: 28,
                          weight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LATITUD, LONGITUD',
                        style: labelStyle(context).copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 14),
                      _Line('Grados', formatDms(f.lat, f.lng)),
                      _Line('UTM', '${toUtm(f.lat, f.lng)}'),
                      _Line(
                        'Altitud',
                        altitude == null ? '–' : '${fmtInt(altitude)} m',
                      ),
                      _Line(
                        'Precisión',
                        '± ${f.accuracy.round()} m · ${_ago(age!)}',
                        warn:
                            f.accuracy > 50 || age > const Duration(minutes: 5),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: f == null
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(
                                  text:
                                      '${formatDecimal(f.lat, f.lng)}\n${formatDms(f.lat, f.lng)}\nUTM ${toUtm(f.lat, f.lng)}',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Coordenadas copiadas.'),
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copiar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(
                      builder: (context) => FilledButton.tonalIcon(
                        onPressed: f == null
                            ? null
                            : () {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                SharePlus.instance.share(
                                  ShareParams(
                                    text: _message(profile),
                                    sharePositionOrigin: box == null
                                        ? null
                                        : box.localToGlobal(Offset.zero) &
                                              box.size,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Compartir'),
                      ),
                    ),
                  ),
                ],
              ),
              const SectionTitle('Avisar a tus contactos'),
              if (profile.contacts.isEmpty)
                Text(
                  'No tienes contactos de emergencia. Agrégalos en tu perfil para mandarles tu ubicación con un toque.',
                  style: TextStyle(color: muted, fontSize: 13),
                )
              else ...[
                FilledButton.icon(
                  onPressed: f == null ? null : () => _sms(profile),
                  icon: const Icon(Icons.sms_rounded),
                  label: Text(
                    'SMS con tu ubicación a ${profile.contacts.length == 1 ? profile.contacts.first.name : '${profile.contacts.length} contactos'}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Un SMS necesita muy poca señal: si no sale, intenta desde un punto más alto.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                for (final c in profile.contacts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_rounded),
                    title: Text(c.name),
                    subtitle: Text(
                      [
                        c.phone,
                        c.relation,
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Llamar a ${c.name}',
                      icon: const Icon(Icons.call_rounded, color: Andes.cyan),
                      onPressed: () => _call(c.phone),
                    ),
                  ),
              ],
              const SectionTitle('Datos médicos'),
              if (profile.isEmpty)
                TonalCard(
                  accent: Andes.gold,
                  onTap: () => openProfile(context),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Completa tu perfil de emergencia: nombre, tipo de sangre, alergias y contactos.',
                          style: TextStyle(
                            color: Andes.gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Andes.gold),
                    ],
                  ),
                )
              else
                TonalCard(
                  onTap: () => openProfile(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile.name.isNotEmpty)
                        _Line('Nombre', profile.name),
                      if (profile.bloodType.isNotEmpty)
                        _Line('Sangre', profile.bloodType),
                      if (profile.allergies.isNotEmpty)
                        _Line('Alergias', profile.allergies),
                      if (profile.conditions.isNotEmpty)
                        _Line('Condiciones', profile.conditions),
                      if (profile.insurance.isNotEmpty)
                        _Line('Seguro', profile.insurance),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _ago(Duration d) => d.inSeconds < 60
      ? 'hace ${d.inSeconds} s'
      : d.inMinutes < 60
      ? 'hace ${d.inMinutes} min'
      : 'hace ${d.inHours} h';
}

/// Botón de llamada de emergencia: el más grande de la pantalla.
class _CallButton extends StatelessWidget {
  const _CallButton({required this.number, required this.onTap});
  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Andes.terracottaContainer,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call_rounded, color: Andes.onTerracotta, size: 28),
            const SizedBox(width: 12),
            Text(
              'LLAMAR AL $number',
              style: const TextStyle(
                color: Andes.onTerracotta,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.warn = false});
  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label.toUpperCase(),
            style: labelStyle(context).copyWith(fontSize: 10),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: dataStyle(
              context,
              size: 14,
              weight: FontWeight.w700,
              color: warn ? Andes.gold : null,
            ),
          ),
        ),
      ],
    ),
  );
}
