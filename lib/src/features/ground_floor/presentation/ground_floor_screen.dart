import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/ground_floor_calculation.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';

class GroundFloorScreen extends ConsumerStatefulWidget {
  const GroundFloorScreen({super.key});

  @override
  ConsumerState<GroundFloorScreen> createState() => _GroundFloorScreenState();
}

class _GroundFloorScreenState extends ConsumerState<GroundFloorScreen> {
  final _titleController = TextEditingController();
  final _areaController = TextEditingController();
  final _perimeterController = TextEditingController();
  final _widthController = TextEditingController();
  final _lengthController = TextEditingController();
  final _edgeWidthController = TextEditingController();
  final _edgeResistanceController = TextEditingController();
  final _notesController = TextEditingController();

  String? _syncedCalculationId;
  String? _selectedConstructionId;
  GroundFloorCalculationKind _selectedKind =
      GroundFloorCalculationKind.slabOnGround;

  @override
  void dispose() {
    _titleController.dispose();
    _areaController.dispose();
    _perimeterController.dispose();
    _widthController.dispose();
    _lengthController.dispose();
    _edgeWidthController.dispose();
    _edgeResistanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final calculationAsync = ref.watch(selectedGroundFloorCalculationProvider);
    final resultAsync = ref.watch(groundFloorCalculationResultProvider);
    final catalogAsync = ref.watch(catalogSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Полы по грунту',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const _StatusBanner(),
          const SizedBox(height: 16),
          projectAsync.when(
            data: (project) {
              if (project == null) {
                return const Text('Активный проект не найден.');
              }
              return calculationAsync.when(
                data: (calculation) {
                  _syncForm(calculation);
                  return Column(
                    children: [
                      _ProjectSummary(
                        project: project,
                        selectedConstructionId: _selectedConstructionId,
                      ),
                      const SizedBox(height: 16),
                      _CalculationListCard(
                        project: project,
                        selectedCalculationId: calculation?.id,
                        onSelect: (id) {
                          ref
                              .read(
                                selectedGroundFloorCalculationIdProvider
                                    .notifier,
                              )
                              .select(id);
                        },
                        onAdd: () => _handleAdd(project),
                      ),
                      const SizedBox(height: 16),
                      if (calculation == null)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'В проекте пока нет сохраненных расчетов пола по грунту.',
                            ),
                          ),
                        )
                      else
                        _EditorCard(
                          project: project,
                          selectedKind: _selectedKind,
                          selectedConstructionId: _selectedConstructionId,
                          titleController: _titleController,
                          areaController: _areaController,
                          perimeterController: _perimeterController,
                          widthController: _widthController,
                          lengthController: _lengthController,
                          edgeWidthController: _edgeWidthController,
                          edgeResistanceController: _edgeResistanceController,
                          notesController: _notesController,
                          onKindChanged: (value) {
                            setState(() {
                              _selectedKind = value;
                            });
                          },
                          onConstructionChanged: (value) {
                            setState(() {
                              _selectedConstructionId = value;
                            });
                          },
                          onSave: () => _handleSave(calculation),
                          onDelete: () => _handleDelete(calculation.id),
                        ),
                      const SizedBox(height: 16),
                      resultAsync.when(
                        data: (result) => catalogAsync.when(
                          data: (catalog) =>
                              _ResultCard(result: result, catalog: catalog),
                          loading: () => const LinearProgressIndicator(),
                          error: (error, _) => Text('Ошибка каталога: $error'),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('Ошибка расчета: $error'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Ошибка выбранного расчета: $error'),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка проекта: $error'),
          ),
        ],
      ),
    );
  }

  void _syncForm(GroundFloorCalculation? calculation) {
    if (calculation == null || _syncedCalculationId == calculation.id) {
      return;
    }
    _syncedCalculationId = calculation.id;
    _titleController.text = calculation.title;
    _areaController.text = calculation.areaSquareMeters.toStringAsFixed(1);
    _perimeterController.text = calculation.perimeterMeters.toStringAsFixed(1);
    _widthController.text = calculation.slabWidthMeters.toStringAsFixed(1);
    _lengthController.text = calculation.slabLengthMeters.toStringAsFixed(1);
    _edgeWidthController.text = calculation.edgeInsulationWidthMeters
        .toStringAsFixed(1);
    _edgeResistanceController.text = calculation.edgeInsulationResistance
        .toStringAsFixed(1);
    _notesController.text = calculation.notes ?? '';
    _selectedConstructionId = calculation.constructionId;
    _selectedKind = calculation.kind;
  }

  Future<void> _handleAdd(Project project) async {
    final floorConstruction = project.constructions.firstWhere(
      (item) =>
          item.elementKind == ConstructionElementKind.floor &&
          item.floorConstructionType == FloorConstructionType.onGround,
      orElse: () => throw StateError(
        'Для нового расчета нужна хотя бы одна конструкция типа "Пол по грунту".',
      ),
    );
    final calculation = GroundFloorCalculation(
      id: 'ground-floor-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Новый пол по грунту',
      kind: GroundFloorCalculationKind.slabOnGround,
      constructionId: floorConstruction.id,
      areaSquareMeters: 36,
      perimeterMeters: 24,
      slabWidthMeters: 6,
      slabLengthMeters: 6,
      edgeInsulationWidthMeters: 0.6,
      edgeInsulationResistance: 1.5,
    );

    try {
      await ref
          .read(projectEditorProvider)
          .addGroundFloorCalculation(calculation);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _handleSave(GroundFloorCalculation current) async {
    try {
      final updated = current.copyWith(
        title: _titleController.text.trim(),
        kind: _selectedKind,
        constructionId: _selectedConstructionId ?? current.constructionId,
        areaSquareMeters: double.parse(_areaController.text.trim()),
        perimeterMeters: double.parse(_perimeterController.text.trim()),
        slabWidthMeters: double.parse(_widthController.text.trim()),
        slabLengthMeters: double.parse(_lengthController.text.trim()),
        edgeInsulationWidthMeters: double.parse(
          _edgeWidthController.text.trim(),
        ),
        edgeInsulationResistance: double.parse(
          _edgeResistanceController.text.trim(),
        ),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        clearNotes: _notesController.text.trim().isEmpty,
      );
      await ref
          .read(projectEditorProvider)
          .updateGroundFloorCalculation(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Расчет сохранен.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $error')));
    }
  }

  Future<void> _handleDelete(String calculationId) async {
    await ref
        .read(projectEditorProvider)
        .deleteGroundFloorCalculation(calculationId);
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Ground floor v1 поддерживает один точный сценарий: плита по грунту. Другие типы уже заведены в модель, но пока отображаются как запланированные.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ProjectSummary extends StatelessWidget {
  const _ProjectSummary({
    required this.project,
    required this.selectedConstructionId,
  });

  final Project project;
  final String? selectedConstructionId;

  @override
  Widget build(BuildContext context) {
    final selectedConstruction = project.constructions.where(
      (item) => item.id == selectedConstructionId,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Проект и модуль',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(project.name),
            Text('Климат: ${project.climatePointId}'),
            Text('Нормативное помещение: ${project.roomPreset.label}'),
            Text(
              'Сохраненных расчетов: ${project.groundFloorCalculations.length}',
            ),
            if (selectedConstruction.isNotEmpty)
              Text('Конструкция: ${selectedConstruction.first.title}'),
          ],
        ),
      ),
    );
  }
}

class _CalculationListCard extends StatelessWidget {
  const _CalculationListCard({
    required this.project,
    required this.selectedCalculationId,
    required this.onSelect,
    required this.onAdd,
  });

  final Project project;
  final String? selectedCalculationId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final hasFloorConstruction = project.constructions.any(
      (item) =>
          item.elementKind == ConstructionElementKind.floor &&
          item.floorConstructionType == FloorConstructionType.onGround,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Сохраненные расчеты',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('ground-floor-add'),
                  onPressed: hasFloorConstruction ? onAdd : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            if (!hasFloorConstruction) ...[
              const SizedBox(height: 12),
              const Text(
                'Сначала добавьте в проект хотя бы одну конструкцию типа "Пол по грунту".',
              ),
            ],
            if (project.groundFloorCalculations.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...project.groundFloorCalculations.map((item) {
                final isSelected = item.id == selectedCalculationId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    key: ValueKey('ground-floor-tile-${item.id}'),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.kind.label} • ${item.areaSquareMeters.toStringAsFixed(1)} м²',
                    ),
                    trailing: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off_outlined,
                    ),
                    onTap: () => onSelect(item.id),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.project,
    required this.selectedKind,
    required this.selectedConstructionId,
    required this.titleController,
    required this.areaController,
    required this.perimeterController,
    required this.widthController,
    required this.lengthController,
    required this.edgeWidthController,
    required this.edgeResistanceController,
    required this.notesController,
    required this.onKindChanged,
    required this.onConstructionChanged,
    required this.onSave,
    required this.onDelete,
  });

  final Project project;
  final GroundFloorCalculationKind selectedKind;
  final String? selectedConstructionId;
  final TextEditingController titleController;
  final TextEditingController areaController;
  final TextEditingController perimeterController;
  final TextEditingController widthController;
  final TextEditingController lengthController;
  final TextEditingController edgeWidthController;
  final TextEditingController edgeResistanceController;
  final TextEditingController notesController;
  final ValueChanged<GroundFloorCalculationKind> onKindChanged;
  final ValueChanged<String?> onConstructionChanged;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final floorConstructions = project.constructions
        .where(
          (item) =>
              item.elementKind == ConstructionElementKind.floor &&
              item.floorConstructionType == FloorConstructionType.onGround,
        )
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Исходные данные',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('ground-floor-title'),
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название расчета'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GroundFloorCalculationKind>(
              key: const ValueKey('ground-floor-kind'),
              initialValue: selectedKind,
              decoration: const InputDecoration(labelText: 'Сценарий'),
              items: GroundFloorCalculationKind.values
                  .map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(item.label),
                    );
                  })
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onKindChanged(value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('ground-floor-construction'),
              initialValue: selectedConstructionId,
              decoration: const InputDecoration(labelText: 'Конструкция пола'),
              items: floorConstructions
                  .map((item) {
                    return DropdownMenuItem(
                      value: item.id,
                      child: Text(item.title),
                    );
                  })
                  .toList(growable: false),
              onChanged: onConstructionChanged,
            ),
            const SizedBox(height: 12),
            _NumericFieldRow(
              firstLabel: 'Площадь, м²',
              firstController: areaController,
              secondLabel: 'Периметр, м',
              secondController: perimeterController,
            ),
            const SizedBox(height: 12),
            _NumericFieldRow(
              firstLabel: 'Ширина плиты, м',
              firstController: widthController,
              secondLabel: 'Длина плиты, м',
              secondController: lengthController,
            ),
            const SizedBox(height: 12),
            _NumericFieldRow(
              firstLabel: 'Ширина утепления кромки, м',
              firstController: edgeWidthController,
              secondLabel: 'R утепления кромки',
              secondController: edgeResistanceController,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Примечание'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  key: const ValueKey('ground-floor-save'),
                  onPressed: onSave,
                  child: const Text('Сохранить'),
                ),
                FilledButton.tonal(
                  key: const ValueKey('ground-floor-delete'),
                  onPressed: onDelete,
                  child: const Text('Удалить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumericFieldRow extends StatelessWidget {
  const _NumericFieldRow({
    required this.firstLabel,
    required this.firstController,
    required this.secondLabel,
    required this.secondController,
  });

  final String firstLabel;
  final TextEditingController firstController;
  final String secondLabel;
  final TextEditingController secondController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: firstController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: firstLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: secondController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: secondLabel),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.catalog});

  final GroundFloorCalculationResult? result;
  final CatalogSnapshot catalog;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const SizedBox.shrink();
    }
    final appliedNorms = catalog.norms
        .where((item) => result!.appliedNormReferenceIds.contains(item.id))
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Результат',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              result!.statusMessage,
              style: TextStyle(
                color: result!.isSupported
                    ? null
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'R конструкции',
                  value:
                      '${result!.constructionResistance.toStringAsFixed(2)} м²·°C/Вт',
                ),
                _MetricTile(
                  label: 'R грунта',
                  value:
                      '${result!.equivalentGroundResistance.toStringAsFixed(2)} м²·°C/Вт',
                ),
                _MetricTile(
                  label: 'Итоговое R',
                  value:
                      '${result!.totalResistance.toStringAsFixed(2)} м²·°C/Вт',
                ),
                _MetricTile(
                  label: 'Требуемое R',
                  value:
                      '${result!.requiredResistance.toStringAsFixed(2)} м²·°C/Вт',
                ),
                _MetricTile(
                  label: 'Потери',
                  value: '${result!.heatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Удельные потери',
                  value:
                      '${result!.specificHeatLossWattsPerSquareMeter.toStringAsFixed(1)} Вт/м²',
                ),
                _MetricTile(
                  label: 'Периметр / площадь',
                  value: result!.shapeFactor.toStringAsFixed(2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result!.passesResistanceCheck
                  ? 'Требование по сопротивлению выполнено.'
                  : 'Требование по сопротивлению не выполнено.',
              style: TextStyle(
                color: result!.passesResistanceCheck
                    ? const Color(0xFF1E6A3B)
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (appliedNorms.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Нормативные ссылки: ${appliedNorms.map((item) => item.code).join(', ')}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
