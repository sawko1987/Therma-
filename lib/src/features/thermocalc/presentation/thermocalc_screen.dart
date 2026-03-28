import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/calculation.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import 'widgets/line_chart_painter.dart';
import 'widgets/section_painter.dart';

class ThermocalcScreen extends ConsumerWidget {
  const ThermocalcScreen({
    super.key,
    this.constructionId,
    this.showElementContext = true,
  });

  final String? constructionId;
  final bool showElementContext;

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    try {
      final savedReport = await ref
          .read(reportExportControllerProvider.notifier)
          .exportCurrentCalculation();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF сохранен: ${savedReport.fileName}\n${savedReport.filePath}',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать PDF: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final constructionAsync = switch (constructionId) {
      final String id => ref.watch(constructionByIdProvider(id)),
      null => ref.watch(selectedConstructionProvider),
    };
    final elementAsync = showElementContext
        ? ref.watch(selectedEnvelopeElementProvider)
        : const AsyncData<HouseEnvelopeElement?>(null);
    final calculationAsync = switch (constructionId) {
      final String id => ref.watch(calculationResultForConstructionProvider(id)),
      null => ref.watch(calculationResultProvider),
    };
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final reportExportAsync = ref.watch(reportExportControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thermocalc',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: reportExportAsync.isLoading
                ? null
                : () => _handleExport(context, ref),
            tooltip: 'Экспорт PDF',
            icon: reportExportAsync.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const _StatusBanner(),
          const SizedBox(height: 16),
          _ProjectSummary(
            projectAsync: projectAsync,
            constructionAsync: constructionAsync,
            elementAsync: elementAsync,
            catalogAsync: catalogAsync,
            showElementContext: showElementContext,
          ),
          const SizedBox(height: 16),
          calculationAsync.when(
            data: (calculation) => constructionAsync.when(
              data: (construction) => catalogAsync.when(
                data: (catalog) {
                  if (calculation == null || construction == null) {
                    return const Text('Недостаточно данных для расчёта.');
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
            error: (error, _) => Text('Ошибка расчёта: $error'),
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
          'Экран использует теплотехнический расчёт v1 и сезонный расчёт влагорежима: сопротивление теплопередаче, температурный профиль, послойное паросопротивление, критический сезон, график парциального давления и итог по влагонакоплению.',
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
    required this.elementAsync,
    required this.catalogAsync,
    required this.showElementContext,
  });

  final AsyncValue<Project?> projectAsync;
  final AsyncValue<Construction?> constructionAsync;
  final AsyncValue<HouseEnvelopeElement?> elementAsync;
  final AsyncValue<CatalogSnapshot> catalogAsync;
  final bool showElementContext;

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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            projectAsync.when(
              data: (project) => constructionAsync.when(
                data: (construction) => elementAsync.when(
                  data: (element) => catalogAsync.when(
                    data: (catalog) {
                      final climate = project == null
                          ? null
                          : catalog.climatePoints.firstWhere(
                              (item) => item.id == project.climatePointId,
                            );
                      final room = project?.houseModel.rooms.firstWhere(
                        (item) => item.id == element?.roomId,
                        orElse: () => Room.defaultRoom(),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(project?.name ?? 'Нет проекта'),
                          const SizedBox(height: 6),
                          Text('Климат: ${climate?.displayName ?? '—'}'),
                          Text('Помещение для норм: ${project?.roomPreset.label ?? '—'}'),
                          if (showElementContext)
                            Text('Ограждение: ${element?.title ?? '—'}'),
                          if (showElementContext)
                            Text('Комната: ${room?.title ?? '—'}'),
                          Text('Конструкция: ${construction?.title ?? '—'}'),
                          if (project?.datasetMigrationLabel
                              case final migrationLabel?)
                            Text(migrationLabel),
                          if (climate != null)
                            Text(
                              'Сезоны влагорежима: ${climate.moistureSeasons.map((item) => item.label).join(', ')}',
                            ),
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Ошибка каталога: $error'),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Ошибка ограждения: $error'),
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
                              .where(
                                (norm) => norm.id == indicator.normReferenceId,
                              )
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
                  'Сезонный влагорежим',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                      label: 'Критический сезон',
                      value: calculation.moistureCheck.criticalSeasonLabel,
                    ),
                    _MetricTile(
                      label: 'Итог',
                      value: calculation.moistureCheck.verdict.label,
                    ),
                    _MetricTile(
                      label: 'Финальное накопление',
                      value:
                          '${calculation.moistureCheck.finalAccumulationKgPerSquareMeter.toStringAsFixed(3)} кг/м²',
                    ),
                    _MetricTile(
                      label: 'Допустимый максимум',
                      value:
                          '${calculation.moistureCheck.maximumAllowedAccumulationKgPerSquareMeter.toStringAsFixed(3)} кг/м²',
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
                              .where(
                                (norm) => norm.id == indicator.normReferenceId,
                              )
                              .firstOrNull,
                        ),
                      )
                      .toList(),
                ),
                if (calculation
                    .moistureCheck
                    .condensationInterfaceTitles
                    .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Критические границы: ${calculation.moistureCheck.condensationInterfaceTitles.join(', ')}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                  'Профиль парциального давления',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'Критический период: ${calculation.moistureCheck.criticalSeasonLabel}',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: CustomPaint(
                    painter: LineChartPainter(
                      lines: [
                        ChartLine(
                          series:
                              calculation.moistureCheck.partialPressureSeries,
                          color: const Color(0xFF8B5E34),
                        ),
                        ChartLine(
                          series: calculation
                              .moistureCheck
                              .saturationPressureSeries,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ],
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
                  'Сезонный баланс влаги',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...calculation.moistureCheck.seasonalPeriods.map(
                  (period) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                period.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${period.durationDays} дн., tнар ${period.outsideTemperature.toStringAsFixed(0)} °C, φнар ${(period.outsideRelativeHumidity * 100).toStringAsFixed(0)}%',
                              ),
                              Text(
                                'Конденсация ${period.condensateKgPerSquareMeter.toStringAsFixed(3)} кг/м², высыхание ${period.dryingPotentialKgPerSquareMeter.toStringAsFixed(3)} кг/м²',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Σ ${period.endAccumulationKgPerSquareMeter.toStringAsFixed(3)}',
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
                  'Профиль паросопротивления',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                      lines: [
                        ChartLine(
                          series:
                              calculation.moistureCheck.vaporResistanceSeries,
                          color: const Color(0xFF8B5E34),
                        ),
                      ],
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                      lines: [
                        ChartLine(
                          series: calculation.temperatureSeries,
                          color: const Color(0xFF006D77),
                        ),
                      ],
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
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
                  'Послойный расчёт',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
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
                  'Применённые нормы',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
  const _MetricTile({required this.label, required this.value});

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
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  const _IndicatorTile({required this.indicator, required this.norm});

  final ComplianceIndicator indicator;
  final NormReference? norm;

  @override
  Widget build(BuildContext context) {
    final color = indicator.isPassed
        ? const Color(0xFF0F766E)
        : const Color(0xFFB45309);

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
            Text(norm!.code, style: Theme.of(context).textTheme.bodySmall),
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
