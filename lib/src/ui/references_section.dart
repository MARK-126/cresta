import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_services.dart';
import '../references/references.dart';
import 'offline_widgets.dart';
import 'theme.dart';

/// Referencias de la expedición: fotos y PDF (copiados a la app), enlaces y teléfonos.
class ReferencesSection extends StatelessWidget {
  const ReferencesSection({super.key, required this.expeditionId});
  final String expeditionId;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).references;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final refs = store.forExpedition(expeditionId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (refs.isEmpty)
              Text(
                'Guarda el permiso, el croquis, la ruta de Wikiloc o el teléfono del refugio. Las fotos y PDF quedan en el teléfono: se abren sin señal.',
                style: TextStyle(color: muted, fontSize: 13, height: 1.35),
              ),
            for (final r in refs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReferenceTile(expeditionId: expeditionId, reference: r),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Agregar referencia'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    final kind = await showModalBottomSheet<ReferenceKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Agregar referencia', style: signage(context, size: 22)),
              const SizedBox(height: 8),
              for (final (k, icon, title, sub) in const [
                (
                  ReferenceKind.file,
                  Icons.description_outlined,
                  'Foto o PDF',
                  'Permiso, croquis, mapa escaneado…',
                ),
                (
                  ReferenceKind.link,
                  Icons.link_rounded,
                  'Enlace',
                  'Ruta en Wikiloc, página del parque… (abre con internet)',
                ),
                (
                  ReferenceKind.phone,
                  Icons.call_rounded,
                  'Teléfono',
                  'Refugio, guardaparques, guía…',
                ),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: Andes.cyan),
                  title: Text(title),
                  subtitle: Text(sub),
                  onTap: () => Navigator.pop(context, k),
                ),
            ],
          ),
        ),
      ),
    );
    if (kind == null || !context.mounted) return;
    final store = AppScope.of(context).references;
    final messenger = ScaffoldMessenger.of(context);
    switch (kind) {
      case ReferenceKind.file:
        final f = await FilePicker.pickFile(
          dialogTitle: 'Elige una foto o un PDF',
        );
        if (f == null || !context.mounted) return;
        final bytes = await f.readAsBytes();
        final dot = f.name.lastIndexOf('.');
        await store.addFile(
          expeditionId,
          title: dot > 0 ? f.name.substring(0, dot) : f.name,
          fileName: f.name,
          bytes: bytes,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text('Guardado en el teléfono: ${_size(bytes.length)}.'),
          ),
        );
      case ReferenceKind.link || ReferenceKind.phone:
        final values = await showModalBottomSheet<(String, String)>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _TwoFieldForm(kind: kind),
        );
        if (values == null) return;
        kind == ReferenceKind.link
            ? await store.addLink(expeditionId, values.$1, values.$2)
            : await store.addPhone(expeditionId, values.$1, values.$2);
    }
  }

  static String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({required this.expeditionId, required this.reference});
  final String expeditionId;
  final Reference reference;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).references;
    final r = reference;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final (IconData icon, String detail) = switch (r.kind) {
      ReferenceKind.file when r.isImage => (
        Icons.image_outlined,
        'Foto · sin señal',
      ),
      ReferenceKind.file when r.isPdf => (
        Icons.picture_as_pdf_outlined,
        'PDF · sin señal',
      ),
      ReferenceKind.file => (
        Icons.insert_drive_file_outlined,
        '${r.extension.toUpperCase()} · sin señal',
      ),
      ReferenceKind.link => (
        Icons.link_rounded,
        Uri.tryParse(r.value)?.host ?? r.value,
      ),
      ReferenceKind.phone => (Icons.call_rounded, r.value),
    };
    return TonalCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      onTap: () => _open(context),
      child: Row(
        children: [
          if (r.isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                store.fileOf(expeditionId, r),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                cacheWidth: 132,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
            )
          else
            SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: Andes.cyan),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final name = await askText(
                  context,
                  title: 'Nombre',
                  initial: r.title,
                );
                if (name != null) await store.rename(expeditionId, r, name);
              } else if (v == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'Quitar "${r.title}"',
                  body: r.kind == ReferenceKind.file
                      ? 'Se borra la copia guardada en la app.'
                      : 'Se quita de la expedición.',
                  action: 'Quitar',
                );
                if (ok) await store.remove(expeditionId, r);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Cambiar nombre')),
              PopupMenuItem(value: 'delete', child: Text('Quitar')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final store = AppScope.of(context).references;
    final messenger = ScaffoldMessenger.of(context);
    final r = reference;
    switch (r.kind) {
      case ReferenceKind.file when r.isImage:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                title: Text(r.title),
              ),
              // Para leer un croquis o un permiso hay que poder hacer zoom
              body: InteractiveViewer(
                maxScale: 8,
                child: Center(child: Image.file(store.fileOf(expeditionId, r))),
              ),
            ),
          ),
        );
      case ReferenceKind.file:
        final res = await OpenFilex.open(store.fileOf(expeditionId, r).path);
        if (res.type != ResultType.done) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No hay una app para abrir este archivo.'),
            ),
          );
        }
      case ReferenceKind.link:
        final ok = await launchUrl(
          Uri.parse(r.value),
          mode: LaunchMode.externalApplication,
        ).catchError((_) => false);
        if (!ok) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el enlace.')),
          );
        }
      case ReferenceKind.phone:
        await launchUrl(Uri(scheme: 'tel', path: r.value.replaceAll(' ', '')))
            .catchError((_) => false);
    }
  }
}

class _TwoFieldForm extends StatefulWidget {
  const _TwoFieldForm({required this.kind});
  final ReferenceKind kind;

  @override
  State<_TwoFieldForm> createState() => _TwoFieldFormState();
}

class _TwoFieldFormState extends State<_TwoFieldForm> {
  final _title = TextEditingController();
  final _value = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.kind == ReferenceKind.link;
    return Padding(
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
            link ? 'Nuevo enlace' : 'Nuevo teléfono',
            style: signage(context, size: 22),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nombre',
              hintText: link ? 'Ruta en Wikiloc' : 'Refugio, guardaparques…',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _value,
            keyboardType: link ? TextInputType.url : TextInputType.phone,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: link ? 'Dirección (URL)' : 'Teléfono',
              hintText: link ? 'es.wikiloc.com/…' : '+52 …',
            ),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: Listenable.merge([_title, _value]),
            builder: (context, _) => FilledButton(
              onPressed:
                  _title.text.trim().isEmpty || _value.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, (
                      _title.text.trim(),
                      _value.text.trim(),
                    )),
              child: const Text('Agregar'),
            ),
          ),
        ],
      ),
    );
  }
}
