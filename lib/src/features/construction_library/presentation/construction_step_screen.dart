import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/calculation.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../building_step/presentation/building_step_screen.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';
import 'construction_editor_sheet.dart';
import 'material_management_screen.dart';

class ConstructionStepScreen extends ConsumerWidget {
  const ConstructionStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final libraryAsync = ref.watch(constructionLibraryProvider);
    final materialEntriesAsync = ref.watch(materialCatalogEntriesProvider);
    final step2Fab = projectAsync.when<Widget?>(
      data: (project) {
        if (project == null) {
          return null;
        }
        final hasSelectedConstructions =
            project.effectiveSelectedConstructionIds.isNotEmpty;
        return FloatingActionButton.extended(
          onPressed: hasSelectedConstructions
              ? () => _openStep2(context)
              : null,
          icon: const Icon(Icons.looks_two_outlined),
          label: const Text('Шаг 2. Здание'),
        );
      },
      loading: () => null,
      error: (_, _) => null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Шаг 1. Конструкции')),
      floatingActionButton: step2Fab,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('Активный проект не найден.'));
          }
          return catalogAsync.when(
            data: (catalog) => materialEntriesAsync.when(
              data: (materialEntries) => libraryAsync.when(
                data: (library) => _ConstructionStepBody(
                  project: project,
                  catalog: catalog,
                  library: library,
                  materialEntries: materialEntries,
                ),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Ошибка загрузки проекта: $error')),
      ),
    );
  }

  void _openStep2(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BuildingStepScreen()),
    );
  }
}

class _ConstructionStepBody extends ConsumerStatefulWidget {
  const _ConstructionStepBody({
    required this.project,
    required this.catalog,
    required this.library,
    required this.materialEntries,
  });

  final Project project;
  final CatalogSnapshot catalog;
  final List<Construction> library;
  final List<MaterialCatalogEntry> materialEntries;

  @override
  ConsumerState<_ConstructionStepBody> createState() =>
      _ConstructionStepBodyState();
}

