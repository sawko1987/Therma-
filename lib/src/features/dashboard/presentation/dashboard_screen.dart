import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_navigation.dart';
import '../../../core/logging/app_logging.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../object_step/presentation/object_step_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectListAsync = ref.watch(objectListProvider);
    final selectedObjectAsync = ref.watch(selectedObjectProvider);
    final selectedProjectAsync = ref.watch(selectedProjectProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SmartCalc Mobile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        key: const PageStorageKey<String>('dashboard-list'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          selectedObjectAsync.when(
            data: (object) => selectedProjectAsync.when(
              data: (project) => _HeroCard(object: object, project: project),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка проекта: $error'),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка активного объекта: $error'),
          ),
          const SizedBox(height: 16),
          _QuickActionsCard(
            onCreateObject: () => _createObject(context, ref),
            onOpenPlan: () => switchToTab(ref, AppTab.plan),
            onOpenThermocalc: () => _openThermocalc(context, ref),
            onOpenReferences: () => switchToTab(ref, AppTab.settings),
          ),
          const SizedBox(height: 16),
          selectedProjectAsync.when(
            data: (project) => _ProjectStatusCard(project: project),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка статуса проекта: $error'),
          ),
          const SizedBox(height: 16),
          objectListAsync.when(
            data: (objects) => _ObjectSwitcherCard(
              objects: objects,
              selectedObjectId: ref.watch(selectedObjectIdProvider),
              onSelectObject: (object) {
                ref.read(selectedObjectIdProvider.notifier).select(object.id);
                ref
                    .read(selectedProjectIdProvider.notifier)
                    .select(object.projectId);
              },
              onOpenProjectTab: () => switchToTab(ref, AppTab.project),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка списка объектов: $error'),
          ),
        ],
      ),
    );
  }

  Future<void> _createObject(BuildContext context, WidgetRef ref) async {
    final result = await showObjectEditorSheet(context);
    if (!context.mounted || result == null) {
      return;
    }

    final completed = await ref
        .read(appErrorReporterProvider)
        .runUiAction(
          context: context,
          action: () async {
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
          },
          operation: 'Failed to create object from dashboard',
          userMessage: 'Не удалось создать объект.',
          category: AppLogCategory.ui,
        );
    if (completed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Объект создан.')),
      );
    }
  }

  Future<void> _openThermocalc(BuildContext context, WidgetRef ref) async {
    final project = await ref.read(selectedProjectProvider.future);
    if (!context.mounted) {
      return;
    }
    if (project == null) {
      switchToTab(ref, AppTab.calculations);
      return;
    }
    await openThermocalcScreen(context);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.object,
    required this.project,
  });

  final DesignObject? object;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final currentObject = object;
    final currentProject = project;
    final title = currentObject == null
        ? 'Активный объект не выбран'
        : currentObject.title;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                Chip(label: Text('Главная')),
                Chip(label: Text('Проектный сценарий')),
                Chip(label: Text('Android first')),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              currentObject == null
                  ? 'Выберите объект во вкладке «Проект», чтобы открыть план дома и расчётные модули.'
                  : 'Главная показывает состояние активного объекта, быстрые переходы по разделам и текущий статус проекта.',
            ),
            if (currentObject != null && currentObject.address.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(currentObject.address),
            ],
            if (currentProject != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HeroMetric(
                    label: 'Конструкций',
                    value:
                        '${currentProject.effectiveSelectedConstructionIds.length}',
                  ),
                  _HeroMetric(
                    label: 'Комнат',
                    value: '${currentProject.houseModel.rooms.length}',
                  ),
                  _HeroMetric(
                    label: 'Ограждений',
                    value: '${currentProject.houseModel.elements.length}',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onCreateObject,
    required this.onOpenPlan,
    required this.onOpenThermocalc,
    required this.onOpenReferences,
  });

  final VoidCallback onCreateObject;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenThermocalc;
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
              'Быстрые переходы',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickActionButton(
                  icon: Icons.add_home_outlined,
                  label: 'Новый объект',
                  onPressed: onCreateObject,
                ),
                _QuickActionButton(
                  icon: Icons.home_work_outlined,
                  label: 'План дома',
                  onPressed: onOpenPlan,
                ),
                _QuickActionButton(
                  icon: Icons.thermostat_outlined,
                  label: 'Thermocalc',
                  onPressed: onOpenThermocalc,
                ),
                _QuickActionButton(
                  icon: Icons.library_books_outlined,
                  label: 'Справочники',
                  onPressed: onOpenReferences,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectStatusCard extends StatelessWidget {
  const _ProjectStatusCard({required this.project});

  final Project? project;

  @override
  Widget build(BuildContext context) {
    if (project == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Статус проекта',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Пока нет выбранного проекта.'),
            ],
          ),
        ),
      );
    }

    final hasPlanDetails = project!.houseModel.openings.isNotEmpty ||
        project!.houseModel.heatingDevices.isNotEmpty ||
        project!.houseModel.rooms.any((room) => room.id != defaultRoomId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статус проекта',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(project!.name),
            const SizedBox(height: 12),
            Text(
              hasPlanDetails
                  ? 'Проект уже содержит уточнённый план дома и инженерные данные.'
                  : 'Проект запущен, но план дома ещё требует детализации.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatusMetric(
                  label: 'Проёмы',
                  value: '${project!.houseModel.openings.length}',
                ),
                _StatusMetric(
                  label: 'Приборы',
                  value: '${project!.houseModel.heatingDevices.length}',
                ),
                _StatusMetric(
                  label: 'Полы по грунту',
                  value: '${project!.groundFloorCalculations.length}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectSwitcherCard extends StatelessWidget {
  const _ObjectSwitcherCard({
    required this.objects,
    required this.selectedObjectId,
    required this.onSelectObject,
    required this.onOpenProjectTab,
  });

  final List<DesignObject> objects;
  final String? selectedObjectId;
  final ValueChanged<DesignObject> onSelectObject;
  final VoidCallback onOpenProjectTab;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Объекты',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (objects.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Объекты пока не созданы.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onOpenProjectTab,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Открыть вкладку Проект'),
                  ),
                ],
              )
            else
              ...objects.map((object) {
                final isSelected = object.id == selectedObjectId;
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      object.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      object.address.isEmpty ? 'Адрес не указан' : object.address,
                    ),
                    trailing: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off_outlined,
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

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFEAF3F0),
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

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({
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
        color: const Color(0xFFF8F5EE),
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
