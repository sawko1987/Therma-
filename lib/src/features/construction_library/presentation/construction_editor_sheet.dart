import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';

Future<Construction?> showConstructionEditor(
  BuildContext context, {
  required CatalogSnapshot catalog,
  Construction? construction,
}) async {
  final titleController = TextEditingController(
    text: construction?.title ?? '',
  );
  var selectedKind = construction?.elementKind ?? ConstructionElementKind.wall;
  final layers = [...?construction?.layers];
  if (layers.isEmpty && catalog.materials.isNotEmpty) {
    layers.add(
      ConstructionLayer(
        id: buildEditorEntityId('layer'),
        materialId: catalog.materials.first.id,
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
            for (final item in catalog.materials) item.id: item,
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
                  items: ConstructionElementKind.values
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
                          catalog: catalog,
                        );
                        if (layer != null) {
                          setState(() => layers.add(layer));
                        }
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
                              title: Text(material?.name ?? layer.materialId),
                              subtitle: Text(
                                '${layer.kind.label} • ${layer.thicknessMm.toStringAsFixed(0)} мм • ${layer.enabled ? 'в расчёте' : 'выключен'}',
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
                                        catalog: catalog,
                                        layer: layer,
                                      );
                                      if (updated != null) {
                                        layers[index] = updated;
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
                  onPressed: layers.isEmpty
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

Future<ConstructionLayer?> showLayerEditor(
  BuildContext context, {
  required CatalogSnapshot catalog,
  ConstructionLayer? layer,
}) async {
  if (catalog.materials.isEmpty) {
    return null;
  }
  final thicknessController = TextEditingController(
    text: (layer?.thicknessMm ?? 100).toString(),
  );
  var selectedMaterialId = layer?.materialId ?? catalog.materials.first.id;
  var selectedKind = layer?.kind ?? LayerKind.solid;
  var enabled = layer?.enabled ?? true;

  final result = await showModalBottomSheet<ConstructionLayer>(
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
                DropdownButtonFormField<String>(
                  initialValue: selectedMaterialId,
                  decoration: const InputDecoration(labelText: 'Материал'),
                  items: catalog.materials
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedMaterialId = value);
                    }
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
                      ConstructionLayer(
                        id: layer?.id ?? buildEditorEntityId('layer'),
                        materialId: selectedMaterialId,
                        kind: selectedKind,
                        thicknessMm: parseEditorDouble(
                          thicknessController.text,
                          fallback: 100,
                        ),
                        enabled: enabled,
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
