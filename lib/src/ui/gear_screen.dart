import 'package:flutter/material.dart';

import '../app_services.dart';
import '../gear/gear.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'theme.dart';

String fmtKg(int grams) => '${(grams / 1000).toStringAsFixed(1)} kg';

/// Resumen del equipo en la pantalla de la expedición.
class GearCard extends StatelessWidget {
  const GearCard({super.key, required this.expeditionId});
  final String expeditionId;

  @override
  Widget build(BuildContext context) {
    final items = AppScope.of(context).gear.forExpedition(expeditionId);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    void open() => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GearScreen(expeditionId: expeditionId),
      ),
    );
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Arma la lista desde una plantilla y márcala mientras empacas.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: open,
            icon: const Icon(Icons.backpack_outlined),
            label: const Text('Armar lista de equipo'),
          ),
        ],
      );
    }
    final packed = items.where((i) => i.packed).length;
    final done = packed == items.length;
    return TonalCard(
      accent: done ? Andes.cyan : Andes.gold,
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Figure(
                  '$packed / ${items.length}',
                  'empacados',
                  size: 22,
                ),
              ),
              Expanded(
                child: Figure(fmtKg(totalGrams(items)), 'peso total', size: 22),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: packed / items.length,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            color: done ? Andes.cyan : Andes.gold,
          ),
        ],
      ),
    );
  }
}

/// Lista de equipo (diseño "Fleet Asset Management" de Stitch, adaptado): por categoría,
/// con peso y lo que ya está empacado.
class GearScreen extends StatelessWidget {
  const GearScreen({super.key, required this.expeditionId});
  final String expeditionId;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final store = services.gear;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.forExpedition(expeditionId);
        final packed = items.where((i) => i.packed).length;
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        return Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<Object>(
                onSelected: (v) async {
                  if (v is GearTemplate) {
                    final n = await store.addTemplate(expeditionId, v);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            n == 0
                                ? 'Ya tenías todo lo de esa plantilla.'
                                : 'Se agregaron $n objetos.',
                          ),
                        ),
                      );
                    }
                  } else if (v == 'unpack') {
                    await store.unpackAll(expeditionId);
                  } else if (v == 'clear' && context.mounted) {
                    final ok = await confirmDialog(
                      context,
                      title: 'Vaciar la lista',
                      body:
                          'Se quitan los ${items.length} objetos de esta expedición.',
                      action: 'Vaciar',
                    );
                    if (ok) await store.deleteExpedition(expeditionId);
                  }
                },
                itemBuilder: (_) => [
                  for (final t in GearTemplate.values)
                    PopupMenuItem(value: t, child: Text('Agregar: ${t.label}')),
                  if (items.isNotEmpty)
                    const PopupMenuItem(
                      value: 'unpack',
                      child: Text('Desmarcar todo (nueva salida)'),
                    ),
                  if (items.isNotEmpty)
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text('Vaciar lista'),
                    ),
                ],
              ),
            ],
          ),
          floatingActionButton: items.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar'),
                ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            children: [
              Text('EQUIPO', style: labelStyle(context, color: Andes.gold)),
              const SizedBox(height: 6),
              Text('Lista de equipo', style: signage(context, size: 32)),
              const SizedBox(height: 16),
              if (items.isEmpty) ...[
                Text(
                  'Empieza con una plantilla; luego quita o agrega lo que necesites.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                for (final t in GearTemplate.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TonalCard(
                      onTap: () => store.addTemplate(expeditionId, t),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.backpack_outlined,
                            color: Andes.cyan,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '${t.items().length} objetos · ${fmtKg(totalGrams(t.items()))}',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.add_rounded),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Empezar en blanco'),
                ),
              ] else ...[
                TonalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Figure(
                              '$packed / ${items.length}',
                              'empacados',
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: Figure(
                              fmtKg(totalGrams(items.where((i) => i.packed))),
                              'en la mochila de ${fmtKg(totalGrams(items))}',
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: packed / items.length,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
                ),
                for (final c in GearCategory.values)
                  if (items.where((i) => i.category == c).toList()
                      case final list when list.isNotEmpty) ...[
                    SectionTitle(
                      c.label,
                      trailing: Text(
                        '${list.where((i) => i.packed).length}/${list.length}',
                        style: dataStyle(context, size: 11, color: muted),
                      ),
                    ),
                    for (final item in list)
                      _ItemRow(expeditionId: expeditionId, item: item),
                  ],
                const SizedBox(height: 8),
                Text(
                  'Toca un objeto para editarlo; deslízalo para quitarlo.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context) =>
      editGearItem(context, expeditionId);
}

/// Agrega un objeto nuevo o edita [item] en la lista de [expeditionId].
Future<void> editGearItem(
  BuildContext context,
  String expeditionId, [
  GearItem? item,
]) async {
  final store = AppScope.of(context).gear;
  final result = await showModalBottomSheet<GearItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemForm(initial: item),
  );
  if (result == null) return;
  item == null
      ? await store.add(expeditionId, result)
      : await store.update(expeditionId, result);
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.expeditionId, required this.item});
  final String expeditionId;
  final GearItem item;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).gear;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Andes.terracottaContainer.withValues(alpha: .16),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Andes.terracottaContainer,
        ),
      ),
      onDismissed: (_) {
        store.remove(expeditionId, item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se quitó "${item.name}".'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () => store.add(expeditionId, item),
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () => editGearItem(context, expeditionId, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Checkbox(
                value: item.packed,
                onChanged: (v) => store.update(
                  expeditionId,
                  item.copyWith(packed: v ?? false),
                ),
              ),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: item.packed ? muted : null,
                    decoration: item.packed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (item.grams != null)
                Text(
                  item.grams! >= 1000 ? fmtKg(item.grams!) : '${item.grams} g',
                  style: dataStyle(context, size: 12, color: muted),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({this.initial});
  final GearItem? initial;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _grams = TextEditingController(
    text: widget.initial?.grams?.toString() ?? '',
  );
  late GearCategory _category = widget.initial?.category ?? GearCategory.other;

  @override
  void dispose() {
    _name.dispose();
    _grams.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final grams = int.tryParse(_grams.text.trim());
    final base = widget.initial;
    Navigator.pop(
      context,
      base == null
          ? GearItem(name: name, category: _category, grams: grams)
          : base.copyWith(
              name: name,
              category: _category,
              grams: grams,
              clearGrams: grams == null,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? 'Nuevo objeto' : 'Editar objeto',
            style: signage(context, size: 22),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: widget.initial == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Peso en gramos (opcional)',
            ),
          ),
          const SizedBox(height: 14),
          Text('Categoría', style: labelStyle(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in GearCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: _name,
            builder: (context, _) => FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : _submit,
              child: Text(widget.initial == null ? 'Agregar' : 'Guardar'),
            ),
          ),
        ],
      ),
    ),
  );
}
