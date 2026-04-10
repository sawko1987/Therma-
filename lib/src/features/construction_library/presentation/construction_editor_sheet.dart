import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import 'material_catalog_support.dart';

typedef CustomMaterialSaver =
    Future<MaterialEntry> Function(MaterialEntry material);

Future<Construction?> showConstructionEditor(
  BuildContext context, {
  required CatalogSnapshot catalog,
  required List<MaterialCatalogEntry> materialEntries,
  Construction? construction,
  CustomMaterialSaver? onSaveCustomMaterial,
  List<ConstructionElementKind>? allowedElementKinds,
}) async {
  final titleController = TextEditingController(
    text: construction?.title ?? '',
  );
  final availableKinds =
      (allowedElementKinds == null || allowedElementKinds.isEmpty)
      ? ConstructionElementKind.values
      : allowedElementKinds;
  var selectedKind = availableKinds.contains(construction?.elementKind)
      ? construction!.elementKind
      : availableKinds.first;
  var selectedFloorType = construction?.floorConstructionType;
  var selectedCrawlSpaceVentilationMode =
      construction?.crawlSpaceVentilationMode;
  final layers = [...?construction?.layers];
  final availableEntries = [...materialEntries];
  final availableMaterials = [
    for (final entry in availableEntries) entry.material,
  ];
  if (layers.isEmpty && availableMaterials.isNotEmpty) {
    layers.add(
      ConstructionLayer(
        id: buildEditorEntityId('layer'),
        materialId: availableMaterials.first.id,
        kind: LayerKind.solid,
        thicknessMm: 100,
      ),
    );
  }

  final result = await showModalBottomSheet<Construction>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final materialMap = {
            for (final item in availableMaterials) item.id: item,
          };
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  construction == null
                      ? 'Новая конструкция'
                      : 'Редактирование конструкции',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ConstructionElementKind>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(
                    labelText: 'Тип конструкции',
                  ),
                  items: availableKinds
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedKind = value;
                        if (value == ConstructionElementKind.floor) {
                          selectedFloorType ??= FloorConstructionType.onGround;
                        } else {
                          selectedFloorType = null;
                          selectedCrawlSpaceVentilationMode = null;
                        }
                      });
                    }
                  },
                ),
                if (selectedKind == ConstructionElementKind.floor) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<FloorConstructionType>(
                    initialValue:
                        selectedFloorType ?? FloorConstructionType.onGround,
                    decoration: const InputDecoration(labelText: 'Тип пола'),
                    items: FloorConstructionType.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedFloorType = value;
                          if (value != FloorConstructionType.overCrawlSpace) {
                            selectedCrawlSpaceVentilationMode = null;
                          }
                        });
                      }
                    },
                  ),
                  if (selectedFloorType ==
                      FloorConstructionType.overCrawlSpace) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CrawlSpaceVentilationMode>(
                      initialValue: selectedCrawlSpaceVentilationMode,
                      decoration: const InputDecoration(
                        labelText: 'Вентиляция техподполья',
                      ),
                      items: CrawlSpaceVentilationMode.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCrawlSpaceVentilationMode = value;
                        });
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Слои конструкции',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final layer = await showLayerEditor(
                          context,
                          materialEntries: availableEntries,
                          onSaveCustomMaterial: onSaveCustomMaterial,
                        );
                        if (layer == null) {
                          return;
                        }
                        _upsertMaterial(availableMaterials, layer.material);
                        _upsertMaterialEntry(
                          availableEntries,
                          MaterialCatalogEntry(
                            material: layer.material,
                            source: layer.material.isCustom
                                ? MaterialCatalogSource.custom
                                : MaterialCatalogSource.seed,
                            isFavorite: false,
                          ),
                        );
                        setState(() => layers.add(layer.layer));
                      },
                      child: const Text('Добавить слой'),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ...layers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final layer = entry.value;
                          final material = materialMap[layer.materialId];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              tileColor: const Color(0xFFF9F7F2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              title: Text(
                                _materialLabel(
                                  material,
                                  fallback: layer.materialId,
                                ),
                              ),
                              subtitle: Text(
                                '${material?.category ?? 'Материал'} • ${layer.kind.label} • ${layer.thicknessMm.toStringAsFixed(0)} мм • ${layer.enabled ? 'в расчёте' : 'выключен'}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'up':
                                      if (index > 0) {
                                        final moved = layers.removeAt(index);
                                        layers.insert(index - 1, moved);
                                        setState(() {});
                                      }
                                    case 'down':
                                      if (index < layers.length - 1) {
                                        final moved = layers.removeAt(index);
                                        layers.insert(index + 1, moved);
                                        setState(() {});
                                      }
                                    case 'toggle':
                                      layers[index] = layer.copyWith(
                                        enabled: !layer.enabled,
                                      );
                                      setState(() {});
                                    case 'edit':
                                      final updated = await showLayerEditor(
                                        context,
                                        materialEntries: availableEntries,
                                        layer: layer,
                                        onSaveCustomMaterial:
                                            onSaveCustomMaterial,
                                      );
                                      if (updated != null) {
                                        _upsertMaterial(
                                          availableMaterials,
                                          updated.material,
                                        );
                                        _upsertMaterialEntry(
                                          availableEntries,
                                          MaterialCatalogEntry(
                                            material: updated.material,
                                            source: updated.material.isCustom
                                                ? MaterialCatalogSource.custom
                                                : MaterialCatalogSource.seed,
                                            isFavorite: false,
                                          ),
                                        );
                                        layers[index] = updated.layer;
                                        setState(() {});
                                      }
                                    case 'delete':
                                      layers.removeAt(index);
                                      setState(() {});
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'up',
                                    child: Text('Переместить внутрь'),
                                  ),
                                  PopupMenuItem(
                                    value: 'down',
                                    child: Text('Переместить наружу'),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text('Вкл/выкл слой'),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Редактировать слой'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Удалить слой'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed:
                      layers.isEmpty ||
                          (selectedKind == ConstructionElementKind.floor &&
                              selectedFloorType ==
                                  FloorConstructionType.overCrawlSpace &&
                              selectedCrawlSpaceVentilationMode == null)
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            Construction(
                              id:
                                  construction?.id ??
                                  buildEditorEntityId('construction'),
                              title: requiredEditorText(
                                titleController.text,
                                fallback: selectedKind.label,
                              ),
                              elementKind: selectedKind,
                              layers: List.unmodifiable(layers),
                              floorConstructionType:
                                  selectedKind == ConstructionElementKind.floor
                                  ? selectedFloorType ??
                                        FloorConstructionType.onGround
                                  : null,
                              crawlSpaceVentilationMode:
                                  selectedKind ==
                                          ConstructionElementKind.floor &&
                                      selectedFloorType ==
                                          FloorConstructionType.overCrawlSpace
                                  ? selectedCrawlSpaceVentilationMode
                                  : null,
                            ),
                          );
                        },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  return result;
}

