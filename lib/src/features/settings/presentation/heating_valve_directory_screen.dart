import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/providers.dart';

class HeatingValveDirectoryScreen extends ConsumerWidget {
  const HeatingValveDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(heatingValveCatalogItemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Справочник арматуры')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: itemsAsync.when(
        data: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            final entry = item.entry;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: Text(entry.title),
                subtitle: Text(
                  '${entry.kind.label} · DN ${entry.connectionDiameterMm.toStringAsFixed(0)} · Kvs ${entry.kvs.toStringAsFixed(2)}'
                  '${entry.settingKvMap.isEmpty ? '' : ' · ${entry.settingKvMap.length} настроек'}',
                ),
                trailing: item.isCustom
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditor(context, ref, entry: entry);
                          } else if (value == 'delete') {
                            ref
                                .read(projectEditorProvider)
                                .deleteHeatingValveCatalogEntry(entry.id);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Редактировать'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Удалить'),
                          ),
                        ],
                      )
                    : const Chip(label: Text('Seed')),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка справочника: $error')),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    HeatingValveCatalogEntry? entry,
  }) async {
    final updated = await showDialog<HeatingValveCatalogEntry>(
      context: context,
      builder: (context) => _HeatingValveEditorDialog(entry: entry),
    );
    if (updated == null) {
      return;
    }
    await ref.read(projectEditorProvider).saveHeatingValveCatalogEntry(updated);
  }
}

class _HeatingValveEditorDialog extends StatefulWidget {
  const _HeatingValveEditorDialog({this.entry});

  final HeatingValveCatalogEntry? entry;

  @override
  State<_HeatingValveEditorDialog> createState() =>
      _HeatingValveEditorDialogState();
}

class _HeatingValveEditorDialogState extends State<_HeatingValveEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _manufacturerController;
  late final TextEditingController _modelController;
  late final TextEditingController _diameterController;
  late final TextEditingController _kvsController;
  late final TextEditingController _settingsController;
  late HeatingValveKind _kind;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _kind = entry?.kind ?? HeatingValveKind.balancingValve;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _manufacturerController = TextEditingController(
      text: entry?.manufacturer ?? '',
    );
    _modelController = TextEditingController(text: entry?.model ?? '');
    _diameterController = TextEditingController(
      text: (entry?.connectionDiameterMm ?? 15).toStringAsFixed(0),
    );
    _kvsController = TextEditingController(
      text: (entry?.kvs ?? 2.5).toStringAsFixed(2),
    );
    _settingsController = TextEditingController(
      text: _formatSettings(entry?.settingKvMap ?? const {}),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _diameterController.dispose();
    _kvsController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Новая арматура' : 'Арматура'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<HeatingValveKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Тип'),
              items: HeatingValveKind.values
                  .map(
                    (kind) =>
                        DropdownMenuItem(value: kind, child: Text(kind.label)),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _kind = value ?? _kind;
              }),
            ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: _manufacturerController,
              decoration: const InputDecoration(labelText: 'Производитель'),
            ),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: 'Модель'),
            ),
            TextField(
              controller: _diameterController,
              decoration: const InputDecoration(labelText: 'DN, мм'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextField(
              controller: _kvsController,
              decoration: const InputDecoration(labelText: 'Kvs'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (_kind.isRegulating)
              TextField(
                controller: _settingsController,
                decoration: const InputDecoration(
                  labelText: 'Настройки Kv',
                  hintText: '1=0.12, 2=0.30',
                ),
                maxLines: 2,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final now = DateTime.now().millisecondsSinceEpoch;
            Navigator.of(context).pop(
              HeatingValveCatalogEntry(
                id: widget.entry?.id ?? 'custom-valve-$now',
                kind: _kind,
                title: _titleController.text.trim().isEmpty
                    ? _kind.label
                    : _titleController.text.trim(),
                manufacturer: _emptyToNull(_manufacturerController.text),
                model: _emptyToNull(_modelController.text),
                connectionDiameterMm: _parseDouble(
                  _diameterController.text,
                  fallback: 15,
                ),
                kvs: _parseDouble(_kvsController.text, fallback: 1),
                settingKvMap: _kind.isRegulating
                    ? _parseSettings(_settingsController.text)
                    : const {},
                isCustom: true,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

String _formatSettings(Map<String, double> settings) {
  return settings.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(', ');
}

Map<String, double> _parseSettings(String value) {
  final result = <String, double>{};
  for (final part in value.split(',')) {
    final pair = part.split('=');
    if (pair.length != 2) {
      continue;
    }
    final kv = double.tryParse(pair[1].trim().replaceAll(',', '.'));
    if (kv != null && kv > 0) {
      result[pair[0].trim()] = kv;
    }
  }
  return result;
}

double _parseDouble(String value, {required double fallback}) {
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
