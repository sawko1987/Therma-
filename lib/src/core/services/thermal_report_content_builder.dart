import '../models/calculation.dart';
import '../models/catalog.dart';
import '../models/project.dart';
import '../models/report.dart';
import 'interfaces.dart';

class ThermalReportContentBuilder implements ReportContentBuilder {
  const ThermalReportContentBuilder();

  @override
  ReportContent buildContent({
    required CatalogSnapshot catalog,
    required Project project,
    required Construction construction,
    required CalculationResult calculation,
  }) {
    final climate = catalog.climatePoints.firstWhere(
      (item) => item.id == project.climatePointId,
    );
    final appliedNorms = catalog.norms
        .where((norm) => calculation.appliedNormReferenceIds.contains(norm.id))
        .map((norm) => '${norm.code} - ${norm.title}')
        .toList(growable: false);

    return ReportContent(
      title: 'Отчет thermocalc',
      projectName: project.name,
      climateLabel: climate.displayName,
      roomLabel: project.roomPreset.label,
      constructionTitle: construction.title,
      datasetVersion: catalog.datasetVersion,
      generatedAt: DateTime.now(),
      thermalMetrics: [
        ReportMetric(
          label: 'Статус сценария',
          value: calculation.scenarioStatus.label,
        ),
        ReportMetric(
          label: 'Фактическое R',
          value: '${_format2(calculation.totalResistance)} м2·°C/Вт',
        ),
        ReportMetric(
          label: 'Требуемое R',
          value: '${_format2(calculation.requiredResistance)} м2·°C/Вт',
        ),
        ReportMetric(
          label: 'Запас',
          value: '${_format2(calculation.resistanceMargin)} м2·°C/Вт',
        ),
        ReportMetric(
          label: 'Условия',
          value:
              '${_format0(calculation.insideAirTemperature)} / ${_format0(calculation.outsideAirTemperature)} °C',
        ),
      ],
      thermalIndicators: calculation.complianceIndicators
          .map(
            (indicator) => ReportIndicatorEntry(
              title: indicator.title,
              value: _formatIndicator(indicator),
              normCode: _findNormCode(catalog, indicator.normReferenceId),
              isPassed: indicator.isPassed,
            ),
          )
          .toList(growable: false),
      moistureSummary: calculation.scenarioStatus.isDirectlySupported
          ? calculation.moistureCheck.summary
          : calculation.scenarioMessage,
      moistureMetrics: calculation.scenarioStatus.isDirectlySupported
          ? [
        ReportMetric(
          label: 'Общее паросопротивление',
          value:
              '${_format2(calculation.moistureCheck.totalVaporResistance)} м2·ч·Па/мг',
        ),
        ReportMetric(
          label: 'Минимум для помещения',
          value:
              '${_format2(calculation.moistureCheck.minimumRecommendedVaporResistance)} м2·ч·Па/мг',
        ),
        ReportMetric(
          label: 'Критический сезон',
          value: calculation.moistureCheck.criticalSeasonLabel,
        ),
        ReportMetric(
          label: 'Итог',
          value: calculation.moistureCheck.verdict.label,
        ),
        ReportMetric(
          label: 'Финальное накопление',
          value:
              '${_format3(calculation.moistureCheck.finalAccumulationKgPerSquareMeter)} кг/м2',
        ),
        ReportMetric(
          label: 'Допустимый максимум',
          value:
              '${_format3(calculation.moistureCheck.maximumAllowedAccumulationKgPerSquareMeter)} кг/м2',
        ),
      ]
          : const [],
      moistureIndicators: calculation.scenarioStatus.isDirectlySupported
          ? calculation.moistureCheck.indicators
          .map(
            (indicator) => ReportIndicatorEntry(
              title: indicator.title,
              value: _formatIndicator(indicator),
              normCode: _findNormCode(catalog, indicator.normReferenceId),
              isPassed: indicator.isPassed,
            ),
          )
          .toList(growable: false)
          : const [],
      thermalLayerRows: calculation.scenarioStatus.isDirectlySupported
          ? calculation.layerRows
          .map(
            (row) => ReportRowEntry(
              title: row.title,
              details:
                  '${_format0(row.thicknessMm)} мм, λ ${_format3(row.thermalConductivity)}, R ${_format2(row.resistance)}',
              trailing:
                  '${_format1(row.tempStart)} -> ${_format1(row.tempEnd)} °C',
            ),
          )
          .toList(growable: false)
          : const [],
      vaporLayerRows: calculation.scenarioStatus.isDirectlySupported
          ? calculation.moistureCheck.layerRows
          .map(
            (row) => ReportRowEntry(
              title: row.title,
              details:
                  '${_format0(row.thicknessMm)} мм, δ ${_format2(row.vaporPermeability)}, Z ${_format2(row.vaporResistance)}',
              trailing: 'Σ ${_format2(row.cumulativeVaporResistance)}',
            ),
          )
          .toList(growable: false)
          : const [],
      seasonalRows: calculation.scenarioStatus.isDirectlySupported
          ? calculation.moistureCheck.seasonalPeriods
          .map(
            (period) => ReportRowEntry(
              title: period.label,
              details:
                  '${period.durationDays} дн., tнар ${_format0(period.outsideTemperature)} °C, φнар ${_format0(period.outsideRelativeHumidity * 100)}%, конденсация ${_format3(period.condensateKgPerSquareMeter)} кг/м2, высыхание ${_format3(period.dryingPotentialKgPerSquareMeter)} кг/м2',
              trailing: 'Σ ${_format3(period.endAccumulationKgPerSquareMeter)}',
            ),
          )
          .toList(growable: false)
          : const [],
      appliedNorms: appliedNorms,
    );
  }

  String _findNormCode(CatalogSnapshot catalog, String normReferenceId) {
    for (final norm in catalog.norms) {
      if (norm.id == normReferenceId) {
        return norm.code;
      }
    }
    return 'Без ссылки';
  }

  String _formatIndicator(ComplianceIndicator indicator) {
    final actual = _format2(indicator.actual);
    final target = _format2(indicator.target);
    if (indicator.unit == 'ratio') {
      return '$actual / $target';
    }
    return '$actual / $target ${indicator.unit}';
  }

  String _format0(double value) => value.toStringAsFixed(0);
  String _format1(double value) => value.toStringAsFixed(1);
  String _format2(double value) => value.toStringAsFixed(2);
  String _format3(double value) => value.toStringAsFixed(3);
}
