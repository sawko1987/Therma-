import 'dart:math';

import '../models/calculation.dart';
import '../models/catalog.dart';
import '../models/project.dart';
import 'interfaces.dart';

class NormativeThermalCalculationEngine implements ThermalCalculationEngine {
  const NormativeThermalCalculationEngine();

  static const _sp50Id = 'sp_50';
  static const _sp131Id = 'sp_131';
  static const _gost54851Id = 'gost_54851';

  @override
  Future<CalculationResult> calculate({
    required CatalogSnapshot catalog,
    required Project project,
    required Construction construction,
  }) async {
    final climate = catalog.climatePoints.firstWhere(
      (point) => point.id == project.climatePointId,
      orElse: () => throw StateError(
        'Climate point ${project.climatePointId} is missing from the catalog.',
      ),
    );
    if (climate.moistureSeasons.isEmpty) {
      throw StateError(
        'Climate point ${project.climatePointId} has no moisture seasons.',
      );
    }

    final enabledLayers = construction.layers
        .where((layer) => layer.enabled)
        .toList(growable: false);
    if (enabledLayers.isEmpty) {
      throw StateError(
        'Construction ${construction.id} has no enabled layers.',
      );
    }

    final materials = {
      for (final material in catalog.materials) material.id: material,
    };
    final breakdown = enabledLayers
        .map((layer) => _buildLayerBreakdown(layer, materials))
        .toList(growable: false);
    final roomCondition = _resolveRoomCondition(
      catalog.moistureRules,
      project.roomPreset,
    );
    final boundary = _resolveSurfaceResistances(construction.elementKind);
    final insideAirTemperature = roomCondition.insideTemperature;
    final outsideAirTemperature = climate.designTemperature;
    final totalLayerResistance = breakdown.fold<double>(
      0,
      (sum, item) => sum + item.resistance,
    );
    final totalResistance =
        boundary.inside + totalLayerResistance + boundary.outside;
    final requiredResistance = _resolveRequiredResistance(
      gsop: climate.gsop,
      elementKind: construction.elementKind,
    );
    final deltaTemperature = insideAirTemperature - outsideAirTemperature;
    final insideSurfaceTemperature =
        insideAirTemperature -
        deltaTemperature * (boundary.inside / totalResistance);
    final outsideSurfaceTemperature =
        insideAirTemperature -
        deltaTemperature *
            ((totalResistance - boundary.outside) / totalResistance);

    final layerRows = <LayerCalculationRow>[];
    var currentResistance = boundary.inside;
    for (final item in breakdown) {
      final tempStart =
          insideAirTemperature -
          deltaTemperature * (currentResistance / totalResistance);
      currentResistance += item.resistance;
      final tempEnd =
          insideAirTemperature -
          deltaTemperature * (currentResistance / totalResistance);
      layerRows.add(
        LayerCalculationRow(
          title: item.material.name,
          thicknessMm: item.layer.thicknessMm,
          thermalConductivity: item.material.thermalConductivity,
          resistance: item.resistance,
          tempStart: tempStart,
          tempEnd: tempEnd,
        ),
      );
    }

    final moistureCheck = _buildMoistureCheck(
      climate: climate,
      project: project,
      breakdown: breakdown,
      roomCondition: roomCondition,
      rules: catalog.moistureRules,
      boundary: boundary,
      totalResistance: totalResistance,
    );

    final appliedNormReferenceIds = catalog.norms
        .map((norm) => norm.id)
        .where((id) => id == _sp50Id || id == _sp131Id || id == _gost54851Id)
        .toList(growable: false);

    return CalculationResult(
      insideAirTemperature: insideAirTemperature,
      outsideAirTemperature: outsideAirTemperature,
      insideSurfaceTemperature: insideSurfaceTemperature,
      outsideSurfaceTemperature: outsideSurfaceTemperature,
      totalResistance: totalResistance,
      requiredResistance: requiredResistance,
      layerRows: layerRows,
      temperatureSeries: GraphSeries(
        title: 'Температурный профиль',
        points: _buildTemperaturePoints(
          insideAirTemperature: insideAirTemperature,
          outsideAirTemperature: outsideAirTemperature,
          totalResistance: totalResistance,
          boundary: boundary,
          breakdown: breakdown,
        ),
      ),
      moistureCheck: moistureCheck,
      complianceIndicators: [
        ComplianceIndicator(
          title: 'Требуемое сопротивление',
          actual: totalResistance,
          target: requiredResistance,
          unit: 'м²·°C/Вт',
          isPassed: totalResistance >= requiredResistance,
          normReferenceId: _sp50Id,
        ),
      ],
      appliedNormReferenceIds: appliedNormReferenceIds,
    );
  }

