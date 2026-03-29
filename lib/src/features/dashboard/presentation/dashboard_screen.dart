import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/calculation.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../building_builder/presentation/building_wizard_screen.dart';
import '../../thermocalc/presentation/thermocalc_preview_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final projectAsync = ref.watch(selectedProjectProvider);
    final heatLossAsync = ref.watch(selectedBuildingHeatLossProvider);

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
          _CatalogOverview(catalogAsync: catalogAsync),
          const SizedBox(height: 16),
          _Step2Card(
            projectAsync: projectAsync,
            heatLossAsync: heatLossAsync,
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
                Chip(label: Text('Шаг 0: объект')),
                Chip(label: Text('Шаг 1: конструкции')),
                Chip(label: Text('Шаг 2: теплопотери')),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Основной сценарий теперь строится вокруг расчетного объекта: комнаты, поверхности, проемы и полный баланс потерь по помещению и по дому.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Construction preview сохранен как отдельный экран детализации, но главным рабочим потоком стал wizard шага 2 с агрегацией по комнатам и объекту.',
            ),
            const SizedBox(height: 18),
            projectAsync.when(
              data: (project) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF5F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.home_work_outlined, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        project == null
                            ? 'Демо-проект пока не загружен'
                            : 'Активный demo-проект: ${project.name} · ${project.rooms.length} комнат · ${project.constructions.length} конструкций',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
                  _MetricTile(
                    label: 'Нормы',
                    value: '${catalog.norms.length}',
                  ),
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

class _Step2Card extends StatelessWidget {
  const _Step2Card({
    required this.projectAsync,
    required this.heatLossAsync,
  });

  final AsyncValue<Project?> projectAsync;
  final AsyncValue<BuildingHeatLossResult?> heatLossAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Шаг 2: расчетный объект',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Wizard собирает объект из комнат, ограждающих поверхностей и проемов, после чего считает потери через ограждения, вентиляцию и общий баланс.',
            ),
            const SizedBox(height: 16),
            heatLossAsync.when(
              data: (result) => result == null
                  ? const Text('Нет результата по демо-объекту.')
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricTile(
                          label: 'Комнаты',
                          value: '${result.roomResults.length}',
                        ),
                        _MetricTile(
                          label: 'Вт потерь',
                          value: result.totalLossW.toStringAsFixed(0),
                        ),
                        _MetricTile(
                          label: 'Вт/К',
                          value: result.heatLossCoefficientWPerK.toStringAsFixed(1),
                        ),
                      ],
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка расчета: $error'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    final project = projectAsync.value;
                    if (project == null) {
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BuildingWizardScreen(initialProject: project),
                      ),
                    );
                  },
                  icon: const Icon(Icons.stacked_line_chart_outlined),
                  label: const Text('Открыть wizard шага 2'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ThermocalcPreviewScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Открыть preview конструкции'),
                ),
              ],
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text('Документация на русском, код на английском.'),
            const Text('Формулы и данные не прячутся во widgets.'),
            const Text('Шаг 2 обязан отдавать стабильный результат для шага 3.'),
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
      width: 112,
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
