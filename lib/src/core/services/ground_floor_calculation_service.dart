import '../models/catalog.dart';
import '../models/calculation.dart';
import '../models/ground_floor_calculation.dart';
import '../models/project.dart';
import 'interfaces.dart';

class NormativeGroundFloorCalculationService
    implements GroundFloorCalculationService {
  const NormativeGroundFloorCalculationService(this._engine);

  final ThermalCalculationEngine _engine;

  @override
  Future<GroundFloorCalculationResult> calculate({
    required CatalogSnapshot catalog,
    required Project project,
    required GroundFloorCalculation calculation,
  }) async {
    final construction = project.constructions.firstWhere(
      (item) => item.id == calculation.constructionId,
      orElse: () => throw StateError(
        'Construction ${calculation.constructionId} is missing from the project.',
      ),
    );
    final baseCalculation = await _engine.calculate(
      catalog: catalog,
      project: project,
      construction: construction,
    );

    if (construction.elementKind != ConstructionElementKind.floor) {
      return _unsupportedResult(
        calculation: calculation,
        baseCalculation: baseCalculation,
        statusMessage:
            'Для модуля полов нужен выбор конструкции типа "Пол".',
      );
    }

    _validateInput(calculation);

    final floorType = construction.floorConstructionType;
    if (!_supportsKindForFloorType(calculation.kind, floorType)) {
      return _unsupportedResult(
        calculation: calculation,
        baseCalculation: baseCalculation,
        statusMessage: _unsupportedCombinationMessage(
          kind: calculation.kind,
          floorType: floorType,
        ),
      );
    }

    final equivalentGroundResistance = switch (calculation.kind) {
      GroundFloorCalculationKind.slabOnGround =>
        _calculateSlabOnGroundResistance(calculation),
      GroundFloorCalculationKind.stripFoundationFloor =>
        _calculateStripFoundationResistance(calculation),
      GroundFloorCalculationKind.basementSlab => 0.0,
    };
    final totalResistance = baseCalculation.totalResistance +
        equivalentGroundResistance;
    final deltaTemperature =
        baseCalculation.insideAirTemperature -
        baseCalculation.outsideAirTemperature;
    final heatLossWatts =
        deltaTemperature / totalResistance * calculation.areaSquareMeters;

    return GroundFloorCalculationResult(
      calculation: calculation,
      isSupported: true,
      statusMessage: _supportedScenarioMessage(calculation.kind),
      insideAirTemperature: baseCalculation.insideAirTemperature,
      outsideAirTemperature: baseCalculation.outsideAirTemperature,
      deltaTemperature: deltaTemperature,
      requiredResistance: baseCalculation.requiredResistance,
      constructionResistance: baseCalculation.totalResistance,
      equivalentGroundResistance: equivalentGroundResistance,
      totalResistance: totalResistance,
      heatTransferCoefficient: 1 / totalResistance,
      heatLossWatts: heatLossWatts,
      specificHeatLossWattsPerSquareMeter:
          heatLossWatts / calculation.areaSquareMeters,
      shapeFactor: calculation.shapeFactor,
      appliedNormReferenceIds: baseCalculation.appliedNormReferenceIds,
    );
  }

  GroundFloorCalculationResult _unsupportedResult({
    required GroundFloorCalculation calculation,
    required CalculationResult baseCalculation,
    required String statusMessage,
  }) {
    return GroundFloorCalculationResult(
      calculation: calculation,
      isSupported: false,
      statusMessage: statusMessage,
      insideAirTemperature: baseCalculation.insideAirTemperature,
      outsideAirTemperature: baseCalculation.outsideAirTemperature,
      deltaTemperature:
          baseCalculation.insideAirTemperature -
          baseCalculation.outsideAirTemperature,
      requiredResistance: baseCalculation.requiredResistance,
      constructionResistance: baseCalculation.totalResistance,
      equivalentGroundResistance: 0,
      totalResistance: baseCalculation.totalResistance,
      heatTransferCoefficient: 1 / baseCalculation.totalResistance,
      heatLossWatts: 0,
      specificHeatLossWattsPerSquareMeter: 0,
      shapeFactor: calculation.shapeFactor,
      appliedNormReferenceIds: baseCalculation.appliedNormReferenceIds,
    );
  }

  void _validateInput(GroundFloorCalculation calculation) {
    if (calculation.areaSquareMeters <= 0) {
      throw StateError('Площадь пола должна быть больше нуля.');
    }
    if (calculation.perimeterMeters <= 0) {
      throw StateError('Периметр пола должен быть больше нуля.');
    }
    if (calculation.slabWidthMeters <= 0 || calculation.slabLengthMeters <= 0) {
      throw StateError('Габариты плиты должны быть больше нуля.');
    }
    if (calculation.edgeInsulationWidthMeters < 0 ||
        calculation.edgeInsulationResistance < 0) {
      throw StateError(
        'Параметры утепления кромки не могут быть отрицательными.',
      );
    }
    if ((calculation.foundationDepthMeters ?? 0) < 0 ||
        (calculation.foundationWidthMeters ?? 0) < 0) {
      throw StateError(
        'Параметры фундамента не могут быть отрицательными.',
      );
    }
  }

  bool _supportsKindForFloorType(
    GroundFloorCalculationKind kind,
    FloorConstructionType? floorType,
  ) {
    return switch (kind) {
      GroundFloorCalculationKind.slabOnGround ||
      GroundFloorCalculationKind.stripFoundationFloor =>
        floorType == FloorConstructionType.onGround,
      GroundFloorCalculationKind.basementSlab =>
        floorType == FloorConstructionType.overBasement,
    };
  }

  String _unsupportedCombinationMessage({
    required GroundFloorCalculationKind kind,
    required FloorConstructionType? floorType,
  }) {
    return switch (kind) {
      GroundFloorCalculationKind.slabOnGround ||
      GroundFloorCalculationKind.stripFoundationFloor =>
        'Для сценария "${kind.label}" нужна конструкция с типом "Пол по грунту".',
      GroundFloorCalculationKind.basementSlab =>
        'Для сценария "${kind.label}" нужна конструкция с типом "Пол над подвалом".',
    };
  }

  String _supportedScenarioMessage(GroundFloorCalculationKind kind) {
    return switch (kind) {
      GroundFloorCalculationKind.slabOnGround =>
        'Сценарий считает плиту по грунту как слоистую конструкцию с добавочным эквивалентным сопротивлением грунта и утепленной кромки.',
      GroundFloorCalculationKind.stripFoundationFloor =>
        'Сценарий считает пол по грунту на ленте как слоистую конструкцию с поправкой на периметр, утепленную кромку и более выраженную краевую зону.',
      GroundFloorCalculationKind.basementSlab =>
        'Сценарий считает плиту над подвалом через нормативный floor-расчет перекрытия над неотапливаемым подвалом без добавочного сопротивления грунта.',
    };
  }

  double _calculateSlabOnGroundResistance(
    GroundFloorCalculation calculation,
  ) {
    final characteristicSize =
        calculation.areaSquareMeters / calculation.perimeterMeters;
    final geometryTerm = 1.15 + characteristicSize * 0.18;
    final edgeWidthBonus = calculation.edgeInsulationWidthMeters * 0.35;
    final edgeResistanceBonus = calculation.edgeInsulationResistance * 0.25;
    return geometryTerm + edgeWidthBonus + edgeResistanceBonus;
  }

  double _calculateStripFoundationResistance(
    GroundFloorCalculation calculation,
  ) {
    final characteristicSize =
        calculation.areaSquareMeters / calculation.perimeterMeters;
    final foundationDepthMeters = calculation.foundationDepthMeters ?? 0.5;
    final geometryFactor =
        1.05 + characteristicSize * 0.20 + foundationDepthMeters * 0.15;
    final edgeBonus =
        calculation.edgeInsulationWidthMeters * 0.30 +
        calculation.edgeInsulationResistance * 0.22;
    return geometryFactor + edgeBonus;
  }
}