class _ConstructionStepBodyState extends ConsumerState<_ConstructionStepBody> {
  ConstructionElementKind? _filterKind;
  String _searchQuery = '';
  _ConstructionLibraryScope _libraryScope = _ConstructionLibraryScope.all;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final selectedIds = widget.project.effectiveSelectedConstructionIds.toSet();
    final materialMap = {
      for (final entry in widget.materialEntries)
        entry.material.id: entry.material,
    };
    final templateIds = widget.catalog.constructionTemplates
        .map((item) => item.id)
        .toSet();
    final filteredLibrary = widget.library
        .where((item) => _filterKind == null || item.elementKind == _filterKind)
        .where(
          (item) =>
              _libraryScope.matches(isTemplate: templateIds.contains(item.id)),
        )
        .where((item) => _matchesConstruction(item, _searchQuery, materialMap))
        .toList(growable: false);
    final selectedConstructions = widget.project.constructions
        .where((item) => selectedIds.contains(item.id))
        .toList(growable: false);

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
                  widget.project.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Соберите набор ограждающих конструкций для проекта. Выбранные конструкции будут доступны на следующем этапе построения здания.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      label: 'Выбрано',
                      value: '${selectedConstructions.length}',
                    ),
                    _MetricChip(
                      label: 'В библиотеке',
                      value: '${widget.library.length}',
                    ),
                    _MetricChip(
                      label: 'Шаг 2',
                      value: selectedConstructions.isEmpty
                          ? 'ожидает'
                          : 'готовится',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      'Конструкции проекта',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: () =>
                              _handleCreateConstruction(context, messenger),
                          icon: const Icon(Icons.add),
                          label: const Text('Создать'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MaterialManagementScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Материалы'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  selectedConstructions.isEmpty
                      ? 'Пока ничего не выбрано. Выберите готовую конструкцию из библиотеки или создайте новую.'
                      : 'Этот набор будет передан в следующий этап.',
                ),
                const SizedBox(height: 16),
                if (selectedConstructions.isEmpty)
                  const Text('Конструкции проекта пока не выбраны.')
                else
                  ...selectedConstructions.map(
                    (construction) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ConstructionCard(
                        construction: construction,
                        materialMap: materialMap,
                        selected: true,
                        onTapPrimary: () async {
                          await _handleRemoveFromProject(
                            messenger,
                            construction.id,
                          );
                        },
                        primaryLabel: 'Убрать из проекта',
                        onEdit: () => _handleEditConstruction(
                          context,
                          messenger,
                          construction,
                        ),
                        onCopy: () => _handleCopyConstruction(
                          context,
                          messenger,
                          construction,
                        ),
                        onDelete: () => _handleDeleteFromLibrary(
                          messenger,
                          construction.id,
                        ),
                        footer: _ConstructionStatusFooter(
                          constructionId: construction.id,
                          onOpenCalculation: () => _openConstructionCalculation(
                            context,
                            construction,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Библиотека конструкций',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Все'),
                      selected: _filterKind == null,
                      onSelected: (_) => setState(() => _filterKind = null),
                    ),
                    ...ConstructionElementKind.values.map(
                      (kind) => FilterChip(
                        label: Text(kind.label),
                        selected: _filterKind == kind,
                        onSelected: (_) => setState(() => _filterKind = kind),
                      ),
                    ),
                    ..._ConstructionLibraryScope.values.map(
                      (scope) => FilterChip(
                        label: Text(scope.label),
                        selected: _libraryScope == scope,
                        onSelected: (_) =>
                            setState(() => _libraryScope = scope),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Поиск по названию и материалам',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 16),
                if (filteredLibrary.isEmpty)
                  const Text(
                    'В библиотеке нет конструкций по текущему фильтру.',
                  )
                else
                  ...filteredLibrary.map(
                    (construction) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ConstructionCard(
                        construction: construction,
                        materialMap: materialMap,
                        selected: selectedIds.contains(construction.id),
                        onTapPrimary: selectedIds.contains(construction.id)
                            ? null
                            : () => _handleSelectForProject(
                                messenger,
                                construction,
                              ),
                        primaryLabel: selectedIds.contains(construction.id)
                            ? 'Уже выбрана'
                            : 'Выбрать в проект',
                        onEdit: () => _handleEditConstruction(
                          context,
                          messenger,
                          construction,
                        ),
                        onCopy: () => _handleCopyConstruction(
                          context,
                          messenger,
                          construction,
                        ),
                        onDelete: () => _handleDeleteFromLibrary(
                          messenger,
                          construction.id,
                        ),
                        footer: _ConstructionStatusFooter(
                          constructionId: construction.id,
                          onOpenCalculation: () => _openConstructionCalculation(
                            context,
                            construction,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Следующий этап',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedConstructions.isEmpty
                      ? 'Переход на шаг 2 заблокирован, пока в проект не добавлена хотя бы одна конструкция.'
                      : 'Следующим шагом будет создание здания из выбранных конструкций. Используйте плавающую кнопку «Шаг 2. Здание».',
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selectedConstructions.isEmpty
                          ? Icons.lock_outline
                          : Icons.arrow_circle_right_outlined,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedConstructions.isEmpty
                            ? 'Кнопка перехода видна справа внизу, но станет активной только после выбора конструкции.'
                            : 'Кнопка перехода активна справа внизу и открывает экран «Шаг 2. Здание».',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCreateConstruction(
    BuildContext context,
    ScaffoldMessengerState messenger,
  ) async {
    final created = await showConstructionEditor(
      context,
      catalog: widget.catalog,
      materialEntries: widget.materialEntries,
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!context.mounted || created == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addConstruction(created);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleEditConstruction(
    BuildContext context,
    ScaffoldMessengerState messenger,
    Construction construction,
  ) async {
    final updated = await showConstructionEditor(
      context,
      catalog: widget.catalog,
      materialEntries: widget.materialEntries,
      construction: construction,
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!context.mounted || updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateLibraryConstruction(updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleCopyConstruction(
    BuildContext context,
    ScaffoldMessengerState messenger,
    Construction source,
  ) async {
    final draft = source.copyWith(
      id: buildEditorEntityId('construction'),
      title: '${source.title} (копия)',
    );
    final copied = await showConstructionEditor(
      context,
      catalog: widget.catalog,
      materialEntries: widget.materialEntries,
      construction: draft,
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!context.mounted || copied == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addConstruction(copied);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleSelectForProject(
    ScaffoldMessengerState messenger,
    Construction construction,
  ) async {
    try {
      await ref
          .read(projectEditorProvider)
          .selectConstructionForProject(construction);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleRemoveFromProject(
    ScaffoldMessengerState messenger,
    String constructionId,
  ) async {
    try {
      await ref
          .read(projectEditorProvider)
          .unselectConstructionFromProject(constructionId);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleDeleteFromLibrary(
    ScaffoldMessengerState messenger,
    String constructionId,
  ) async {
    try {
      await ref
          .read(projectEditorProvider)
          .deleteConstructionFromLibrary(constructionId);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  void _openConstructionCalculation(
    BuildContext context,
    Construction construction,
  ) {
    ref.read(selectedConstructionIdProvider.notifier).select(construction.id);
    ref.read(selectedEnvelopeElementIdProvider.notifier).select(null);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThermocalcScreen(
          constructionId: construction.id,
          showElementContext: false,
        ),
      ),
    );
  }

  void _showError(ScaffoldMessengerState messenger, Object error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

bool _matchesConstruction(
  Construction construction,
  String query,
  Map<String, MaterialEntry> materialMap,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  final haystack = [
    construction.title,
    construction.elementKind.label,
    construction.floorConstructionType?.label,
    construction.crawlSpaceVentilationMode?.label,
    ...construction.layers.expand((layer) {
      final material = materialMap[layer.materialId];
      return [
        layer.materialId,
        material?.name,
        material?.category,
        material?.subcategory,
        material?.manufacturer,
        material?.notes,
        ...?material?.aliases,
        ...?material?.tags,
      ];
    }),
  ].join(' ').toLowerCase();
  return haystack.contains(normalized);
}

enum _ConstructionLibraryScope { all, templates, custom }

extension on _ConstructionLibraryScope {
  String get label => switch (this) {
    _ConstructionLibraryScope.all => 'Все конструкции',
    _ConstructionLibraryScope.templates => 'Шаблоны',
    _ConstructionLibraryScope.custom => 'Свои',
  };

  bool matches({required bool isTemplate}) => switch (this) {
    _ConstructionLibraryScope.all => true,
    _ConstructionLibraryScope.templates => isTemplate,
    _ConstructionLibraryScope.custom => !isTemplate,
  };
}

class _ConstructionCard extends StatelessWidget {
  const _ConstructionCard({
    required this.construction,
    required this.materialMap,
    required this.selected,
    required this.onTapPrimary,
    required this.primaryLabel,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    this.footer,
  });

  final Construction construction;
  final Map<String, MaterialEntry> materialMap;
  final bool selected;
  final VoidCallback? onTapPrimary;
  final String primaryLabel;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final layerTitles = construction.layers
        .map((layer) => materialMap[layer.materialId]?.name ?? layer.materialId)
        .join(', ');
    final summaryParts = [
      construction.elementKind.label,
      if (construction.floorConstructionType case final floorType?)
        floorType.label,
      if (construction.crawlSpaceVentilationMode case final ventilationMode?)
        ventilationMode.label,
      'слоёв ${construction.layers.length}',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(selected ? Icons.check_circle : Icons.layers_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  construction.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'copy':
                      onCopy();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                  PopupMenuItem(value: 'copy', child: Text('Копировать')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить из библиотеки'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summaryParts.join(' • '),
          ),
          const SizedBox(height: 4),
          Text(layerTitles, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: onTapPrimary,
              child: Text(primaryLabel),
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

class _ConstructionStatusFooter extends ConsumerWidget {
  const _ConstructionStatusFooter({
    required this.constructionId,
    required this.onOpenCalculation,
  });

  final String constructionId;
  final VoidCallback onOpenCalculation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculationAsync = ref.watch(
      calculationResultForConstructionProvider(constructionId),
    );

    return calculationAsync.when(
      data: (result) {
        if (result == null) {
          return _StatusContainer(
            child: Row(
              children: [
                const Expanded(
                  child: Text('Расчет недоступен для этой конструкции.'),
                ),
                FilledButton.icon(
                  onPressed: onOpenCalculation,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Проверить расчет'),
                ),
              ],
            ),
          );
        }

        if (!result.scenarioStatus.isDirectlySupported) {
          return _StatusContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(label: Text(result.scenarioStatus.label)),
                const SizedBox(height: 8),
                Text(result.scenarioMessage),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onOpenCalculation,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Открыть расчет'),
                ),
              ],
            ),
          );
        }

        final thermalPassed = result.complianceIndicators.every(
          (item) => item.isPassed,
        );
        final moistureVerdict = result.moistureCheck.verdict;
        return _StatusContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      thermalPassed
                          ? 'Теплозащита: ок'
                          : 'Теплозащита: проверить',
                    ),
                  ),
                  Chip(label: Text('Влага: ${moistureVerdict.label}')),
                  Chip(
                    label: Text(
                      'R ${result.totalResistance.toStringAsFixed(2)} / ${result.requiredResistance.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(result.moistureCheck.summary),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onOpenCalculation,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Проверить расчет'),
              ),
            ],
          ),
        );
      },
      loading: () => const _StatusContainer(child: LinearProgressIndicator()),
      error: (error, _) => _StatusContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ошибка расчета: $error'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onOpenCalculation,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Открыть расчет'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusContainer extends StatelessWidget {
  const _StatusContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
