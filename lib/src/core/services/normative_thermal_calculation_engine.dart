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
    final enabledLayers = construction.layers
        .where((layer) => layer.enabled)
        .toList(growable: false);
    if (enabledLayers.isEmpty) {
      throw StateError('Construction ${construction.id} has no enabled layers.');
    }

    final materials = {
      for (final material in catalog.materials) material.id: material,
    };
    final boundary = _resolveSurfaceResistances(construction.elementKind);
    final insideAirTemperature = _resolveInsideAirTemperature(project.roomPreset);
    final outsideAirTemperature = climate.designTemperature;
    final totalLayerResistance = enabledLayers.fold<double>(
      0,
      (sum, layer) => sum + _resolveLayerResistance(layer, materials),
    );
    final totalResistance =
        boundary.inside + totalLayerResistance + boundary.outside;
    final requiredResistance = _resolveRequiredResistance(
      gsop: climate.gsop,
      elementKind: construction.elementKind,
    );
    final deltaTemperature = insideAirTemperature - outsideAirTemperature;
    final insideSurfaceTemperature = insideAirTemperature -
        deltaTemperature * (boundary.inside / totalResistance);
    final outsideSurfaceTemperature = insideAirTemperature -
        deltaTemperature * ((totalResistance - boundary.outside) / totalResistance);

    var currentResistance = boundary.inside;
    var currentThickness = 0.0;
    final layerRows = <LayerCalculationRow>[];
    final temperaturePoints = <Point<double>>[
      Point(0, insideSurfaceTemperature),
    ];

    for (final layer in enabledLayers) {
      final material = materials[layer.materialId];
      if (material == null) {
        throw StateError(
          'Material ${layer.materialId} is missing from the catalog.',
        );
      }

      final resistance = _resolveLayerResistance(layer, materials);
      final tempStart = insideAirTemperature -
          deltaTemperature * (currentResistance / totalResistance);
      currentResistance += resistance;
      final tempEnd = insideAirTemperature -
          deltaTemperature * (currentResistance / totalResistance);
      currentThickness += layer.thicknessMm;

      layerRows.add(
        LayerCalculationRow(
          title: material.name,
          thicknessMm: layer.thicknessMm,
          thermalConductivity: material.thermalConductivity,
          resistance: resistance,
          tempStart: tempStart,
          tempEnd: tempEnd,
        ),
      );
      temperaturePoints.add(Point(currentThickness, tempEnd));
    }

    final moistureCheck = _buildMoistureCheck(
      climate: climate,
      project: project,
      enabledLayers: enabledLayers,
      materials: materials,
    );

    final appliedNormReferenceIds = catalog.norms
        .map((norm) => norm.id)
        .where(
          (id) => id == _sp50Id || id == _sp131Id || id == _gost54851Id,
        )
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
        points: temperaturePoints,
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
    required List<ConstructionLayer> enabledLayers,
    required Map<String, MaterialEntry> materials,
  }) {
    var currentThickness = 0.0;
    var cumulativeVaporResistance = 0.0;
    final layerRows = <MoistureLayerCalculationRow>[];
    final points = <Point<double>>[const Point(0, 0)];

    for (final layer in enabledLayers) {
      final material = materials[layer.materialId];
      if (material == null) {
        throw StateError(
          'Material ${layer.materialId} is missing from the catalog.',
        );
      }

      final vaporResistance = _resolveLayerVaporResistance(layer, materials);
      currentThickness += layer.thicknessMm;
      cumulativeVaporResistance += vaporResistance;

      layerRows.add(
        MoistureLayerCalculationRow(
          title: material.name,
          thicknessMm: layer.thicknessMm,
          vaporPermeability: material.vaporPermeability,
          vaporResistance: vaporResistance,
          cumulativeVaporResistance: cumulativeVaporResistance,
        ),
      );
      points.add(Point(currentThickness, cumulativeVaporResistance));
    }

    final minimumRecommendedVaporResistance = _resolveMinimumVaporResistance(
      project.roomPreset,
    );
    final maximumRecommendedOutwardDryingRatio =
        _resolveMaximumOutwardDryingRatio(climate);
    final firstLayerResistance = layerRows.first.vaporResistance;
    final lastLayerResistance = layerRows.last.vaporResistance;
    final outwardDryingRatio = lastLayerResistance / firstLayerResistance;
    final indicators = [
      ComplianceIndicator(
        title: 'Паросопротивление конструкции',
        actual: cumulativeVaporResistance,
        target: minimumRecommendedVaporResistance,
        unit: 'м²·ч·Па/мг',
        isPassed: cumulativeVaporResistance >= minimumRecommendedVaporResistance,
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
    ];
    final failedIndicators = indicators.where((indicator) => !indicator.isPassed);
    final level = switch (failedIndicators.length) {
      0 => ScreeningLevel.low,
      1 => ScreeningLevel.medium,
      _ => ScreeningLevel.high,
    };

    return MoistureCheckResult(
      totalVaporResistance: cumulativeVaporResistance,
      minimumRecommendedVaporResistance: minimumRecommendedVaporResistance,
      outwardDryingRatio: outwardDryingRatio,
      maximumRecommendedOutwardDryingRatio: maximumRecommendedOutwardDryingRatio,
      layerRows: layerRows,
      vaporResistanceSeries: GraphSeries(
        title: 'Паросопротивление по слоям',
        points: points,
      ),
      indicators: indicators,
      level: level,
      summary: _buildMoistureSummary(level),
    );
  }

  double _resolveLayerResistance(
    ConstructionLayer layer,
    Map<String, MaterialEntry> materials,
  ) {
    final material = materials[layer.materialId];
    if (material == null) {
      throw StateError('Material ${layer.materialId} is missing from the catalog.');
    }
    if (material.thermalConductivity <= 0) {
      throw StateError(
        'Material ${layer.materialId} has invalid thermal conductivity.',
      );
    }
    if (layer.thicknessMm < 0) {
      throw StateError('Layer ${layer.id} has invalid thickness.');
    }
    return (layer.thicknessMm / 1000.0) / material.thermalConductivity;
  }

  double _resolveLayerVaporResistance(
    ConstructionLayer layer,
    Map<String, MaterialEntry> materials,
  ) {
    final material = materials[layer.materialId];
    if (material == null) {
      throw StateError('Material ${layer.materialId} is missing from the catalog.');
    }
    if (material.vaporPermeability <= 0) {
      throw StateError(
        'Material ${layer.materialId} has invalid vapor permeability.',
      );
    }
    if (layer.thicknessMm < 0) {
      throw StateError('Layer ${layer.id} has invalid thickness.');
    }
    return (layer.thicknessMm / 1000.0) / material.vaporPermeability;
  }

  double _resolveInsideAirTemperature(RoomPreset roomPreset) {
    return switch (roomPreset) {
      RoomPreset.livingRoom => 20.0,
      RoomPreset.attic => 18.0,
      RoomPreset.basement => 16.0,
    };
  }

  _SurfaceResistances _resolveSurfaceResistances(
    ConstructionElementKind elementKind,
  ) {
    return switch (elementKind) {
      ConstructionElementKind.wall => const _SurfaceResistances(inside: 0.13, outside: 0.04),
      ConstructionElementKind.roof => const _SurfaceResistances(inside: 0.10, outside: 0.04),
      ConstructionElementKind.floor => const _SurfaceResistances(inside: 0.17, outside: 0.04),
      ConstructionElementKind.ceiling => const _SurfaceResistances(inside: 0.10, outside: 0.04),
    };
  }

  double _resolveRequiredResistance({
    required double gsop,
    required ConstructionElementKind elementKind,
  }) {
    // v1 keeps the requirement formula explicit and deterministic until the
    // full normative lookup tables are introduced into the local dataset.
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

  double _resolveMinimumVaporResistance(RoomPreset roomPreset) {
    // MVP moisture screening uses explicit provisional thresholds until the
    // full condensation and seasonal moisture tables are added to the dataset.
    return switch (roomPreset) {
      RoomPreset.livingRoom => 1.80,
      RoomPreset.attic => 1.40,
      RoomPreset.basement => 1.20,
    };
  }

  double _resolveMaximumOutwardDryingRatio(ClimatePoint climate) {
    // Colder climates require a more vapor-open exterior in the MVP screen.
    return climate.designTemperature <= -30 ? 0.80 : 1.00;
  }

  String _buildMoistureSummary(ScreeningLevel level) {
    return switch (level) {
      ScreeningLevel.low =>
        'MVP-скрининг влагорежима не показывает явного риска по паропереносу.',
      ScreeningLevel.medium =>
        'MVP-скрининг влагорежима показывает пограничный сценарий и требует проверки узла.',
      ScreeningLevel.high =>
        'MVP-скрининг влагорежима показывает повышенный риск: нужна ручная инженерная проверка.',
    };
  }
}

class _SurfaceResistances {
  const _SurfaceResistances({
    required this.inside,
    required this.outside,
  });

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
