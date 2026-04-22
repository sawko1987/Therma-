import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/calculation.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../building_step/presentation/building_step_screen.dart';
import 'construction_directory_screen.dart';

class ConstructionStepScreen extends ConsumerWidget {
  const ConstructionStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final libraryAsync = ref.watch(constructionLibraryProvider);
    final materialEntriesAsync = ref.watch(materialCatalogEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Шаг 1. Конструкции')),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('Активный проект не найден.'));
          }
          return materialEntriesAsync.when(
            data: (materialEntries) => libraryAsync.when(
              data: (library) => _ConstructionStepBody(
                project: project,
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Ошибка загрузки проекта: $error')),
      ),
    );
  }
}

class _ConstructionStepBody extends ConsumerStatefulWidget {
  const _ConstructionStepBody({
    required this.project,
    required this.library,
    required this.materialEntries,
  });

  final Project project;
  final List<Construction> library;
  final List<MaterialCatalogEntry> materialEntries;

  @override
  ConsumerState<_ConstructionStepBody> createState() =>
      _ConstructionStepBodyState();
}

class _ConstructionStepBodyState extends ConsumerState<_ConstructionStepBody> {
  final Set<String> _expandedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final materialMap = {
      for (final entry in widget.materialEntries)
        entry.material.id: entry.material,
    };
    final selections = widget.project.effectiveProjectConstructionSelections;
    final selectedRows = [
      for (final selection in selections)
        if (widget.project.constructions.any(
          (construction) => construction.id == selection.constructionId,
        ))
          (
            selection,
            widget.project.constructions.firstWhere(
              (construction) => construction.id == selection.constructionId,
            ),
          ),
    ];

