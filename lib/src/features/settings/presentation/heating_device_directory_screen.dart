import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../application/heating_device_filter.dart';

class HeatingDeviceDirectoryScreen extends ConsumerStatefulWidget {
  const HeatingDeviceDirectoryScreen({super.key});

  @override
  ConsumerState<HeatingDeviceDirectoryScreen> createState() =>
      _HeatingDeviceDirectoryScreenState();
}

class _HeatingDeviceDirectoryScreenState
    extends ConsumerState<HeatingDeviceDirectoryScreen> {
  final _queryController = TextEditingController();
  String? _manufacturer;
  bool _showCustomOnly = false;
  double? _heightMm;
  int? _sectionCount;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

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
          final filter = HeatingDeviceFilter(
            query: _queryController.text,
            manufacturer: _manufacturer,
            minHeightMm: _heightMm == null ? null : _heightMm! - 50,
            maxHeightMm: _heightMm == null ? null : _heightMm! + 50,
            showCustomOnly: _showCustomOnly,
            minSections: _sectionCount,
            maxSections: _sectionCount,
          );
          final filtered = applyHeatingDeviceFilter(items, filter);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              TextField(
                controller: _queryController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Поиск',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _FilterStrip(
                children: [
                  ChoiceChip(
                    label: const Text('Все'),
                    selected: _manufacturer == null && !_showCustomOnly,
                    onSelected: (_) => setState(() {
                      _manufacturer = null;
                      _showCustomOnly = false;
                    }),
                  ),
                  ...['НРЗ', 'Оазис'].map(
                    (manufacturer) => ChoiceChip(
                      label: Text(manufacturer),
                      selected:
                          _manufacturer == manufacturer && !_showCustomOnly,
                      onSelected: (_) => setState(() {
                        _manufacturer = manufacturer;
                        _showCustomOnly = false;
                      }),
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Свои'),
                    selected: _showCustomOnly,
                    onSelected: (_) => setState(() {
                      _manufacturer = null;
                      _showCustomOnly = true;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _FilterStrip(
                children: [
                  for (final height in const [300, 350, 400, 500, 600])
                    ChoiceChip(
                      label: Text('$height мм'),
                      selected: _heightMm == height,
                      onSelected: (_) => setState(
                        () => _heightMm = _heightMm == height
                            ? null
                            : height.toDouble(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _FilterStrip(
                children: [
                  for (final sections in const [4, 6, 8, 10, 12])
                    ChoiceChip(
                      label: Text('$sections секц.'),
                      selected: _sectionCount == sections,
                      onSelected: (_) => setState(
                        () => _sectionCount = _sectionCount == sections
                            ? null
                            : sections,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Найдено: ${filtered.length} из ${items.length}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (filter.isActive)
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.close),
                      label: const Text('Сбросить'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('Нет приборов по фильтрам')),
                )
              else
                ...filtered.map(
                  (item) => _HeatingDeviceCard(
                    item: item,
                    onEdit: () => _openEditor(context, entry: item.entry),
                    onDelete: () => _deleteEntry(context, item),
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

  void _resetFilters() {
    setState(() {
      _queryController.clear();
      _manufacturer = null;
      _showCustomOnly = false;
      _heightMm = null;
      _sectionCount = null;
    });
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

  Future<void> _deleteEntry(
    BuildContext context,
    HeatingDeviceCatalogItem item,
  ) async {
    if (!item.isCustom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Базовые приборы нельзя удалить. Добавьте свой прибор.',
          ),
        ),
      );
      return;
    }
    await ref
        .read(projectEditorProvider)
        .deleteHeatingDeviceCatalogEntry(item.entry.id);
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final child in children) ...[child, const SizedBox(width: 8)],
        ],
      ),
    );
  }
}

class _HeatingDeviceCard extends StatelessWidget {
  const _HeatingDeviceCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final HeatingDeviceCatalogItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  entry.kind == HeatingDeviceKind.underfloorLoop.storageKey
                      ? Icons.grid_on_outlined
                      : Icons.thermostat_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (item.isCustom)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Chip(
                                label: Text('Свой'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_identity(entry)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.bolt_outlined,
                  label: '${entry.ratedPowerWatts.toStringAsFixed(0)} Вт',
                ),
                if (entry.sectionCount != null)
                  _InfoChip(
                    icon: Icons.view_column_outlined,
                    label: '${entry.sectionCount} секц.',
                  ),
                if (entry.heightMm != null)
                  _InfoChip(
                    icon: Icons.height,
                    label: '${entry.heightMm!.toStringAsFixed(0)} мм',
                  ),
                if (entry.workingPressureBar != null)
                  _InfoChip(
                    icon: Icons.speed_outlined,
                    label:
                        '${entry.workingPressureBar!.toStringAsFixed(0)} бар',
                  ),
                _InfoChip(
                  icon: Icons.thermostat,
                  label:
                      '${entry.designFlowTempC.toStringAsFixed(0)}/${entry.designReturnTempC.toStringAsFixed(0)}/${entry.roomTempC.toStringAsFixed(0)}',
                ),
              ],
            ),
            if (_source(entry).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _source(entry),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _identity(HeatingDeviceCatalogEntry entry) {
    final parts = [
      entry.manufacturer,
      entry.series,
      entry.model,
      if (entry.panelType != null) 'тип ${entry.panelType}',
    ].whereType<String>().where((value) => value.isNotEmpty);
    return parts.join(' • ');
  }

  String _source(HeatingDeviceCatalogEntry entry) {
    final parts = [
      entry.sourceLabel ?? entry.sourceUrl,
      entry.sourceCheckedAt,
    ].whereType<String>().where((value) => value.isNotEmpty);
    return parts.join(' • ');
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
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
  final seriesController = TextEditingController(text: entry?.series ?? '');
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
  final waterVolumeController = TextEditingController(
    text: entry?.waterVolumePerSection?.toString() ?? '',
  );
  final panelTypeController = TextEditingController(
    text: entry?.panelType ?? '',
  );
  final workingPressureController = TextEditingController(
    text: entry?.workingPressureBar?.toString() ?? '',
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
                  controller: seriesController,
                  decoration: const InputDecoration(labelText: 'Серия'),
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
                        controller: waterVolumeController,
                        decoration: const InputDecoration(
                          labelText: 'Объём воды на 1 секцию, л',
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
                        controller: panelTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Тип панели',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: workingPressureController,
                        decoration: const InputDecoration(
                          labelText: 'Рабочее давление, бар',
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
                        series: _optionalText(seriesController.text),
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
                        waterVolumePerSection: _parseOptionalDouble(
                          waterVolumeController.text,
                        ),
                        panelType: _optionalText(panelTypeController.text),
                        workingPressureBar: _parseOptionalDouble(
                          workingPressureController.text,
                        ),
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
                        sourceLabel: entry?.sourceLabel,
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
