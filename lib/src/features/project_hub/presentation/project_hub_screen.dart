import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_navigation.dart';
import '../../../core/logging/app_logging.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../object_step/presentation/object_step_screen.dart';

class ProjectHubScreen extends ConsumerWidget {
  const ProjectHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectListAsync = ref.watch(objectListProvider);
    final selectedObjectId = ref.watch(selectedObjectIdProvider);
    final selectedObjectAsync = ref.watch(selectedObjectProvider);
    final selectedProjectAsync = ref.watch(selectedProjectProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Проект')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openObjectEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Новый объект'),
      ),
      body: ListView(
        key: const PageStorageKey<String>('project-hub-list'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        children: [
          _ProjectHubHeader(
            onCreateObject: () => _openObjectEditor(context, ref),
            onOpenReferences: () => switchToTab(ref, AppTab.settings),
          ),
          const SizedBox(height: 16),
          objectListAsync.when(
            data: (objects) => _ObjectSelectionCard(
              objects: objects,
              selectedObjectId: selectedObjectId,
              onSelectObject: (object) => _selectObject(ref, object),
              onEditObject: (object) =>
                  _openObjectEditor(context, ref, object: object),
              onDeleteObject: (object) => _deleteObject(context, ref, object),
              onCreateObject: () => _openObjectEditor(context, ref),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка загрузки объектов: $error'),
          ),
          const SizedBox(height: 16),
          selectedObjectAsync.when(
            data: (selectedObject) => selectedProjectAsync.when(
              data: (project) {
                final progress = _ProjectProgress.fromData(
                  object: selectedObject,
                  project: project,
                );
                return Column(
                  children: [
                    _ProjectReadinessCard(
                      progress: progress,
                      onNextStep: () =>
                          _openProgressStep(context, progress.nextStep),
                    ),
                    const SizedBox(height: 16),
                    _ProjectStepsCard(
                      progress: progress,
                      canOpenDetailFlows: selectedObject != null,
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка проекта: $error'),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка активного объекта: $error'),
          ),
        ],
      ),
    );
  }

  Future<void> _openObjectEditor(
    BuildContext context,
    WidgetRef ref, {
    DesignObject? object,
  }) async {
    final result = await showObjectEditorSheet(context, object: object);
    if (!context.mounted || result == null) {
      return;
    }

    final reporter = ref.read(appErrorReporterProvider);
    final completed = await reporter.runUiAction(
      context: context,
      action: () async {
        if (object == null) {
          await ref
              .read(projectEditorProvider)
              .createObject(
                title: result.title,
                address: result.address,
                description: result.description,
                customerPhone: result.customerPhone,
                climatePointId: result.climatePointId,
              );
          return true;
        }
        await ref
            .read(projectEditorProvider)
            .updateObject(
              object.copyWith(
                title: result.title,
                address: result.address,
                description: result.description,
                customerPhone: result.customerPhone,
                climatePointId: result.climatePointId,
                updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
              ),
            );
        return true;
      },
      operation: object == null
          ? 'Failed to create object from project hub'
          : 'Failed to update object from project hub',
      userMessage: object == null
          ? 'Не удалось создать объект.'
          : 'Не удалось обновить объект.',
      category: AppLogCategory.ui,
    );

    if (completed == true && context.mounted) {
      final message = object == null ? 'Объект создан.' : 'Объект обновлён.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _deleteObject(
    BuildContext context,
    WidgetRef ref,
    DesignObject object,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить объект?'),
          content: Text('Объект «${object.title}» будет удалён вместе с проектом.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final completed = await ref
        .read(appErrorReporterProvider)
        .runUiAction(
          context: context,
          action: () async {
            await ref.read(projectEditorProvider).deleteObject(object.id);
            return true;
          },
          operation: 'Failed to delete object from project hub',
          userMessage: 'Не удалось удалить объект.',
          category: AppLogCategory.ui,
          contextData: {'objectId': object.id, 'projectId': object.projectId},
        );
    if (completed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Объект удалён.')),
      );
    }
  }

  void _selectObject(WidgetRef ref, DesignObject object) {
    ref.read(selectedObjectIdProvider.notifier).select(object.id);
    ref.read(selectedProjectIdProvider.notifier).select(object.projectId);
  }

  Future<void> _openProgressStep(
    BuildContext context,
    _ProjectHubStep step,
  ) {
    switch (step) {
      case _ProjectHubStep.object:
        return openObjectStepScreen(context);
      case _ProjectHubStep.construction:
        return openConstructionStepScreen(context);
      case _ProjectHubStep.plan:
        return openBuildingStepScreen(context);
      case _ProjectHubStep.heating:
        return openHeatingEconomicsScreen(context);
    }
  }
}

class _ProjectHubHeader extends StatelessWidget {
  const _ProjectHubHeader({
    required this.onCreateObject,
    required this.onOpenReferences,
  });

  final VoidCallback onCreateObject;
  final VoidCallback onOpenReferences;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Проектный хаб',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Здесь выбирается активный объект, проверяется готовность проекта и открываются рабочие шаги 0-3 без переключения в линейный мастер.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onCreateObject,
                  icon: const Icon(Icons.add_home_outlined),
                  label: const Text('Новый объект'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenReferences,
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('Справочники'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectSelectionCard extends StatelessWidget {
  const _ObjectSelectionCard({
    required this.objects,
    required this.selectedObjectId,
    required this.onSelectObject,
    required this.onEditObject,
    required this.onDeleteObject,
    required this.onCreateObject,
  });

  final List<DesignObject> objects;
  final String? selectedObjectId;
  final ValueChanged<DesignObject> onSelectObject;
  final ValueChanged<DesignObject> onEditObject;
  final ValueChanged<DesignObject> onDeleteObject;
  final VoidCallback onCreateObject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Активный объект',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Выберите объект, чтобы корневые вкладки работали в контексте нужного проекта.',
            ),
            const SizedBox(height: 16),
            if (objects.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Пока нет ни одного объекта.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onCreateObject,
                    icon: const Icon(Icons.add),
                    label: const Text('Создать первый объект'),
                  ),
                ],
              )
            else
              ...objects.map((object) {
                final isSelected = object.id == selectedObjectId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    title: Text(
                      object.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (object.address.isNotEmpty) object.address,
                        if (object.customerPhone.isNotEmpty)
                          'Телефон: ${object.customerPhone}',
                        if (object.description.isNotEmpty) object.description,
                      ].join('\n'),
                    ),
                    isThreeLine:
                        object.customerPhone.isNotEmpty ||
                        object.description.isNotEmpty,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off_outlined,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'select':
                            onSelectObject(object);
                            break;
                          case 'edit':
                            onEditObject(object);
                            break;
                          case 'delete':
                            onDeleteObject(object);
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'select',
                          child: Text('Сделать активным'),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Редактировать'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Удалить')),
                      ],
                    ),
                    onTap: () => onSelectObject(object),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ProjectReadinessCard extends StatelessWidget {
  const _ProjectReadinessCard({
    required this.progress,
    required this.onNextStep,
  });

  final _ProjectProgress progress;
  final VoidCallback onNextStep;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Готовность проекта',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(progress.summary),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ProgressMetric(
                  label: 'Шагов закрыто',
                  value: '${progress.completedSteps}/4',
                ),
                _ProgressMetric(
                  label: 'Комнат',
                  value: '${progress.roomCount}',
                ),
                _ProgressMetric(
                  label: 'Конструкций',
                  value: '${progress.constructionCount}',
                ),
                _ProgressMetric(
                  label: 'Расчётов пола',
                  value: '${progress.groundFloorCount}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNextStep,
                icon: const Icon(Icons.arrow_forward),
                label: Text(progress.nextStepLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectStepsCard extends StatelessWidget {
  const _ProjectStepsCard({
    required this.progress,
    required this.canOpenDetailFlows,
  });

  final _ProjectProgress progress;
  final bool canOpenDetailFlows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Шаги 0-3',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _ProjectStepTile(
              title: 'Шаг 0. Объект',
              description:
                  'Карточка объекта, климатическая точка и выбор активного проекта.',
              statusLabel: progress.objectStatus,
              onOpen: () => openObjectStepScreen(context),
            ),
            const Divider(),
            _ProjectStepTile(
              title: 'Шаг 1. Конструкции',
              description:
                  'Состав конструкций проекта и готовность набора к расчёту.',
              statusLabel: progress.constructionStatus,
              onOpen: canOpenDetailFlows
                  ? () => openConstructionStepScreen(context)
                  : null,
            ),
            const Divider(),
            _ProjectStepTile(
              title: 'Шаг 2. Помещения',
              description:
                  'Комнаты, план дома и связь ограждений с помещениями.',
              statusLabel: progress.planStatus,
              onOpen:
                  canOpenDetailFlows ? () => openBuildingStepScreen(context) : null,
            ),
            const Divider(),
            _ProjectStepTile(
              title: 'Шаг 3. Отопление и экономика',
              description:
                  'Теплопотери здания, тарифы и проверка инженерного сценария.',
              statusLabel: progress.heatingStatus,
              onOpen: canOpenDetailFlows
                  ? () => openHeatingEconomicsScreen(context)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectStepTile extends StatelessWidget {
  const _ProjectStepTile({
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.onOpen,
  });

  final String title;
  final String description;
  final String statusLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('$statusLabel\n$description'),
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onOpen,
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFF5F4EE),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

enum _ProjectHubStep { object, construction, plan, heating }

class _ProjectProgress {
  const _ProjectProgress({
    required this.object,
    required this.project,
    required this.hasConstructions,
    required this.hasPlan,
    required this.hasHeatingScenario,
  });

  factory _ProjectProgress.fromData({
    required DesignObject? object,
    required Project? project,
  }) {
    final hasConstructions =
        project?.effectiveSelectedConstructionIds.isNotEmpty ?? false;
    final hasPlan = project != null && _hasDetailedPlan(project);
    final hasHeatingScenario = project != null && _hasHeatingScenario(project);
    return _ProjectProgress(
      object: object,
      project: project,
      hasConstructions: hasConstructions,
      hasPlan: hasPlan,
      hasHeatingScenario: hasHeatingScenario,
    );
  }

  final DesignObject? object;
  final Project? project;
  final bool hasConstructions;
  final bool hasPlan;
  final bool hasHeatingScenario;

  int get completedSteps => [
    object != null,
    hasConstructions,
    hasPlan,
    hasHeatingScenario,
  ].where((item) => item).length;

  int get roomCount => project?.houseModel.rooms.length ?? 0;
  int get constructionCount => project?.effectiveSelectedConstructionIds.length ?? 0;
  int get groundFloorCount => project?.groundFloorCalculations.length ?? 0;

  String get summary {
    if (object == null) {
      return 'Проект ещё не стартовал: сначала создайте или выберите объект.';
    }
    if (!hasConstructions) {
      return 'Объект выбран. Следующий критичный шаг: собрать конструкции проекта.';
    }
    if (!hasPlan) {
      return 'Конструкции готовы. Теперь нужно описать помещения и план дома.';
    }
    if (!hasHeatingScenario) {
      return 'План собран. Осталось проверить расчётный сценарий отопления и экономики.';
    }
    return 'Проект готов к рабочим расчётам: объект, конструкции, план и отопительный сценарий собраны.';
  }

  _ProjectHubStep get nextStep {
    if (object == null) {
      return _ProjectHubStep.object;
    }
    if (!hasConstructions) {
      return _ProjectHubStep.construction;
    }
    if (!hasPlan) {
      return _ProjectHubStep.plan;
    }
    return _ProjectHubStep.heating;
  }

  String get nextStepLabel {
    return switch (nextStep) {
      _ProjectHubStep.object => 'Открыть шаг 0',
      _ProjectHubStep.construction => 'Перейти к шагу 1',
      _ProjectHubStep.plan => 'Перейти к шагу 2',
      _ProjectHubStep.heating => 'Перейти к шагу 3',
    };
  }

  String get objectStatus =>
      object == null ? 'Не выбран объект' : 'Объект выбран';

  String get constructionStatus =>
      hasConstructions ? 'Конструкции собраны' : 'Нет активных конструкций';

  String get planStatus =>
      hasPlan ? 'План дома уточнён' : 'Нужна детализация помещений';

  String get heatingStatus => hasHeatingScenario
      ? 'Расчётный сценарий заполнен'
      : 'Нет инженерного сценария';
}

bool _hasDetailedPlan(Project project) {
  final hasAdditionalRooms = project.houseModel.rooms.any(
    (room) => room.id != defaultRoomId,
  );
  final hasPlacedEnvelope = project.houseModel.elements.any(
    (element) => element.wallPlacement != null,
  );
  return hasAdditionalRooms ||
      hasPlacedEnvelope ||
      project.houseModel.openings.isNotEmpty;
}

bool _hasHeatingScenario(Project project) {
  return project.groundFloorCalculations.isNotEmpty ||
      project.houseModel.heatingDevices.isNotEmpty;
}
