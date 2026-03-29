import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/ground_floor_calculation.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/services/ground_floor_calculation_service.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';

import 'support/fakes.dart';

void main() {
  Construction buildFloorConstruction() {
    return Construction(
      id: 'floor',
      title: 'Пол по грунту',
      elementKind: ConstructionElementKind.floor,
      floorConstructionType: FloorConstructionType.onGround,
      layers: buildWallConstruction().layers,
    );
  }

  test(
    'ground floor v1 adds equivalent ground resistance and heat loss',
    () async {
      final floor = buildFloorConstruction();
      final project = buildTestProject(
        constructions: [floor],
        groundFloorCalculations: const [
          GroundFloorCalculation(
            id: 'gf',
            title: 'Пол',
            kind: GroundFloorCalculationKind.slabOnGround,
            constructionId: 'floor',
            areaSquareMeters: 36,
            perimeterMeters: 24,
            slabWidthMeters: 6,
            slabLengthMeters: 6,
            edgeInsulationWidthMeters: 0.6,
            edgeInsulationResistance: 1.5,
          ),
        ],
      );
      const service = NormativeGroundFloorCalculationService(
        NormativeThermalCalculationEngine(),
      );

      final result = await service.calculate(
        catalog: testCatalogSnapshot,
        project: project,
        calculation: project.groundFloorCalculations.single,
      );

      expect(result.isSupported, isTrue);
      expect(result.equivalentGroundResistance, closeTo(2.01, 0.02));
      expect(
        result.totalResistance,
        greaterThan(result.constructionResistance),
      );
      expect(result.heatLossWatts, closeTo(218, 3));
      expect(result.passesResistanceCheck, isTrue);
    },
  );

  test('unsupported ground floor kind reports planned status', () async {
    final floor = buildFloorConstruction();
    final project = buildTestProject(constructions: [floor]);
    const service = NormativeGroundFloorCalculationService(
      NormativeThermalCalculationEngine(),
    );

    final result = await service.calculate(
      catalog: testCatalogSnapshot,
      project: project,
      calculation: const GroundFloorCalculation(
        id: 'future',
        title: 'Будущий сценарий',
        kind: GroundFloorCalculationKind.basementSlab,
        constructionId: 'floor',
        areaSquareMeters: 30,
        perimeterMeters: 22,
        slabWidthMeters: 5,
        slabLengthMeters: 6,
        edgeInsulationWidthMeters: 0.4,
        edgeInsulationResistance: 1.0,
      ),
    );

    expect(result.isSupported, isFalse);
    expect(result.statusMessage, contains('запланирован'));
  });
}
