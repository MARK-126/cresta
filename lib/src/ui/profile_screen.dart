import 'package:flutter/material.dart';

import '../app_services.dart';
import '../profile/emergency_profile.dart';
import 'panels.dart';
import 'theme.dart';

/// Perfil de emergencia (diseño "Athlete Registration" de Stitch, adaptado): datos que
/// necesitan los rescatistas y a quién avisar. Se guarda solo en el teléfono.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _bloodTypes = ['O+', 'O−', 'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−'];

  late final ProfileStore _store = AppScope.of(context).profile;
  late final _name = TextEditingController(text: _store.profile.name);
  late final _allergies = TextEditingController(text: _store.profile.allergies);
  late final _conditions = TextEditingController(
    text: _store.profile.conditions,
  );
  late final _insurance = TextEditingController(text: _store.profile.insurance);
  late final _number = TextEditingController(
    text: _store.profile.emergencyNumber,
  );
  late String _blood = _store.profile.bloodType;
  late List<EmergencyContact> _contacts = List.of(_store.profile.contacts);

  @override
  void dispose() {
    for (final c in [_name, _allergies, _conditions, _insurance, _number]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _store.save(
      EmergencyProfile(
        name: _name.text.trim(),
        bloodType: _blood,
        allergies: _allergies.text.trim(),
        conditions: _conditions.text.trim(),
        insurance: _insurance.text.trim(),
        emergencyNumber: _number.text.trim().isEmpty
            ? '911'
            : _number.text.trim(),
        contacts: _contacts,
      ),
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Perfil de emergencia guardado.')),
    );
    navigator.pop();
  }

  Future<void> _editContact([int? index]) async {
    final c = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _ContactForm(initial: index == null ? null : _contacts[index]),
    );
    if (c == null) return;
    setState(() {
      _contacts = List.of(_contacts);
      if (index == null) {
        _contacts.add(c);
      } else {
        _contacts[index] = c;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            'PERFIL DE EMERGENCIA',
            style: labelStyle(context, color: Andes.terracottaContainer),
          ),
          const SizedBox(height: 6),
          Text('Tus datos', style: signage(context, size: 32)),
          const SizedBox(height: 6),
          Text(
            'Aparecen en la pantalla SOS y en el mensaje de auxilio. Se guardan solo en este teléfono.',
            style: TextStyle(color: muted, fontSize: 13, height: 1.35),
          ),
          const SectionTitle('Quién eres'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SectionTitle('Datos médicos'),
          Text('Tipo de sangre', style: labelStyle(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in _bloodTypes)
                ChoiceChip(
                  label: Text(b),
                  selected: _blood == b,
                  onSelected: (on) => setState(() => _blood = on ? b : ''),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _allergies,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alergias',
              hintText: 'Penicilina, picadura de abeja…',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _conditions,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Condiciones y medicamentos',
              hintText: 'Asma (salbutamol), diabetes…',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _insurance,
            decoration: const InputDecoration(
              labelText: 'Seguro médico (opcional)',
              hintText: 'Aseguradora y número de póliza',
            ),
          ),
          const SectionTitle('A quién avisar'),
          for (var i = 0; i < _contacts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TonalCard(
                accent: Andes.terracottaContainer,
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                onTap: () => _editContact(i),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _contacts[i].name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            [
                              _contacts[i].phone,
                              _contacts[i].relation,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: dataStyle(
                              context,
                              size: 12.5,
                              color: muted,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(
                        () => _contacts = List.of(_contacts)..removeAt(i),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _editContact,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Agregar contacto'),
          ),
          const SectionTitle('Número de emergencias'),
          TextField(
            controller: _number,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Número',
              helperText: '911 en México y Argentina; 112 en Europa y Chile. Cámbialo según el país de tu expedición.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 28),
          GlowButton(
            label: 'Guardar',
            icon: Icons.check_rounded,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({this.initial});
  final EmergencyContact? initial;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _relation = TextEditingController(text: widget.initial?.relation);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.initial == null ? 'Nuevo contacto' : 'Editar contacto',
          style: signage(context, size: 22),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono',
            hintText: 'Con lada internacional: +52 55 1234 5678',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _relation,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Relación (opcional)',
            hintText: 'Pareja, hermana, guía…',
          ),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: Listenable.merge([_name, _phone]),
          builder: (context, _) => FilledButton(
            onPressed: _name.text.trim().isEmpty || _phone.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    EmergencyContact(
                      name: _name.text.trim(),
                      phone: _phone.text.trim(),
                      relation: _relation.text.trim(),
                    ),
                  ),
            child: const Text('Listo'),
          ),
        ),
      ],
    ),
  );
}

/// Abre el perfil de emergencia.
Future<void> openProfile(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
);
