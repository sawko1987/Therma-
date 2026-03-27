import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/calculation.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import 'widgets/line_chart_painter.dart';
import 'widgets/section_painter.dart';

class ThermocalcScreen extends ConsumerWidget {
  const ThermocalcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final constructionAsync = ref.watch(selectedConstructionProvider);
    final calculationAsync = ref.watch(calculationResultProvider);
    final catalogAsync = ref.watch(catalogSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thermocalc',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const _StatusBanner(),
          const SizedBox(height: 16),
          _ProjectSummary(
            projectAsync: projectAsync,
            constructionAsync: constructionAsync,
            catalogAsync: catalogAsync,
          ),
          const SizedBox(height: 16),
          calculationAsync.when(
            data: (calculation) => constructionAsync.when(
              data: (construction) => catalogAsync.when(
                data: (catalog) {
                  if (calculation == null || construction == null) {
                    return const Text('Недостаточно данных для расчета.');
                  }
                  return _CalculationBody(
                    calculation: calculation,
                    construction: construction,
                    catalog: catalog,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Ошибка каталога: $error'),
              ),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE7F4EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Текущий экран использует нормативный расчет теплозащиты v1 и MVP-скрининг влагорежима: сопротивление теплопередаче, температурный профиль, послойное паросопротивление и ссылки на примененные нормы. PDF-отчет остаётся следующим этапом.',
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
    required this.catalog,
  });

  final CalculationResult calculation;
  final Construction construction;
  final CatalogSnapshot catalog;

  @override
  Widget build(BuildContext context) {
    final materialMap = {
      for (final material in catalog.materials) material.id: material,
    };
    final appliedNorms = catalog.norms
        .where((norm) => calculation.appliedNormReferenceIds.contains(norm.id))
        .toList(growable: false);

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Нормативные показатели',
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
                      label: 'Фактическое R',
                      value:
                          '${calculation.totalResistance.toStringAsFixed(2)} м²·°C/Вт',
                    ),
                    _MetricTile(
                      label: 'Требуемое R',
                      value:
                          '${calculation.requiredResistance.toStringAsFixed(2)} м²·°C/Вт',
                    ),
                    _MetricTile(
                      label: 'Запас',
                      value:
                          '${calculation.resistanceMargin.toStringAsFixed(2)} м²·°C/Вт',
                    ),
                    _MetricTile(
                      label: 'Условия',
                      value:
                          '${calculation.insideAirTemperature.toStringAsFixed(0)} / ${calculation.outsideAirTemperature.toStringAsFixed(0)} °C',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: calculation.complianceIndicators
                      .map(
                        (indicator) => _IndicatorTile(
                          indicator: indicator,
                          norm: catalog.norms
                              .where((norm) => norm.id == indicator.normReferenceId)
                              .firstOrNull,
                        ),
                      )
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
                  'MVP-скрининг влагорежима',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(calculation.moistureCheck.summary),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricTile(
                      label: 'Σ паросопротивление',
                      value:
                          '${calculation.moistureCheck.totalVaporResistance.toStringAsFixed(2)} м²·ч·Па/мг',
                    ),
                    _MetricTile(
                      label: 'Минимум для помещения',
                      value:
                          '${calculation.moistureCheck.minimumRecommendedVaporResistance.toStringAsFixed(2)} м²·ч·Па/мг',
                    ),
                    _MetricTile(
                      label: 'Наружный/внутренний слой',
                      value:
                          '${calculation.moistureCheck.outwardDryingRatio.toStringAsFixed(2)}',
                    ),
                    _MetricTile(
                      label: 'Статус скрининга',
                      value: calculation.moistureCheck.level.label,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: calculation.moistureCheck.indicators
                      .map(
                        (indicator) => _IndicatorTile(
                          indicator: indicator,
                          norm: catalog.norms
                              .where((norm) => norm.id == indicator.normReferenceId)
                              .firstOrNull,
                        ),
                      )
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
                SizedBox(
                  height: 180,
                  child: CustomPaint(
                    painter: SectionPainter(
                      construction: construction,
                      materials: materialMap,
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
                  'Профиль паросопротивления',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Минимум для помещения: ${calculation.moistureCheck.minimumRecommendedVaporResistance.toStringAsFixed(2)} м²·ч·Па/мг',
                ),
                Text(
                  'Максимальный ratio наружного/внутреннего слоя: ${calculation.moistureCheck.maximumRecommendedOutwardDryingRatio.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      series: calculation.moistureCheck.vaporResistanceSeries,
                      color: const Color(0xFF8B5E34),
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
                  'Температурный профиль',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Температура внутренней поверхности: ${calculation.insideSurfaceTemperature.toStringAsFixed(1)} °C',
                ),
                Text(
                  'Температура наружной поверхности: ${calculation.outsideSurfaceTemperature.toStringAsFixed(1)} °C',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      series: calculation.temperatureSeries,
                      color: const Color(0xFF006D77),
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
                  'Послойное паросопротивление',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                ...calculation.moistureCheck.layerRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.title,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${row.thicknessMm.toStringAsFixed(0)} мм, δ ${row.vaporPermeability.toStringAsFixed(2)}, Z ${row.vaporResistance.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Σ ${row.cumulativeVaporResistance.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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
                  'Послойный расчет',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                ...calculation.layerRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.title,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${row.thicknessMm.toStringAsFixed(0)} мм, λ ${row.thermalConductivity.toStringAsFixed(3)}, R ${row.resistance.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${row.tempStart.toStringAsFixed(1)} → ${row.tempEnd.toStringAsFixed(1)} °C',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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
                  'Примененные нормы',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                ...appliedNorms.map(
                  (norm) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('${norm.code} • ${norm.title}'),
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
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
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  const _IndicatorTile({
    required this.indicator,
    required this.norm,
  });

  final ComplianceIndicator indicator;
  final NormReference? norm;

  @override
  Widget build(BuildContext context) {
    final color =
        indicator.isPassed ? const Color(0xFF0F766E) : const Color(0xFFB45309);

    return Container(
      width: 220,
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
            indicator.unit == 'ratio'
                ? '${indicator.actual.toStringAsFixed(2)} / ${indicator.target.toStringAsFixed(2)}'
                : '${indicator.actual.toStringAsFixed(2)} / ${indicator.target.toStringAsFixed(2)} ${indicator.unit}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          if (norm != null) ...[
            const SizedBox(height: 6),
            Text(
              norm!.code,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
