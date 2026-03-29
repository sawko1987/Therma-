import '../models/catalog.dart';
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

    if (!calculation.kind.isSupportedInV1) {
      return GroundFloorCalculationResult(
        calculation: calculation,
        isSupported: false,
        statusMessage:
            'Сценарий ${calculation.kind.label} запланирован, но в v1 пока не реализован.',
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

    if (construction.elementKind != ConstructionElementKind.floor) {
      return GroundFloorCalculationResult(
        calculation: calculation,
        isSupported: false,
        statusMessage:
            'Для расчета пола по грунту v1 нужно выбрать конструкцию типа "Пол".',
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

    if (construction.floorConstructionType != FloorConstructionType.onGround) {
      return GroundFloorCalculationResult(
        calculation: calculation,
        isSupported: false,
        statusMessage:
            'Для модуля пола по грунту нужна конструкция с типом "Пол по грунту".',
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

    _validateInput(calculation);

    final equivalentGroundResistance = _calculateEquivalentGroundResistance(
      calculation,
    );
    final totalResistance =
        baseCalculation.totalResistance + equivalentGroundResistance;
    final deltaTemperature =
        baseCalculation.insideAirTemperature -
        baseCalculation.outsideAirTemperature;
    final heatLossWatts =
        deltaTemperature / totalResistance * calculation.areaSquareMeters;

    return GroundFloorCalculationResult(
      calculation: calculation,
      isSupported: true,
      statusMessage:
          'v1 считает плиту по грунту как слоистую конструкцию с добавочным эквивалентным сопротивлением грунта и утепленной кромки.',
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
  }

  double _calculateEquivalentGroundResistance(
    GroundFloorCalculation calculation,
  ) {
    final characteristicSize =
        calculation.areaSquareMeters / calculation.perimeterMeters;
    final geometryTerm = 1.15 + characteristicSize * 0.18;
    final edgeWidthBonus = calculation.edgeInsulationWidthMeters * 0.35;
    final edgeResistanceBonus = calculation.edgeInsulationResistance * 0.25;
    return geometryTerm + edgeWidthBonus + edgeResistanceBonus;
  }
}
