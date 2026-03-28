import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../ground_floor/presentation/ground_floor_screen.dart';
import '../../house_scheme/presentation/house_scheme_screen.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final projectListAsync = ref.watch(projectListProvider);
    final projectAsync = ref.watch(selectedProjectProvider);
    final selectedProjectId = ref.watch(selectedProjectIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SmartCalc Mobile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _HeroCard(projectAsync: projectAsync),
          const SizedBox(height: 16),
          _ProjectListCard(
            projectListAsync: projectListAsync,
            selectedProjectId: selectedProjectId,
            onSelectProject: (projectId) {
              ref.read(selectedProjectIdProvider.notifier).select(projectId);
            },
          ),
          const SizedBox(height: 16),
          _CatalogOverview(catalogAsync: catalogAsync),
          const SizedBox(height: 16),
          _RoadmapCard(
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
          ),
          const SizedBox(height: 16),
          const _RulesCard(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.projectAsync});

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
            projectAsync.when(
              data: (project) => Container(
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
                            project == null
                                ? 'Сохранённый проект пока не загружен'
                                : 'Активный проект: ${project.name}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (project?.datasetMigrationLabel
                        case final migrationLabel?)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          migrationLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка загрузки проекта: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectListCard extends StatelessWidget {
  const _ProjectListCard({
    required this.projectListAsync,
    required this.selectedProjectId,
    required this.onSelectProject,
  });

  final AsyncValue<List<Project>> projectListAsync;
  final String? selectedProjectId;
  final ValueChanged<String> onSelectProject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: projectListAsync.when(
          data: (projects) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Сохранённые проекты',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Проекты читаются из локального хранилища и доступны после перезапуска приложения.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (projects.isEmpty)
                const Text('Пока нет сохранённых проектов.')
              else
                ...projects.asMap().entries.map((entry) {
                  final index = entry.key;
                  final project = entry.value;
                  final isSelected =
                      project.id == selectedProjectId ||
                      (selectedProjectId == null && index == 0);

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == projects.length - 1 ? 0 : 12,
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
                        project.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          '${project.roomPreset.label} • ${project.constructions.length} конструкция(й)',
                          ...?switch (project.datasetMigrationLabel) {
                            final String migrationLabel => [migrationLabel],
                            null => null,
                          },
                        ].join('\n'),
                      ),
                      isThreeLine: project.hasDatasetMigration,
                      trailing: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off_outlined,
                      ),
                      onTap: () => onSelectProject(project.id),
                    ),
                  );
                }),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Ошибка загрузки проектов: $error'),
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
    required this.onOpenHouseScheme,
    required this.onOpenPreview,
    required this.onOpenGroundFloor,
  });

  final VoidCallback onOpenHouseScheme;
  final VoidCallback onOpenPreview;
  final VoidCallback onOpenGroundFloor;

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
              'Открываются экран thermocalc, отдельный модуль полов по грунту v1 и конструктор дома из Phase 2: помещения, ограждения, конструкции и запуск расчёта из выбранного элемента.',
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onOpenHouseScheme,
              icon: const Icon(Icons.home_work_outlined),
              label: const Text('Открыть сборку дома'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenPreview,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Открыть thermocalc'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onOpenGroundFloor,
              icon: const Icon(Icons.foundation_outlined),
              label: const Text('Открыть полы по грунту'),
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
