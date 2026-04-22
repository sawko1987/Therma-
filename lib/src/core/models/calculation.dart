import 'dart:math';

enum CalculationScenarioStatus { supported, routedToGroundFloor, unsupported }

extension CalculationScenarioStatusX on CalculationScenarioStatus {
  String get label => switch (this) {
    CalculationScenarioStatus.supported => 'Поддерживается',
    CalculationScenarioStatus.routedToGroundFloor => 'Через полы по грунту',
    CalculationScenarioStatus.unsupported => 'Сценарий не поддержан',
  };

  bool get isDirectlySupported =>
      this == CalculationScenarioStatus.supported;
}

class LayerCalculationRow {
  const LayerCalculationRow({
    required this.title,
    required this.thicknessMm,
    required this.thermalConductivity,
    required this.resistance,
    required this.tempStart,
    required this.tempEnd,
  });

  final String title;
  final double thicknessMm;
  final double thermalConductivity;
  final double resistance;
  final double tempStart;
  final double tempEnd;
}

class MoistureLayerCalculationRow {
  const MoistureLayerCalculationRow({
    required this.title,
    required this.thicknessMm,
    required this.vaporPermeability,
    required this.vaporResistance,
    required this.cumulativeVaporResistance,
  });

  final String title;
  final double thicknessMm;
  final double vaporPermeability;
  final double vaporResistance;
  final double cumulativeVaporResistance;
}

class GraphSeries {
  const GraphSeries({required this.title, required this.points});

  final String title;
  final List<Point<double>> points;
}

class ComplianceIndicator {
  const ComplianceIndicator({
    required this.title,
    required this.actual,
    required this.target,
    required this.unit,
    required this.isPassed,
    required this.normReferenceId,
  });

  final String title;
  final double actual;
  final double target;
  final String unit;
  final bool isPassed;
  final String normReferenceId;
}

enum ScreeningLevel { low, medium, high }

extension ScreeningLevelX on ScreeningLevel {
  String get label => switch (this) {
    ScreeningLevel.low => 'Низкий риск',
    ScreeningLevel.medium => 'Умеренный риск',
    ScreeningLevel.high => 'Повышенный риск',
  };
}

enum SeasonalMoistureVerdict { pass, recoveryRequired, fail }

extension SeasonalMoistureVerdictX on SeasonalMoistureVerdict {
  String get label => switch (this) {
    SeasonalMoistureVerdict.pass => 'Сезон устойчив',
    SeasonalMoistureVerdict.recoveryRequired => 'Нужна проверка узла',
    SeasonalMoistureVerdict.fail => 'Есть риск влагонакопления',
  };
}

class SeasonalMoisturePeriodResult {
  const SeasonalMoisturePeriodResult({
    required this.label,
    required this.durationDays,
    required this.outsideTemperature,
    required this.outsideRelativeHumidity,
    required this.maxExcessPressure,
    required this.condensateKgPerSquareMeter,
    required this.dryingPotentialKgPerSquareMeter,
    required this.endAccumulationKgPerSquareMeter,
    required this.hasInterstitialCondensation,
  });

  final String label;
  final int durationDays;
  final double outsideTemperature;
  final double outsideRelativeHumidity;
  final double maxExcessPressure;
  final double condensateKgPerSquareMeter;
  final double dryingPotentialKgPerSquareMeter;
  final double endAccumulationKgPerSquareMeter;
  final bool hasInterstitialCondensation;
}

class MoistureCheckResult {
  const MoistureCheckResult({
    required this.totalVaporResistance,
    required this.minimumRecommendedVaporResistance,
    required this.outwardDryingRatio,
    required this.maximumRecommendedOutwardDryingRatio,
    required this.layerRows,
    required this.vaporResistanceSeries,
    required this.indicators,
    required this.level,
    required this.summary,
    required this.criticalSeasonLabel,
    required this.partialPressureSeries,
    required this.saturationPressureSeries,
    required this.condensationInterfaceTitles,
    required this.seasonalPeriods,
    required this.finalAccumulationKgPerSquareMeter,
    required this.maximumAllowedAccumulationKgPerSquareMeter,
    required this.verdict,
  });

  final double totalVaporResistance;
  final double minimumRecommendedVaporResistance;
  final double outwardDryingRatio;
  final double maximumRecommendedOutwardDryingRatio;
  final List<MoistureLayerCalculationRow> layerRows;
  final GraphSeries vaporResistanceSeries;
  final List<ComplianceIndicator> indicators;
  final ScreeningLevel level;
  final String summary;
  final String criticalSeasonLabel;
  final GraphSeries partialPressureSeries;
  final GraphSeries saturationPressureSeries;
  final List<String> condensationInterfaceTitles;
  final List<SeasonalMoisturePeriodResult> seasonalPeriods;
  final double finalAccumulationKgPerSquareMeter;
  final double maximumAllowedAccumulationKgPerSquareMeter;
  final SeasonalMoistureVerdict verdict;
}

class CalculationResult {
  const CalculationResult({
    required this.scenarioStatus,
    required this.scenarioMessage,
    required this.insideAirTemperature,
    required this.outsideAirTemperature,
    required this.insideSurfaceTemperature,
    required this.outsideSurfaceTemperature,
    required this.totalResistance,
    required this.requiredResistance,
    required this.layerRows,
    required this.temperatureSeries,
    required this.moistureCheck,
    required this.complianceIndicators,
    required this.appliedNormReferenceIds,
  });

  final CalculationScenarioStatus scenarioStatus;
  final String scenarioMessage;
  final double insideAirTemperature;
  final double outsideAirTemperature;
  final double insideSurfaceTemperature;
  final double outsideSurfaceTemperature;
  final double totalResistance;
  final double requiredResistance;
  final List<LayerCalculationRow> layerRows;
  final GraphSeries temperatureSeries;
  final MoistureCheckResult moistureCheck;
  final List<ComplianceIndicator> complianceIndicators;
  final List<String> appliedNormReferenceIds;

  double get resistanceMargin => totalResistance - requiredResistance;
}
