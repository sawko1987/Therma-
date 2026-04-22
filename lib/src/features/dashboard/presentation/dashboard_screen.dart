import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../building_step/presentation/building_step_screen.dart';
import '../../construction_library/presentation/construction_step_screen.dart';
import '../../ground_floor/presentation/ground_floor_screen.dart';
import '../../heating_economics/presentation/heating_economics_screen.dart';
import '../../house_scheme/presentation/house_scheme_screen.dart';
import '../../object_step/presentation/object_step_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final objectListAsync = ref.watch(objectListProvider);
    final projectAsync = ref.watch(selectedProjectProvider);
    final objectAsync = ref.watch(selectedObjectProvider);
    final selectedObjectId = ref.watch(selectedObjectIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SmartCalc Mobile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _HeroCard(objectAsync: objectAsync, projectAsync: projectAsync),
          const SizedBox(height: 16),
          _ObjectListCard(
            objectListAsync: objectListAsync,
            selectedObjectId: selectedObjectId,
            onSelectObject: (object) {
              ref.read(selectedObjectIdProvider.notifier).select(object.id);
              ref
                  .read(selectedProjectIdProvider.notifier)
                  .select(object.projectId);
            },
          ),
          const SizedBox(height: 16),
          _CatalogOverview(catalogAsync: catalogAsync),
          const SizedBox(height: 16),
          _RoadmapCard(
            hasSelectedObject: selectedObjectId != null,
            onOpenObjectStep: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ObjectStepScreen(),
                ),
              );
            },
            onOpenConstructionStep: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ConstructionStepScreen(),
                ),
              );
            },
            onOpenBuildingStep: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BuildingStepScreen(),
                ),
              );
            },
            onOpenHouseScheme: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HouseSchemeScreen(),
                ),
              );
            },
            onOpenPreview: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ThermocalcScreen(),
                ),
              );
            },
            onOpenGroundFloor: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GroundFloorScreen(),
                ),
              );
            },
            onOpenHeatingEconomics: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HeatingEconomicsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const _RulesCard(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.objectAsync, required this.projectAsync});

  final AsyncValue<DesignObject?> objectAsync;
  final AsyncValue<Project?> projectAsync;

  @override
  Widget build(BuildContext context) {
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
                Chip(label: Text('Android first')),
                Chip(label: Text('Offline-first')),
                Chip(label: Text('Seasonal moisture')),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Инженерный калькулятор для мобильного сценария, а не перенос сайта один-в-один.',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Текущий каркас уже содержит доменные модели, локальные каталоги, нормативный экран теплозащиты, сезонный расчёт влагорежима, локальное хранение проектов, PDF-отчёт и рабочий конструктор дома для Phase 2.',
            ),
            const SizedBox(height: 18),
            objectAsync.when(
              data: (object) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF5F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.home_work_outlined, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            object == null
                                ? 'Объект пока не выбран'
                                : 'Активный объект: ${object.title}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (object != null && object.address.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          object.address,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка загрузки объекта: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectListCard extends StatelessWidget {
  const _ObjectListCard({
    required this.objectListAsync,
    required this.selectedObjectId,
    required this.onSelectObject,
  });

  final AsyncValue<List<DesignObject>> objectListAsync;
  final String? selectedObjectId;
  final ValueChanged<DesignObject> onSelectObject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: objectListAsync.when(
          data: (objects) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Объекты',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Сначала выберите объект проектирования, затем переходите к инженерным шагам расчета.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (objects.isEmpty)
                const Text('Пока нет объектов.')
              else
                ...objects.asMap().entries.map((entry) {
                  final index = entry.key;
                  final object = entry.value;
                  final isSelected =
                      object.id == selectedObjectId ||
                      (selectedObjectId == null && index == 0);

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == objects.length - 1 ? 0 : 12,
                    ),
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
                        [
                          if (object.address.isNotEmpty) object.address,
                          if (object.customerPhone.isNotEmpty)
                            'Телефон: ${object.customerPhone}',
                        ].join('\n'),
                      ),
                      isThreeLine: object.customerPhone.isNotEmpty,
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
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Ошибка загрузки объектов: $error'),
        ),
      ),
    );
  }
}

class _CatalogOverview extends StatelessWidget {
  const _CatalogOverview({required this.catalogAsync});

  final AsyncValue<CatalogSnapshot> catalogAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: catalogAsync.when(
          data: (catalog) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Локальные каталоги',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    label: 'Климат',
                    value: '${catalog.climatePoints.length}',
                  ),
                  _MetricTile(
                    label: 'Материалы',
                    value: '${catalog.materials.length}',
                  ),
                  _MetricTile(label: 'Нормы', value: '${catalog.norms.length}'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Версия датасета: ${catalog.datasetVersion}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Ошибка загрузки каталога: $error'),
        ),
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({
    required this.hasSelectedObject,
    required this.onOpenObjectStep,
    required this.onOpenConstructionStep,
    required this.onOpenBuildingStep,
    required this.onOpenHouseScheme,
    required this.onOpenPreview,
    required this.onOpenGroundFloor,
    required this.onOpenHeatingEconomics,
  });

  final bool hasSelectedObject;
  final VoidCallback onOpenObjectStep;
  final VoidCallback onOpenConstructionStep;
  final VoidCallback onOpenBuildingStep;
  final VoidCallback onOpenHouseScheme;
  final VoidCallback onOpenPreview;
  final VoidCallback onOpenGroundFloor;
  final VoidCallback onOpenHeatingEconomics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Что уже можно смотреть',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Открываются экран thermocalc, отдельный модуль полов по грунту v1 и пошаговый сценарий дома: выбор конструкций, планировка помещений и расчёт суммарных теплопотерь по зданию.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpenObjectStep,
              icon: const Icon(Icons.looks_3_outlined),
              label: const Text('Открыть шаг 0'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: hasSelectedObject ? onOpenConstructionStep : null,
              icon: const Icon(Icons.looks_one_outlined),
              label: const Text('Открыть шаг 1'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: hasSelectedObject ? onOpenBuildingStep : null,
              icon: const Icon(Icons.looks_two_outlined),
              label: const Text('Открыть шаг 2'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: hasSelectedObject ? onOpenHouseScheme : null,
              icon: const Icon(Icons.home_work_outlined),
              label: const Text('Открыть планировку дома'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: hasSelectedObject ? onOpenPreview : null,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Открыть thermocalc'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: hasSelectedObject ? onOpenGroundFloor : null,
              icon: const Icon(Icons.foundation_outlined),
              label: const Text('Открыть полы по грунту'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: hasSelectedObject ? onOpenHeatingEconomics : null,
              icon: const Icon(Icons.looks_3_outlined),
              label: const Text('Открыть шаг 3'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Зафиксированные правила',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text('Документация на русском, код на английском.'),
            const Text('Формулы и данные не прячутся во widgets.'),
            const Text(
              'Каждая расчётная правка требует тестов и ссылки на источник.',
            ),
            const Text('Чек-лист и ADR обновляются вместе с кодом.'),
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
      width: 104,
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
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