  MoistureCheckResult _buildMoistureCheck({
    required ClimatePoint climate,
    required Project project,
    required List<_LayerBreakdown> breakdown,
    required MoistureRoomCondition roomCondition,
    required MoistureRuleSet rules,
    required _SurfaceResistances boundary,
    required double totalResistance,
  }) {
    final layerRows = <MoistureLayerCalculationRow>[];
    final vaporPoints = <Point<double>>[const Point(0, 0)];
    var totalVaporResistance = 0.0;
    var totalThickness = 0.0;

    for (final item in breakdown) {
      totalVaporResistance += item.vaporResistance;
      totalThickness += item.layer.thicknessMm;
      layerRows.add(
        MoistureLayerCalculationRow(
          title: item.material.name,
          thicknessMm: item.layer.thicknessMm,
          vaporPermeability: item.material.vaporPermeability,
          vaporResistance: item.vaporResistance,
          cumulativeVaporResistance: totalVaporResistance,
        ),
      );
      vaporPoints.add(Point(totalThickness, totalVaporResistance));
    }

    final minimumRecommendedVaporResistance =
        roomCondition.minimumRecommendedVaporResistance;
    final maximumRecommendedOutwardDryingRatio =
        _resolveMaximumOutwardDryingRatio(climate, rules);
    final firstLayerResistance = layerRows.first.vaporResistance;
    final lastLayerResistance = layerRows.last.vaporResistance;
    final outwardDryingRatio = lastLayerResistance / firstLayerResistance;

    var accumulatedMoisture = 0.0;
    _SeasonEvaluation? criticalSeason;
    final seasonalResults = <SeasonalMoisturePeriodResult>[];

    for (final season in climate.moistureSeasons) {
      final evaluation = _evaluateSeason(
        season: season,
        roomCondition: roomCondition,
        breakdown: breakdown,
        totalResistance: totalResistance,
        boundary: boundary,
        totalVaporResistance: totalVaporResistance,
        dryingRecoveryFactor: rules.seasonalDryingRecoveryFactor,
        carriedAccumulationKgPerSquareMeter: accumulatedMoisture,
      );
      accumulatedMoisture = evaluation.endAccumulationKgPerSquareMeter;
      seasonalResults.add(evaluation.result);
      if (criticalSeason == null ||
          evaluation.maxExcessPressure > criticalSeason.maxExcessPressure) {
        criticalSeason = evaluation;
      }
    }

    final verdict = _resolveSeasonalVerdict(
      finalAccumulationKgPerSquareMeter: accumulatedMoisture,
      maximumAllowedAccumulationKgPerSquareMeter:
          rules.maximumSeasonalAccumulationKgPerSquareMeter,
      hasCondensation: seasonalResults.any(
        (item) => item.hasInterstitialCondensation,
      ),
    );
    final indicators = [
      ComplianceIndicator(
        title: 'Паросопротивление конструкции',
        actual: totalVaporResistance,
        target: minimumRecommendedVaporResistance,
        unit: 'м²·ч·Па/мг',
        isPassed: totalVaporResistance >= minimumRecommendedVaporResistance,
        normReferenceId: _sp50Id,
      ),
      ComplianceIndicator(
        title: 'Высыхание наружу',
        actual: outwardDryingRatio,
        target: maximumRecommendedOutwardDryingRatio,
        unit: 'ratio',
        isPassed: outwardDryingRatio <= maximumRecommendedOutwardDryingRatio,
        normReferenceId: _sp50Id,
      ),
      ComplianceIndicator(
        title: 'Итоговое влагонакопление',
        actual: accumulatedMoisture,
        target: rules.maximumSeasonalAccumulationKgPerSquareMeter,
        unit: 'кг/м²',
        isPassed:
            accumulatedMoisture <=
            rules.maximumSeasonalAccumulationKgPerSquareMeter,
        normReferenceId: _sp50Id,
      ),
    ];
    final failedIndicators = indicators.where(
      (indicator) => !indicator.isPassed,
    );
    final level = switch (failedIndicators.length) {
      0 => ScreeningLevel.low,
      1 => ScreeningLevel.medium,
      _ => ScreeningLevel.high,
    };
    final worstSeason = criticalSeason ?? _emptySeason(totalThickness);

    return MoistureCheckResult(
      totalVaporResistance: totalVaporResistance,
      minimumRecommendedVaporResistance: minimumRecommendedVaporResistance,
      outwardDryingRatio: outwardDryingRatio,
      maximumRecommendedOutwardDryingRatio:
          maximumRecommendedOutwardDryingRatio,
      layerRows: layerRows,
      vaporResistanceSeries: GraphSeries(
        title: 'Паросопротивление по слоям',
        points: vaporPoints,
      ),
      indicators: indicators,
      level: level,
      summary: _buildMoistureSummary(
        verdict: verdict,
        criticalSeasonLabel: worstSeason.result.label,
        condensationInterfaces: worstSeason.condensationInterfaceTitles,
      ),
      criticalSeasonLabel: worstSeason.result.label,
      partialPressureSeries: GraphSeries(
        title: 'Парциальное давление пара',
        points: worstSeason.partialPressurePoints,
      ),
      saturationPressureSeries: GraphSeries(
        title: 'Давление насыщения',
        points: worstSeason.saturationPressurePoints,
      ),
      condensationInterfaceTitles: worstSeason.condensationInterfaceTitles,
      seasonalPeriods: seasonalResults,
      finalAccumulationKgPerSquareMeter: accumulatedMoisture,
      maximumAllowedAccumulationKgPerSquareMeter:
          rules.maximumSeasonalAccumulationKgPerSquareMeter,
      verdict: verdict,
    );
  }

