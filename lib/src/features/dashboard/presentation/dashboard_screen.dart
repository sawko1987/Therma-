import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../thermocalc/presentation/thermocalc_preview_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final projectAsync = ref.watch(selectedProjectProvider);

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
          _RoadmapCard(
            onOpenPreview: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ThermocalcPreviewScreen(),
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
                Chip(label: Text('Thermocalc MVP')),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Инженерный калькулятор для мобильного сценария, а не перенос сайта один-в-один.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Текущий каркас уже содержит доменные модели, seed-данные, правила разработки и визуальный preview экрана расчета. Следующий крупный шаг — замена preview-движка на нормативный расчет.',
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
                            : 'Активный demo-проект: ${project.name}',
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

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.onOpenPreview});

  final VoidCallback onOpenPreview;

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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Открывается preview основного экрана thermocalc: слои конструкции, статусные индикаторы, сечение и графики. Это рабочий scaffold для UX и архитектуры, а не финальный нормативный расчет.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpenPreview,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Открыть thermocalc preview'),
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
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            const Text('Документация на русском, код на английском.'),
            const Text('Формулы и данные не прячутся во widgets.'),
            const Text('Каждая расчетная правка требует тестов и ссылки на источник.'),
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