    final hasActiveConstructions =
        widget.project.activeSelectedConstructionIds.isNotEmpty;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 180),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.project.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'На этом шаге собирается набор конструкций проекта. Здесь остаются только конструкции проекта: их можно временно исключать из расчета, разворачивать и готовить к следующему шагу.',
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Конструкции проекта',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3F0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('${selectedRows.length}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'По умолчанию строки свернуты. Можно временно исключить конструкцию из расчета, вернуть ее обратно или развернуть для просмотра состава и расчетного статуса.',
                    ),
                    const SizedBox(height: 16),
                    if (selectedRows.isEmpty)
                      const _EmptyProjectConstructionsState()
                    else
                      ...selectedRows.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ProjectConstructionRow(
                            construction: entry.$2,
                            selection: entry.$1,
                            materialMap: materialMap,
                            expanded: _expandedIds.contains(entry.$2.id),
                            onToggleExpanded: () => setState(() {
                              if (!_expandedIds.add(entry.$2.id)) {
                                _expandedIds.remove(entry.$2.id);
                              }
                            }),
                            onToggleIncluded: () async {
                              try {
                                if (entry.$1.includedInCalculation) {
                                  await ref
                                      .read(projectEditorProvider)
                                      .excludeConstructionFromCalculation(
                                        entry.$2.id,
                                      );
                                } else {
                                  await ref
                                      .read(projectEditorProvider)
                                      .includeConstructionInCalculation(
                                        entry.$2.id,
                                      );
                                }
                              } catch (error) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            },
                            onRemove: () async {
                              try {
                                await ref
                                    .read(projectEditorProvider)
                                    .unselectConstructionFromProject(
                                      entry.$2.id,
                                    );
                              } catch (error) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            },
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
                      'Следующий шаг',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasActiveConstructions
                          ? 'Можно переходить к созданию помещений и планировки дома.'
                          : 'Чтобы перейти к шагу 2, оставьте хотя бы одну конструкцию включенной в расчет.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: hasActiveConstructions
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const BuildingStepScreen(),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.meeting_room_outlined),
                        label: const Text(
                          'Перейти к созданию помещений (Шаг 2)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _handleAddConstruction(context, materialMap),
            icon: const Icon(Icons.add),
            label: const Text('Добавить конструкцию'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAddConstruction(
    BuildContext context,
    Map<String, MaterialEntry> materialMap,
  ) async {
    final selected = await showConstructionPickerModal(
      context,
      constructions: widget.library,
      materialEntries: widget.materialEntries,
      materialMap: materialMap,
    );
    if (!context.mounted || selected == null) {
      return;
    }
    try {
      switch (selected.action) {
        case ConstructionPickerAction.selectExisting:
          await ref
              .read(projectEditorProvider)
              .selectConstructionForProject(selected.construction);
        case ConstructionPickerAction.addProjectOnly:
          await ref
              .read(projectEditorProvider)
              .addProjectOnlyConstruction(selected.construction);
        case ConstructionPickerAction.saveToLibraryAndProject:
          await ref
              .read(projectEditorProvider)
              .addConstruction(selected.construction);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _EmptyProjectConstructionsState extends StatelessWidget {
  const _EmptyProjectConstructionsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4ED),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'В проект пока не добавлена ни одна конструкция. Используйте плавающую кнопку, чтобы выбрать готовую конструкцию из отдельного списка.',
      ),
    );
  }
}

class _ProjectConstructionRow extends StatelessWidget {
  const _ProjectConstructionRow({
    required this.construction,
    required this.selection,
    required this.materialMap,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onToggleIncluded,
    required this.onRemove,
  });

  final Construction construction;
  final ProjectConstructionSelection selection;
  final Map<String, MaterialEntry> materialMap;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleIncluded;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: selection.includedInCalculation
              ? Theme.of(context).colorScheme.outlineVariant
              : const Color(0xFFD1C6AF),
        ),
        borderRadius: BorderRadius.circular(18),
        color: selection.includedInCalculation
            ? Colors.white
            : const Color(0xFFFCF8EF),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        construction.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      _ProjectConstructionSummary(
                        constructionId: construction.id,
                        includedInCalculation: selection.includedInCalculation,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: selection.includedInCalculation
                      ? 'Исключить из расчета'
                      : 'Вернуть в расчет',
                  onPressed: onToggleIncluded,
                  icon: Icon(
                    selection.includedInCalculation
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                IconButton(
                  tooltip: expanded ? 'Свернуть' : 'Развернуть',
                  onPressed: onToggleExpanded,
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ),
                IconButton(
                  tooltip: 'Убрать из проекта',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(construction.elementKind.label)),
                  if (construction.floorConstructionType case final floorType?)
                    Chip(label: Text(floorType.label)),
                  if (!selection.includedInCalculation)
                    const Chip(label: Text('Исключена из расчета')),
                ],
              ),
              const SizedBox(height: 12),
              ...construction.layers.map(
                (layer) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F4ED),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${materialMap[layer.materialId]?.name ?? layer.materialId} • ${layer.kind.label} • ${layer.thicknessMm.toStringAsFixed(0)} мм'
                      '${layer.enabled ? '' : ' • выключен'}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstructionCalculationPanel(constructionId: construction.id),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectConstructionSummary extends ConsumerWidget {
  const _ProjectConstructionSummary({
    required this.constructionId,
    required this.includedInCalculation,
  });

  final String constructionId;
  final bool includedInCalculation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!includedInCalculation) {
      return Text(
        'Исключена из расчета',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final calculationAsync = ref.watch(
      calculationResultForConstructionProvider(constructionId),
    );
    return calculationAsync.when(
      data: (result) {
        if (result == null) {
          return Text(
            'Расчет пока недоступен',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Text(
          _buildShortCalculationText(result),
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
      loading: () =>
          Text('Считаем...', style: Theme.of(context).textTheme.bodySmall),
      error: (error, _) =>
          Text('Ошибка расчета', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

String _buildShortCalculationText(CalculationResult result) {
  if (!result.scenarioStatus.isDirectlySupported) {
    return result.scenarioStatus.label;
  }
  return 'R ${result.totalResistance.toStringAsFixed(2)} / ${result.requiredResistance.toStringAsFixed(2)}';
}