  _LayerBreakdown _buildLayerBreakdown(
    ConstructionLayer layer,
    Map<String, MaterialEntry> materials,
  ) {
    final material = materials[layer.materialId];
    if (material == null) {
      throw StateError(
        'Material ${layer.materialId} is missing from the catalog.',
      );
    }
    if (material.thermalConductivity <= 0) {
      throw StateError(
        'Material ${layer.materialId} has invalid thermal conductivity.',
      );
    }
    if (material.vaporPermeability <= 0) {
      throw StateError(
        'Material ${layer.materialId} has invalid vapor permeability.',
      );
    }
    if (layer.thicknessMm < 0) {
      throw StateError('Layer ${layer.id} has invalid thickness.');
    }

    return _LayerBreakdown(
      layer: layer,
      material: material,
      resistance: (layer.thicknessMm / 1000.0) / material.thermalConductivity,
      vaporResistance:
          (layer.thicknessMm / 1000.0) / material.vaporPermeability,
    );
  }

  MoistureRoomCondition _resolveRoomCondition(
    MoistureRuleSet rules,
    RoomPreset roomPreset,
  ) {
    return rules.roomConditions.firstWhere(
      (item) => item.roomPresetId == roomPreset.catalogId,
      orElse: () => throw StateError(
        'Room preset ${roomPreset.catalogId} is missing from moisture rules.',
      ),
    );
  }

  List<Point<double>> _buildTemperaturePoints({
    required double insideAirTemperature,
    required double outsideAirTemperature,
    required double totalResistance,
    required _SurfaceResistances boundary,
    required List<_LayerBreakdown> breakdown,
  }) {
    final deltaTemperature = insideAirTemperature - outsideAirTemperature;
    var currentResistance = boundary.inside;
    var currentThickness = 0.0;
    final points = <Point<double>>[
      Point(
        0,
        insideAirTemperature -
            deltaTemperature * (boundary.inside / totalResistance),
      ),
    ];

    for (final item in breakdown) {
      currentResistance += item.resistance;
      currentThickness += item.layer.thicknessMm;
      final temperature =
          insideAirTemperature -
          deltaTemperature * (currentResistance / totalResistance);
      points.add(Point(currentThickness, temperature));
    }

    return points;
  }

