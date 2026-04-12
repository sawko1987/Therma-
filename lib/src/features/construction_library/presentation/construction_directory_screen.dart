import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/calculation.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';
import 'construction_editor_sheet.dart';

enum ConstructionPickerAction {
  selectExisting,
  addProjectOnly,
  saveToLibraryAndProject,
}

enum ConstructionSaveTarget { projectOnly, libraryAndProject }

class ConstructionPickerResult {
  const ConstructionPickerResult({
    required this.construction,
    required this.action,
  });

  final Construction construction;
  final ConstructionPickerAction action;
}

class ConstructionDirectoryScreen extends ConsumerStatefulWidget {
  const ConstructionDirectoryScreen({super.key});

  @override
  ConsumerState<ConstructionDirectoryScreen> createState() =>
      _ConstructionDirectoryScreenState();
}

class _ConstructionDirectoryScreenState
    extends ConsumerState<ConstructionDirectoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final materialEntriesAsync = ref.watch(materialCatalogEntriesProvider);
    final libraryAsync = ref.watch(constructionLibraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Справочник конструкций'),
        actions: [
          IconButton(
            tooltip: 'Создать конструкцию',
            onPressed: _handleCreate,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: catalogAsync.when(
        data: (catalog) => materialEntriesAsync.when(
          data: (materialEntries) => libraryAsync.when(
            data: (library) {
              final materialMap = {
                for (final entry in materialEntries)
                  entry.material.id: entry.material,
              };
              final filtered = _filterConstructions(library, query: _query);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Справочник конструкций',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Здесь собрана вся библиотека конструкций проекта. В списке показываются только названия, а детали и расчет открываются по кнопке информации.',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Поиск по названию',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                          const SizedBox(height: 12),
                          Text('Найдено: ${filtered.length}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Конструкции по текущему фильтру не найдены.',
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (construction) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ConstructionDirectoryRow(
                          construction: construction,
                          onInfo: () => showConstructionInfoSheet(
                            context,
                            construction: construction,
                            materialMap: materialMap,
                          ),
                          onEdit: () => _handleEdit(
                            catalog,
                            materialEntries,
                            construction,
                          ),
                          onDelete: () => _handleDelete(construction.id),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Ошибка загрузки библиотеки: $error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Ошибка загрузки материалов: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Ошибка загрузки каталога: $error')),
      ),
    );
  }

  Future<void> _handleCreate() async {
    final catalog = await ref.read(catalogSnapshotProvider.future);
    final materialEntries = await ref.read(
      materialCatalogEntriesProvider.future,
    );
    if (!mounted) {
      return;
    }
    final created = await showConstructionEditor(
      context,
      catalog: catalog,
      materialEntries: materialEntries,
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!mounted || created == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).saveConstructionToLibrary(created);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleEdit(
    CatalogSnapshot catalog,
    List<MaterialCatalogEntry> materialEntries,
    Construction construction,
  ) async {
    if (!mounted) {
      return;
    }
    final updated = await showConstructionEditor(
      context,
      catalog: catalog,
      materialEntries: materialEntries,
      construction: construction,
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!mounted || updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateLibraryConstruction(updated);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleDelete(String constructionId) async {
    try {
      await ref
          .read(projectEditorProvider)
          .deleteConstructionFromLibrary(constructionId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _ConstructionDirectoryRow extends StatelessWidget {
  const _ConstructionDirectoryRow({
    required this.construction,
    required this.onInfo,
    required this.onEdit,
    required this.onDelete,
  });

  final Construction construction;
  final VoidCallback onInfo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          construction.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Информация',
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'delete':
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
      ),
    );
  }
}

Future<ConstructionPickerResult?> showConstructionPickerModal(
  BuildContext context, {
  required List<Construction> constructions,
  required List<MaterialCatalogEntry> materialEntries,
  required Map<String, MaterialEntry> materialMap,
}) {
  return showModalBottomSheet<ConstructionPickerResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      var query = '';
      return StatefulBuilder(
        builder: (context, setState) {
          final filtered = _filterConstructions(constructions, query: query);
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
                  'Добавить конструкцию',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Выберите конструкцию из отдельного справочника. В списке показаны только названия.',
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Поиск по названию',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('По текущему запросу ничего не найдено.'),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final construction = filtered[index];
                            return Card(
                              child: ListTile(
                                title: Text(construction.title),
                                onTap: () => Navigator.of(context).pop(
                                  ConstructionPickerResult(
                                    construction: construction,
                                    action:
                                        ConstructionPickerAction.selectExisting,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Копировать',
                                      onPressed: () async {
                                        final draft = construction.copyWith(
                                          id: buildEditorEntityId(
                                            'construction',
                                          ),
                                          title:
                                              '${construction.title} (копия)',
                                          layers: [
                                            for (final layer
                                                in construction.layers)
                                              layer.copyWith(
                                                id: buildEditorEntityId(
                                                  'layer',
                                                ),
                                              ),
                                          ],
                                        );
                                        final copied =
                                            await showQuickConstructionCopyEditor(
                                              context,
                                              construction: draft,
                                              materialEntries: materialEntries,
                                              onSaveCustomMaterial: null,
                                            );
                                        if (!context.mounted ||
                                            copied == null) {
                                          return;
                                        }
                                        final target =
                                            await showConstructionSaveTargetSheet(
                                              context,
                                            );
                                        if (!context.mounted ||
                                            target == null) {
                                          return;
                                        }
                                        Navigator.of(context).pop(
                                          ConstructionPickerResult(
                                            construction: copied,
                                            action:
                                                target ==
                                                    ConstructionSaveTarget
                                                        .projectOnly
                                                ? ConstructionPickerAction
                                                      .addProjectOnly
                                                : ConstructionPickerAction
                                                      .saveToLibraryAndProject,
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.content_copy_outlined,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Информация',
                                      onPressed: () =>
                                          showConstructionInfoSheet(
                                            context,
                                            construction: construction,
                                            materialMap: materialMap,
                                          ),
                                      icon: const Icon(Icons.info_outline),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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

Future<ConstructionSaveTarget?> showConstructionSaveTargetSheet(
  BuildContext context,
) {
  return showModalBottomSheet<ConstructionSaveTarget>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Куда сохранить конструкцию?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'После быстрой правки решите, нужна ли эта копия только для текущего проекта или её надо добавить и в общий справочник.',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Только для этого проекта'),
              subtitle: const Text('Не добавлять в общий справочник'),
              onTap: () =>
                  Navigator.of(context).pop(ConstructionSaveTarget.projectOnly),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.library_add_outlined),
              title: const Text('Добавить в справочник и в проект'),
              subtitle: const Text(
                'Сохранить в библиотеку для повторного выбора',
              ),
              onTap: () => Navigator.of(
                context,
              ).pop(ConstructionSaveTarget.libraryAndProject),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<Construction?> showQuickConstructionCopyEditor(
  BuildContext context, {
  required Construction construction,
  required List<MaterialCatalogEntry> materialEntries,
  CustomMaterialSaver? onSaveCustomMaterial,
}) async {
  final titleController = TextEditingController(text: construction.title);
  final layers = [...construction.layers];
  final availableEntries = [...materialEntries];
  final availableMaterials = [
    for (final entry in availableEntries) entry.material,
  ];

  final result = await showModalBottomSheet<Construction>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final materialMap = {
            for (final material in availableMaterials) material.id: material,
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
                  'Быстрая копия конструкции',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Измените название и состав слоев. Остальные параметры копии сохраняются как у исходной конструкции.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Слои',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final added = await showLayerEditor(
                          context,
                          materialEntries: availableEntries,
                          onSaveCustomMaterial: onSaveCustomMaterial,
                        );
                        if (added == null) {
                          return;
                        }
                        _upsertMaterialLocal(
                          availableMaterials,
                          added.material,
                        );
                        _upsertMaterialEntryLocal(
                          availableEntries,
                          MaterialCatalogEntry(
                            material: added.material,
                            source: added.material.isCustom
                                ? MaterialCatalogSource.custom
                                : MaterialCatalogSource.seed,
                            isFavorite: false,
                          ),
                        );
                        setState(() => layers.add(added.layer));
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
                                '${material?.name ?? layer.materialId} • ${layer.kind.label}',
                              ),
                              subtitle: Text(
                                '${layer.thicknessMm.toStringAsFixed(0)} мм'
                                '${layer.enabled ? '' : ' • выключен'}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'edit':
                                      final updated = await showLayerEditor(
                                        context,
                                        materialEntries: availableEntries,
                                        layer: layer,
                                        onSaveCustomMaterial:
                                            onSaveCustomMaterial,
                                      );
                                      if (updated != null) {
                                        _upsertMaterialLocal(
                                          availableMaterials,
                                          updated.material,
                                        );
                                        _upsertMaterialEntryLocal(
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
                            construction.copyWith(
                              title: requiredEditorText(
                                titleController.text,
                                fallback: construction.title,
                              ),
                              layers: List.unmodifiable(layers),
                            ),
                          );
                        },
                  child: const Text('Продолжить'),
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

Future<void> showConstructionInfoSheet(
  BuildContext context, {
  required Construction construction,
  required Map<String, MaterialEntry> materialMap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        return Padding(
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
                  construction.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(_constructionSummary(construction)),
                const SizedBox(height: 16),
                Text(
                  'Состав',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...construction.layers.map(
                  (layer) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F4ED),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${materialMap[layer.materialId]?.name ?? layer.materialId} • ${layer.kind.label} • ${layer.thicknessMm.toStringAsFixed(0)} мм'
                        '${layer.enabled ? '' : ' • выключен'}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ConstructionCalculationPanel(constructionId: construction.id),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ConstructionCalculationPanel extends ConsumerWidget {
  const ConstructionCalculationPanel({super.key, required this.constructionId});

  final String constructionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculationAsync = ref.watch(
      calculationResultForConstructionProvider(constructionId),
    );

    return calculationAsync.when(
      data: (result) {
        if (result == null) {
          return _InfoBox(
            child: _OpenCalculationButton(constructionId: constructionId),
          );
        }

        return _InfoBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(result.scenarioStatus.label)),
                  Chip(
                    label: Text(
                      'R ${result.totalResistance.toStringAsFixed(2)} / ${result.requiredResistance.toStringAsFixed(2)}',
                    ),
                  ),
                  Chip(label: Text(result.moistureCheck.verdict.label)),
                ],
              ),
              const SizedBox(height: 8),
              Text(result.scenarioMessage),
              const SizedBox(height: 8),
              Text(result.moistureCheck.summary),
              const SizedBox(height: 12),
              _OpenCalculationButton(constructionId: constructionId),
            ],
          ),
        );
      },
      loading: () => const _InfoBox(child: LinearProgressIndicator()),
      error: (error, _) => _InfoBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ошибка расчета: $error'),
            const SizedBox(height: 12),
            _OpenCalculationButton(constructionId: constructionId),
          ],
        ),
      ),
    );
  }
}

class _OpenCalculationButton extends ConsumerWidget {
  const _OpenCalculationButton({required this.constructionId});

  final String constructionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () {
        ref
            .read(selectedConstructionIdProvider.notifier)
            .select(constructionId);
        ref.read(selectedEnvelopeElementIdProvider.notifier).select(null);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ThermocalcScreen(
              constructionId: constructionId,
              showElementContext: false,
            ),
          ),
        );
      },
      icon: const Icon(Icons.analytics_outlined),
      label: const Text('Открыть расчет'),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4ED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

List<Construction> _filterConstructions(
  List<Construction> constructions, {
  required String query,
}) {
  final normalized = query.trim().toLowerCase();
  return constructions
      .where((construction) {
        if (normalized.isEmpty) {
          return true;
        }
        return construction.title.toLowerCase().contains(normalized);
      })
      .toList(growable: false);
}

String _constructionSummary(Construction construction) {
  return [
    construction.elementKind.label,
    if (construction.floorConstructionType case final floorType?)
      floorType.label,
    if (construction.crawlSpaceVentilationMode case final ventilationMode?)
      ventilationMode.label,
    'слоев ${construction.layers.length}',
  ].join(' • ');
}

void _upsertMaterialEntryLocal(
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

void _upsertMaterialLocal(
  List<MaterialEntry> materials,
  MaterialEntry material,
) {
  final index = materials.indexWhere((item) => item.id == material.id);
  if (index == -1) {
    materials.add(material);
    return;
  }
  materials[index] = material;
}