class LayerEditorResult {
  const LayerEditorResult({required this.layer, required this.material});

  final ConstructionLayer layer;
  final MaterialEntry material;
}

Future<LayerEditorResult?> showLayerEditor(
  BuildContext context, {
  required List<MaterialCatalogEntry> materialEntries,
  ConstructionLayer? layer,
  CustomMaterialSaver? onSaveCustomMaterial,
}) async {
  if (materialEntries.isEmpty) {
    return null;
  }
  final thicknessController = TextEditingController(
    text: (layer?.thicknessMm ?? 100).toString(),
  );
  final localEntries = [...materialEntries];
  final localMaterials = [for (final entry in localEntries) entry.material];
  var selectedMaterialId = layer?.materialId ?? localMaterials.first.id;
  var selectedKind = layer?.kind ?? LayerKind.solid;
  var enabled = layer?.enabled ?? true;

  final result = await showModalBottomSheet<LayerEditorResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final selectedMaterial = localMaterials.firstWhere(
            (item) => item.id == selectedMaterialId,
            orElse: () => localMaterials.first,
          );
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        layer == null ? 'Новый слой' : 'Редактирование слоя',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onSaveCustomMaterial == null
                          ? null
                          : () async {
                              final draft = await showMaterialEditor(context);
                              if (draft == null) {
                                return;
                              }
                              final saved = await onSaveCustomMaterial(draft);
                              _upsertMaterial(localMaterials, saved);
                              _upsertMaterialEntry(
                                localEntries,
                                MaterialCatalogEntry(
                                  material: saved,
                                  source: MaterialCatalogSource.custom,
                                  isFavorite: false,
                                ),
                              );
                              setState(() => selectedMaterialId = saved.id);
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Свой материал'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MaterialPickerField(
                  materialEntries: localEntries,
                  value: localEntries.firstWhere(
                    (entry) => entry.material.id == selectedMaterial.id,
                    orElse: () => localEntries.first,
                  ),
                  onChanged: (material) {
                    setState(() => selectedMaterialId = material.id);
                  },
                  onEditCustomMaterial:
                      onSaveCustomMaterial == null || !selectedMaterial.isCustom
                      ? null
                      : () async {
                          final updatedDraft = await showMaterialEditor(
                            context,
                            material: selectedMaterial,
                          );
                          if (updatedDraft == null) {
                            return;
                          }
                          final saved = await onSaveCustomMaterial(
                            updatedDraft,
                          );
                          _upsertMaterial(localMaterials, saved);
                          _upsertMaterialEntry(
                            localEntries,
                            MaterialCatalogEntry(
                              material: saved,
                              source: MaterialCatalogSource.custom,
                              isFavorite: false,
                            ),
                          );
                          setState(() => selectedMaterialId = saved.id);
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LayerKind>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(labelText: 'Тип слоя'),
                  items: LayerKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedKind = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thicknessController,
                  decoration: const InputDecoration(labelText: 'Толщина, мм'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Учитывать в расчёте'),
                  value: enabled,
                  onChanged: (value) => setState(() => enabled = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      LayerEditorResult(
                        layer: ConstructionLayer(
                          id: layer?.id ?? buildEditorEntityId('layer'),
                          materialId: selectedMaterial.id,
                          kind: selectedKind,
                          thicknessMm: parseEditorDouble(
                            thicknessController.text,
                            fallback: 100,
                          ),
                          enabled: enabled,
                        ),
                        material: selectedMaterial,
                      ),
                    );
                  },
                  child: const Text('Сохранить слой'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  thicknessController.dispose();
  return result;
}

Future<MaterialEntry?> showMaterialEditor(
  BuildContext context, {
  MaterialEntry? material,
}) async {
  final nameController = TextEditingController(text: material?.name ?? '');
  final categoryController = TextEditingController(
    text: material?.category ?? '',
  );
  final thermalController = TextEditingController(
    text: material?.thermalConductivity.toString() ?? '0.04',
  );
  final vaporController = TextEditingController(
    text: material?.vaporPermeability.toString() ?? '0.30',
  );
  final aliasesController = TextEditingController(
    text: material?.aliases.join(', ') ?? '',
  );
  final tagsController = TextEditingController(
    text: material?.tags.join(', ') ?? '',
  );
  final manufacturerController = TextEditingController(
    text: material?.manufacturer ?? '',
  );
  final subcategoryController = TextEditingController(
    text: material?.subcategory ?? '',
  );
  final densityController = TextEditingController(
    text: material?.densityKgM3?.toString() ?? '',
  );
  final notesController = TextEditingController(text: material?.notes ?? '');

  final result = await showModalBottomSheet<MaterialEntry>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              material == null ? 'Свой материал' : 'Редактирование материала',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Категория'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: thermalController,
              decoration: const InputDecoration(
                labelText: 'Теплопроводность λ, Вт/(м·°C)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: vaporController,
              decoration: const InputDecoration(
                labelText: 'Паропроницаемость δ, мг/(м·ч·Па)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aliasesController,
              decoration: const InputDecoration(
                labelText: 'Синонимы для поиска',
                hintText: 'через запятую',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tagsController,
              decoration: const InputDecoration(
                labelText: 'Теги',
                hintText: 'каркас, фасад, тёплая стена',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: manufacturerController,
              decoration: const InputDecoration(labelText: 'Производитель'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subcategoryController,
              decoration: const InputDecoration(labelText: 'Подкатегория'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: densityController,
              decoration: const InputDecoration(labelText: 'Плотность, кг/м³'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Примечание'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  MaterialEntry(
                    id: material?.id ?? buildEditorEntityId('custom-material'),
                    name: requiredEditorText(
                      nameController.text,
                      fallback: 'Свой материал',
                    ),
                    category: requiredEditorText(
                      categoryController.text,
                      fallback: 'Пользовательские',
                    ),
                    thermalConductivity: parseEditorDouble(
                      thermalController.text,
                      fallback: 0.04,
                    ),
                    vaporPermeability: parseEditorDouble(
                      vaporController.text,
                      fallback: 0.30,
                    ),
                    aliases: aliasesController.text
                        .split(',')
                        .map((item) => item.trim())
                        .where((item) => item.isNotEmpty)
                        .toList(growable: false),
                    tags: tagsController.text
                        .split(',')
                        .map((item) => item.trim())
                        .where((item) => item.isNotEmpty)
                        .toList(growable: false),
                    manufacturer: _nullableEditorText(
                      manufacturerController.text,
                    ),
                    subcategory: _nullableEditorText(
                      subcategoryController.text,
                    ),
                    densityKgM3: _nullableEditorDouble(densityController.text),
                    notes: _nullableEditorText(notesController.text),
                  ),
                );
              },
              child: const Text('Сохранить материал'),
            ),
          ],
        ),
      );
    },
  );

  nameController.dispose();
  categoryController.dispose();
  thermalController.dispose();
  vaporController.dispose();
  aliasesController.dispose();
  tagsController.dispose();
  manufacturerController.dispose();
  subcategoryController.dispose();
  densityController.dispose();
  notesController.dispose();
  return result;
}

class _MaterialPickerField extends StatelessWidget {
  const _MaterialPickerField({
    required this.materialEntries,
    required this.value,
    required this.onChanged,
    this.onEditCustomMaterial,
  });

  final List<MaterialCatalogEntry> materialEntries;
  final MaterialCatalogEntry value;
  final ValueChanged<MaterialEntry> onChanged;
  final Future<void> Function()? onEditCustomMaterial;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final selected = await showMaterialPicker(
          context,
          materialEntries: materialEntries,
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Материал',
          suffixIcon: Icon(Icons.search),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _materialLabel(value.material, fallback: value.material.id),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.material.category} • λ ${value.material.thermalConductivity.toStringAsFixed(3)} • δ ${value.material.vaporPermeability.toStringAsFixed(3)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                if (value.isFavorite)
                  const Chip(
                    label: Text('Избранное'),
                    visualDensity: VisualDensity.compact,
                  ),
                Chip(
                  label: Text(value.isCustom ? 'Свой' : 'Базовый'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (onEditCustomMaterial != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onEditCustomMaterial,
                  child: const Text('Изменить свой материал'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<MaterialEntry?> showMaterialPicker(
  BuildContext context, {
  required List<MaterialCatalogEntry> materialEntries,
}) async {
  var filter = const MaterialFilterState();
  return showModalBottomSheet<MaterialEntry>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final filtered = filterMaterialCatalogEntries(
            materialEntries,
            filter,
          );
          final grouped = <String, List<MaterialCatalogEntry>>{};
          for (final item in filtered) {
            grouped.putIfAbsent(item.material.category, () => []).add(item);
          }
          final categories =
              materialEntries
                  .map((item) => item.material.category)
                  .toSet()
                  .toList()
                ..sort();
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Подбор материала',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Поиск по названию, тегам, категории',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => filter = filter.copyWith(query: value)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Избранные'),
                      selected: filter.favoritesOnly,
                      onSelected: (value) => setState(
                        () => filter = filter.copyWith(favoritesOnly: value),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Низкая λ'),
                      selected: filter.lambdaMax == 0.05,
                      onSelected: (value) => setState(
                        () => filter = value
                            ? filter.copyWith(lambdaMax: 0.05)
                            : filter.copyWith(clearLambdaMax: true),
                      ),
                    ),
                    ChoiceChip(
                      label: Text(filter.source.label),
                      selected: true,
                      onSelected: (_) async {
                        final selectedSource = await _showSourcePicker(
                          context,
                          current: filter.source,
                        );
                        if (selectedSource != null) {
                          setState(
                            () => filter = filter.copyWith(
                              source: selectedSource,
                            ),
                          );
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Text(filter.category ?? 'Категория'),
                      selected: filter.category != null,
                      onSelected: (_) async {
                        final selectedCategory = await _showCategoryPicker(
                          context,
                          categories: categories,
                          current: filter.category,
                        );
                        setState(
                          () => filter = selectedCategory == null
                              ? filter.copyWith(clearCategory: true)
                              : filter.copyWith(category: selectedCategory),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final updated = await showMaterialAdvancedFilters(
                        context,
                        filter: filter,
                      );
                      if (updated != null) {
                        setState(() => filter = updated);
                      }
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('Фильтры'),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: grouped.entries
                        .map(
                          (entry) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 8,
                                ),
                                child: Text(
                                  entry.key,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              ...entry.value.map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    _materialLabel(
                                      item.material,
                                      fallback: item.material.id,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item.isCustom ? 'Свой' : 'Базовый'} • λ ${item.material.thermalConductivity.toStringAsFixed(3)} • δ ${item.material.vaporPermeability.toStringAsFixed(3)}',
                                  ),
                                  trailing: item.isFavorite
                                      ? const Icon(Icons.star, size: 18)
                                      : null,
                                  onTap: () =>
                                      Navigator.of(context).pop(item.material),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<MaterialFilterState?> showMaterialAdvancedFilters(
  BuildContext context, {
  required MaterialFilterState filter,
}) async {
  final lambdaMinController = TextEditingController(
    text: filter.lambdaMin?.toString() ?? '',
  );
  final lambdaMaxController = TextEditingController(
    text: filter.lambdaMax?.toString() ?? '',
  );
  final vaporMinController = TextEditingController(
    text: filter.vaporMin?.toString() ?? '',
  );
  final vaporMaxController = TextEditingController(
    text: filter.vaporMax?.toString() ?? '',
  );
  var sort = filter.sort;

  final result = await showModalBottomSheet<MaterialFilterState>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Расширенные фильтры',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lambdaMinController,
                  decoration: const InputDecoration(labelText: 'λ от'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lambdaMaxController,
                  decoration: const InputDecoration(labelText: 'λ до'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vaporMinController,
                  decoration: const InputDecoration(labelText: 'δ от'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vaporMaxController,
                  decoration: const InputDecoration(labelText: 'δ до'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MaterialSortOption>(
                  initialValue: sort,
                  decoration: const InputDecoration(labelText: 'Сортировка'),
                  items: MaterialSortOption.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => sort = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(const MaterialFilterState()),
                      child: const Text('Сбросить'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          filter.copyWith(
                            lambdaMin: _nullableEditorDouble(
                              lambdaMinController.text,
                            ),
                            clearLambdaMin:
                                _nullableEditorDouble(
                                  lambdaMinController.text,
                                ) ==
                                null,
                            lambdaMax: _nullableEditorDouble(
                              lambdaMaxController.text,
                            ),
                            clearLambdaMax:
                                _nullableEditorDouble(
                                  lambdaMaxController.text,
                                ) ==
                                null,
                            vaporMin: _nullableEditorDouble(
                              vaporMinController.text,
                            ),
                            clearVaporMin:
                                _nullableEditorDouble(
                                  vaporMinController.text,
                                ) ==
                                null,
                            vaporMax: _nullableEditorDouble(
                              vaporMaxController.text,
                            ),
                            clearVaporMax:
                                _nullableEditorDouble(
                                  vaporMaxController.text,
                                ) ==
                                null,
                            sort: sort,
                          ),
                        );
                      },
                      child: const Text('Применить'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );

  lambdaMinController.dispose();
  lambdaMaxController.dispose();
  vaporMinController.dispose();
  vaporMaxController.dispose();
  return result;
}

void _upsertMaterialEntry(
  List<MaterialCatalogEntry> entries,
  MaterialCatalogEntry entry,
) {
  final index = entries.indexWhere(
    (item) => item.material.id == entry.material.id,
  );
  if (index == -1) {
    entries.add(entry);
    return;
  }
  entries[index] = entry;
}

void _upsertMaterial(List<MaterialEntry> materials, MaterialEntry material) {
  final index = materials.indexWhere((item) => item.id == material.id);
  if (index == -1) {
    materials.add(material);
    return;
  }
  materials[index] = material;
}

String _materialLabel(MaterialEntry? material, {required String fallback}) {
  if (material == null) {
    return fallback;
  }
  return material.isCustom ? '${material.name} • свой' : material.name;
}

Future<MaterialSourceFilter?> _showSourcePicker(
  BuildContext context, {
  required MaterialSourceFilter current,
}) {
  return showModalBottomSheet<MaterialSourceFilter>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: MaterialSourceFilter.values
            .map(
              (item) => ListTile(
                leading: item == current ? const Icon(Icons.check) : null,
                title: Text(item.label),
                onTap: () => Navigator.of(context).pop(item),
              ),
            )
            .toList(growable: false),
      ),
    ),
  );
}

Future<String?> _showCategoryPicker(
  BuildContext context, {
  required List<String> categories,
  required String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: current == null ? const Icon(Icons.check) : null,
            title: const Text('Все категории'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ...categories.map(
            (item) => ListTile(
              leading: item == current ? const Icon(Icons.check) : null,
              title: Text(item),
              onTap: () => Navigator.of(context).pop(item),
            ),
          ),
        ],
      ),
    ),
  );
}

String buildEditorEntityId(String prefix) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '$prefix-$timestamp';
}

double parseEditorDouble(String value, {required double fallback}) {
  return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
}

String requiredEditorText(String value, {required String fallback}) {
  final normalized = value.trim();
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableEditorText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

double? _nullableEditorDouble(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized.replaceAll(',', '.'));
}