  _SeasonEvaluation _evaluateSeason({
    required ClimateSeason season,
    required MoistureRoomCondition roomCondition,
    required List<_LayerBreakdown> breakdown,
    required double totalResistance,
    required _SurfaceResistances boundary,
    required double totalVaporResistance,
    required double dryingRecoveryFactor,
    required double carriedAccumulationKgPerSquareMeter,
  }) {
    final insidePartialPressure =
        _saturationPressure(roomCondition.insideTemperature) *
        roomCondition.insideRelativeHumidity;
    final outsidePartialPressure =
        _saturationPressure(season.outsideTemperature) *
        season.outsideRelativeHumidity;
    final temperaturePoints = _buildTemperaturePoints(
      insideAirTemperature: roomCondition.insideTemperature,
      outsideAirTemperature: season.outsideTemperature,
      totalResistance: totalResistance,
      boundary: boundary,
      breakdown: breakdown,
    );

    var currentThickness = 0.0;
    var currentVaporResistance = 0.0;
    var maxExcessPressure = 0.0;
    var condensateKgPerSquareMeter = 0.0;
    final partialPressurePoints = <Point<double>>[
      Point(0, insidePartialPressure),
    ];
    final saturationPressurePoints = <Point<double>>[
      Point(0, _saturationPressure(temperaturePoints.first.y)),
    ];
    final condensationInterfaces = <String>[];

    for (var index = 0; index < breakdown.length; index++) {
      final item = breakdown[index];
      currentThickness += item.layer.thicknessMm;
      currentVaporResistance += item.vaporResistance;

      final partialPressure =
          insidePartialPressure -
          (insidePartialPressure - outsidePartialPressure) *
              (currentVaporResistance / totalVaporResistance);
      final saturationPressure = _saturationPressure(
        temperaturePoints[index + 1].y,
      );
      partialPressurePoints.add(Point(currentThickness, partialPressure));
      saturationPressurePoints.add(Point(currentThickness, saturationPressure));

      final excessPressure = max(0.0, partialPressure - saturationPressure);
      maxExcessPressure = max(maxExcessPressure, excessPressure);

      if (excessPressure > 0) {
        condensationInterfaces.add(item.material.name);
        final incomingFlux = max(
          0.0,
          (insidePartialPressure - saturationPressure) / currentVaporResistance,
        );
        final outerVaporResistance =
            totalVaporResistance - currentVaporResistance;
        final outgoingFlux = outerVaporResistance <= 0
            ? 0.0
            : max(
                0.0,
                (saturationPressure - outsidePartialPressure) /
                    outerVaporResistance,
              );
        final netFlux = max(0.0, incomingFlux - outgoingFlux);
        condensateKgPerSquareMeter +=
            netFlux * 24 * season.durationDays / 1000000.0;
      }
    }

    final dryingFlux = condensateKgPerSquareMeter == 0
        ? max(
            0.0,
            (insidePartialPressure - outsidePartialPressure) /
                totalVaporResistance,
          )
        : 0.0;
    final dryingPotentialKgPerSquareMeter =
        dryingFlux *
        24 *
        season.durationDays /
        1000000.0 *
        dryingRecoveryFactor;
    final endAccumulationKgPerSquareMeter = max(
      0.0,
      carriedAccumulationKgPerSquareMeter +
          condensateKgPerSquareMeter -
          dryingPotentialKgPerSquareMeter,
    );

    return _SeasonEvaluation(
      result: SeasonalMoisturePeriodResult(
        label: season.label,
        durationDays: season.durationDays,
        outsideTemperature: season.outsideTemperature,
        outsideRelativeHumidity: season.outsideRelativeHumidity,
        maxExcessPressure: maxExcessPressure,
        condensateKgPerSquareMeter: condensateKgPerSquareMeter,
        dryingPotentialKgPerSquareMeter: dryingPotentialKgPerSquareMeter,
        endAccumulationKgPerSquareMeter: endAccumulationKgPerSquareMeter,
        hasInterstitialCondensation: condensationInterfaces.isNotEmpty,
      ),
      partialPressurePoints: partialPressurePoints,
      saturationPressurePoints: saturationPressurePoints,
      condensationInterfaceTitles: condensationInterfaces,
      maxExcessPressure: maxExcessPressure,
      endAccumulationKgPerSquareMeter: endAccumulationKgPerSquareMeter,
    );
  }

  _SeasonEvaluation _emptySeason(double totalThickness) {
    return _SeasonEvaluation(
      result: const SeasonalMoisturePeriodResult(
        label: 'Без сезонных данных',
        durationDays: 0,
        outsideTemperature: 0,
        outsideRelativeHumidity: 0,
        maxExcessPressure: 0,
        condensateKgPerSquareMeter: 0,
        dryingPotentialKgPerSquareMeter: 0,
        endAccumulationKgPerSquareMeter: 0,
        hasInterstitialCondensation: false,
      ),
      partialPressurePoints: const [Point(0, 0), Point(1, 0)],
      saturationPressurePoints: const [Point(0, 0), Point(1, 0)],
      condensationInterfaceTitles: const [],
      maxExcessPressure: 0,
      endAccumulationKgPerSquareMeter: 0,
    );
  }

  SeasonalMoistureVerdict _resolveSeasonalVerdict({
    required double finalAccumulationKgPerSquareMeter,
    required double maximumAllowedAccumulationKgPerSquareMeter,
    required bool hasCondensation,
  }) {
    if (finalAccumulationKgPerSquareMeter >
        maximumAllowedAccumulationKgPerSquareMeter) {
      return SeasonalMoistureVerdict.fail;
    }
    if (hasCondensation || finalAccumulationKgPerSquareMeter > 0) {
      return SeasonalMoistureVerdict.recoveryRequired;
    }
    return SeasonalMoistureVerdict.pass;
  }

