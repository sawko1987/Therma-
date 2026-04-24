import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';

class HeatingDeviceDirectoryScreen extends ConsumerStatefulWidget {
  const HeatingDeviceDirectoryScreen({super.key});

  @override
  ConsumerState<HeatingDeviceDirectoryScreen> createState() =>
      _HeatingDeviceDirectoryScreenState();
}

class _HeatingDeviceDirectoryScreenState
    extends ConsumerState<HeatingDeviceDirectoryScreen> {
  String? _manufacturer;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(heatingDeviceCatalogItemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Справочник приборов отопления')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: entriesAsync.when(
        data: (items) {
          final manufacturers = {
            for (final item in items)
              if ((item.entry.manufacturer ?? '').isNotEmpty)
                item.entry.manufacturer!,
          }.toList()..sort();
          final filtered = items
              .where(
                (item) =>
                    _manufacturer == null ||
                    item.entry.manufacturer == _manufacturer,
              )
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Все'),
                    selected: _manufacturer == null,
                    onSelected: (_) => setState(() => _manufacturer = null),
                  ),
                  ...manufacturers.map(
                    (manufacturer) => ChoiceChip(
                      label: Text(manufacturer),
                      selected: _manufacturer == manufacturer,
                      onSelected: (_) =>
                          setState(() => _manufacturer = manufacturer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...filtered.map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(
                      item.entry.kind ==
                              HeatingDeviceKind.underfloorLoop.storageKey
                          ? Icons.grid_on_outlined
                          : Icons.thermostat_outlined,
                    ),
                    title: Text(item.entry.title),
                    subtitle: Text(_subtitle(item.entry, item.isCustom)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _openEditor(context, entry: item.entry);
                        } else if (value == 'delete' && item.isCustom) {
                          await ref
                              .read(projectEditorProvider)
                              .deleteHeatingDeviceCatalogEntry(item.entry.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Редактировать'),
                        ),
                        if (item.isCustom)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Удалить'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка справочника: $error')),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    HeatingDeviceCatalogEntry? entry,
  }) async {
    final edited = await showHeatingDeviceEditorSheet(context, entry: entry);
    if (!mounted || edited == null) {
      return;
    }
    await ref.read(projectEditorProvider).saveHeatingDeviceCatalogEntry(edited);
  }

  String _subtitle(HeatingDeviceCatalogEntry entry, bool custom) {
    final parts = [
      if (custom) 'Пользовательский',
      if (entry.manufacturer != null) entry.manufacturer!,
      if (entry.panelType != null) 'тип ${entry.panelType}',
      if (entry.sectionCount != null) '${entry.sectionCount} секц.',
      '${entry.ratedPowerWatts.toStringAsFixed(0)} Вт',
      '${entry.designFlowTempC.toStringAsFixed(0)}/${entry.designReturnTempC.toStringAsFixed(0)}/${entry.roomTempC.toStringAsFixed(0)}',
    ];
    return parts.join(' • ');
  }
}

Future<HeatingDeviceCatalogEntry?> showHeatingDeviceEditorSheet(
  BuildContext context, {
  HeatingDeviceCatalogEntry? entry,
}) async {
  final titleController = TextEditingController(text: entry?.title ?? '');
  final manufacturerController = TextEditingController(
    text: entry?.manufacturer ?? '',
  );
  final modelController = TextEditingController(text: entry?.model ?? '');
  final powerController = TextEditingController(
    text: (entry?.ratedPowerWatts ?? 1000).toStringAsFixed(0),
  );
  final widthController = TextEditingController(
    text: entry?.widthMm?.toStringAsFixed(0) ?? '',
  );
  final heightController = TextEditingController(
    text: entry?.heightMm?.toStringAsFixed(0) ?? '',
  );
  final depthController = TextEditingController(
    text: entry?.depthMm?.toStringAsFixed(0) ?? '',
  );
  final sectionController = TextEditingController(
    text: entry?.sectionCount?.toString() ?? '',
  );
  final panelTypeController = TextEditingController(
    text: entry?.panelType ?? '',
  );
  final flowController = TextEditingController(
    text: (entry?.designFlowTempC ?? 75).toStringAsFixed(0),
  );
  final returnController = TextEditingController(
    text: (entry?.designReturnTempC ?? 65).toStringAsFixed(0),
  );
  final roomController = TextEditingController(
    text: (entry?.roomTempC ?? 20).toStringAsFixed(0),
  );
  final exponentController = TextEditingController(
    text: (entry?.heatOutputExponent ?? 1.3).toString(),
  );
  final sourceUrlController = TextEditingController(
    text: entry?.sourceUrl ?? '',
  );
  var kind = parseHeatingDeviceKind(
    entry?.kind ?? HeatingDeviceKind.radiator.storageKey,
  );

  return showModalBottomSheet<HeatingDeviceCatalogEntry>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry == null
                      ? 'Новый прибор отопления'
                      : 'Редактирование прибора',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<HeatingDeviceKind>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Тип'),
                  items: HeatingDeviceKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => kind = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: manufacturerController,
                  decoration: const InputDecoration(labelText: 'Производитель'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(labelText: 'Модель'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: powerController,
                  decoration: const InputDecoration(labelText: 'Мощность, Вт'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widthController,
                        decoration: const InputDecoration(
                          labelText: 'Ширина, мм',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: heightController,
                        decoration: const InputDecoration(
                          labelText: 'Высота, мм',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: depthController,
                        decoration: const InputDecoration(
                          labelText: 'Глубина, мм',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sectionController,
                        decoration: const InputDecoration(labelText: 'Секций'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: panelTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Тип панели',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: flowController,
                        decoration: const InputDecoration(
                          labelText: 'Подача, °C',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: returnController,
                        decoration: const InputDecoration(
                          labelText: 'Обратка, °C',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: roomController,
                        decoration: const InputDecoration(
                          labelText: 'Комната, °C',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exponentController,
                  decoration: const InputDecoration(labelText: 'Показатель n'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sourceUrlController,
                  decoration: const InputDecoration(labelText: 'Источник'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      HeatingDeviceCatalogEntry(
                        id:
                            entry?.id ??
                            'custom-heating-device-${DateTime.now().millisecondsSinceEpoch}',
                        kind: kind.storageKey,
                        title: _requiredText(
                          titleController.text,
                          fallback: kind.label,
                        ),
                        manufacturer: _optionalText(
                          manufacturerController.text,
                        ),
                        model: _optionalText(modelController.text),
                        ratedPowerWatts: _parseDouble(
                          powerController.text,
                          fallback: 1000,
                        ),
                        widthMm: _parseOptionalDouble(widthController.text),
                        heightMm: _parseOptionalDouble(heightController.text),
                        depthMm: _parseOptionalDouble(depthController.text),
                        sectionCount: int.tryParse(
                          sectionController.text.trim(),
                        ),
                        panelType: _optionalText(panelTypeController.text),
                        designFlowTempC: _parseDouble(
                          flowController.text,
                          fallback: 75,
                        ),
                        designReturnTempC: _parseDouble(
                          returnController.text,
                          fallback: 65,
                        ),
                        roomTempC: _parseDouble(
                          roomController.text,
                          fallback: 20,
                        ),
                        heatOutputExponent: _parseOptionalDouble(
                          exponentController.text,
                        ),
                        sourceUrl: _optionalText(sourceUrlController.text),
                        sourceCheckedAt: DateTime.now()
                            .toIso8601String()
                            .split('T')
                            .first,
                        isCustom: true,
                      ),
                    );
                  },
                  child: const Text('Сохранить прибор'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _requiredText(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String? _optionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double _parseDouble(String value, {required double fallback}) {
  return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
}

double? _parseOptionalDouble(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return double.tryParse(trimmed.replaceAll(',', '.'));
}
