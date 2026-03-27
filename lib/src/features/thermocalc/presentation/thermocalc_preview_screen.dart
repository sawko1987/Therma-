import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/calculation.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import 'widgets/line_chart_painter.dart';
import 'widgets/section_painter.dart';

class ThermocalcPreviewScreen extends ConsumerWidget {
  const ThermocalcPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final constructionAsync = ref.watch(previewConstructionProvider);
    final calculationAsync = ref.watch(previewCalculationProvider);
    final catalogAsync = ref.watch(catalogSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thermocalc Preview',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const _PreviewBanner(),
          const SizedBox(height: 16),
          _ProjectSummary(
            projectAsync: projectAsync,
            constructionAsync: constructionAsync,
            catalogAsync: catalogAsync,
          ),
          const SizedBox(height: 16),
          calculationAsync.when(
            data: (calculation) => constructionAsync.when(
              data: (construction) {
                if (calculation == null || construction == null) {
                  return const Text('Недостаточно данных для preview.');
                }
                return _CalculationBody(
                  calculation: calculation,
                  construction: construction,
                  catalogAsync: catalogAsync,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка конструкции: $error'),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка расчета: $error'),
          ),
        ],
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Важно: это preview-экран для архитектуры и визуализаций. Расчетный движок пока черновой и не заменяет нормативную реализацию.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ProjectSummary extends StatelessWidget {
  const _ProjectSummary({
    required this.projectAsync,
    required this.constructionAsync,
    required this.catalogAsync,
  });

  final AsyncValue<Project?> projectAsync;
  final AsyncValue<Construction?> constructionAsync;
  final AsyncValue<CatalogSnapshot> catalogAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Проект и исходные условия',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            projectAsync.when(
              data: (project) => constructionAsync.when(
                data: (construction) => catalogAsync.when(
                  data: (catalog) {
                    final climate = project == null
                        ? null
                        : catalog.climatePoints.firstWhere(
                            (item) => item.id == project.climatePointId,
                          );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project?.name ?? 'Нет проекта'),
                        const SizedBox(height: 6),
                        Text('Климат: ${climate?.displayName ?? '—'}'),
                        Text('Помещение: ${project?.roomPreset.label ?? '—'}'),
                        Text('Конструкция: ${construction?.title ?? '—'}'),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Ошибка каталога: $error'),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Ошибка конструкции: $error'),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка проекта: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalculationBody extends StatelessWidget {
  const _CalculationBody({
    required this.calculation,
    required this.construction,
    required this.catalogAsync,
  });

  final CalculationResult calculation;
  final Construction construction;
  final AsyncValue<CatalogSnapshot> catalogAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Индикаторы',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: calculation.complianceIndicators
                      .map((indicator) => _IndicatorTile(indicator: indicator))
                      .toList(),
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
                  'Сечение конструкции',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                catalogAsync.when(
                  data: (catalog) => SizedBox(
                    height: 180,
                    child: CustomPaint(
                      painter: SectionPainter(
                        construction: construction,
                        materials: {
                          for (final material in catalog.materials)
                            material.id: material
                        },
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Ошибка каталога: $error'),
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
                  'Графики',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 170,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      series: calculation.temperatureSeries,
                      color: const Color(0xFF006D77),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      series: calculation.humiditySeries,
                      color: const Color(0xFFB45309),
                    ),
                    child: const SizedBox.expand(),
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
                  'Слои и preview-метрики',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Сопротивление теплопередаче: ${calculation.totalResistance.toStringAsFixed(2)} м²·°C/Вт',
                ),
                Text(
                  'Теплопотери: ${calculation.heatLossPerSqm.toStringAsFixed(1)} Вт/м²',
                ),
                const SizedBox(height: 14),
                ...calculation.layerRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            row.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${row.thicknessMm.toStringAsFixed(0)} мм'),
                        const SizedBox(width: 12),
                        Text('R ${row.resistance.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  const _IndicatorTile({required this.indicator});

  final ComplianceIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final color = indicator.isPassed
        ? const Color(0xFF0F766E)
        : const Color(0xFFB45309);

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            indicator.isPassed ? Icons.verified_outlined : Icons.warning_amber,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(
            indicator.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${indicator.actual.toStringAsFixed(1)} / ${indicator.target.toStringAsFixed(1)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