  double _saturationPressure(double temperatureCelsius) {
    if (temperatureCelsius >= 0) {
      return 610.5 *
          exp((17.269 * temperatureCelsius) / (237.3 + temperatureCelsius));
    }
    return 610.5 *
        exp((21.875 * temperatureCelsius) / (265.5 + temperatureCelsius));
  }

  _SurfaceResistances _resolveSurfaceResistances(
    ConstructionElementKind elementKind,
  ) {
    return switch (elementKind) {
      ConstructionElementKind.wall => const _SurfaceResistances(
        inside: 0.13,
        outside: 0.04,
      ),
      ConstructionElementKind.roof => const _SurfaceResistances(
        inside: 0.10,
        outside: 0.04,
      ),
      ConstructionElementKind.floor => const _SurfaceResistances(
        inside: 0.17,
        outside: 0.04,
      ),
      ConstructionElementKind.ceiling => const _SurfaceResistances(
        inside: 0.10,
        outside: 0.04,
      ),
    };
  }

  double _resolveRequiredResistance({
    required double gsop,
    required ConstructionElementKind elementKind,
  }) {
    final coefficients = switch (elementKind) {
      ConstructionElementKind.wall => const _RequirementCoefficients(
        slope: 0.00035,
        intercept: 1.65,
        minimum: 2.60,
      ),
      ConstructionElementKind.roof => const _RequirementCoefficients(
        slope: 0.00050,
        intercept: 2.20,
        minimum: 3.30,
      ),
      ConstructionElementKind.floor => const _RequirementCoefficients(
        slope: 0.00045,
        intercept: 1.90,
        minimum: 3.00,
      ),
      ConstructionElementKind.ceiling => const _RequirementCoefficients(
        slope: 0.00040,
        intercept: 1.80,
        minimum: 2.80,
      ),
    };

    return max(
      coefficients.minimum,
      coefficients.intercept + gsop * coefficients.slope,
    );
  }

  double _resolveMaximumOutwardDryingRatio(
    ClimatePoint climate,
    MoistureRuleSet rules,
  ) {
    return climate.designTemperature <=
            rules.coldClimateDesignTemperatureThreshold
        ? rules.coldClimateMaximumOutwardDryingRatio
        : rules.defaultMaximumOutwardDryingRatio;
  }

  String _buildMoistureSummary({
    required SeasonalMoistureVerdict verdict,
    required String criticalSeasonLabel,
    required List<String> condensationInterfaces,
  }) {
    final interfaces = condensationInterfaces.isEmpty
        ? 'без пересечения профилей давления'
        : condensationInterfaces.join(', ');
    return switch (verdict) {
      SeasonalMoistureVerdict.pass =>
        'Сезонный расчёт влагорежима не показывает устойчивого влагонакопления; критический период: $criticalSeasonLabel, $interfaces.',
      SeasonalMoistureVerdict.recoveryRequired =>
        'Сезонный расчёт показывает пограничный сценарий: в период "$criticalSeasonLabel" возможна конденсация на границах $interfaces, но сезонный баланс пока укладывается в допуск.',
      SeasonalMoistureVerdict.fail =>
        'Сезонный расчёт показывает риск влагонакопления: в период "$criticalSeasonLabel" конденсация на границах $interfaces не компенсируется высыханием.',
    };
  }
}

class _LayerBreakdown {
  const _LayerBreakdown({
    required this.layer,
    required this.material,
    required this.resistance,
    required this.vaporResistance,
  });

  final ConstructionLayer layer;
  final MaterialEntry material;
  final double resistance;
  final double vaporResistance;
}

class _SeasonEvaluation {
  const _SeasonEvaluation({
    required this.result,
    required this.partialPressurePoints,
    required this.saturationPressurePoints,
    required this.condensationInterfaceTitles,
    required this.maxExcessPressure,
    required this.endAccumulationKgPerSquareMeter,
  });

  final SeasonalMoisturePeriodResult result;
  final List<Point<double>> partialPressurePoints;
  final List<Point<double>> saturationPressurePoints;
  final List<String> condensationInterfaceTitles;
  final double maxExcessPressure;
  final double endAccumulationKgPerSquareMeter;
}

class _SurfaceResistances {
  const _SurfaceResistances({required this.inside, required this.outside});

  final double inside;
  final double outside;
}

class _RequirementCoefficients {
  const _RequirementCoefficients({
    required this.slope,
    required this.intercept,
    required this.minimum,
  });

  final double slope;
  final double intercept;
  final double minimum;
}
