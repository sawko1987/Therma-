import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/calculation.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';

import 'support/fakes.dart';
import 'support/reference_cases.dart';

void main() {
  const engine = NormativeThermalCalculationEngine();

  group('reference cases', () {
    for (final referenceCase in referenceCases) {
      test('matches ${referenceCase.name}', () async {
        final construction = referenceCase.project.constructions.single;

        final result = await engine.calculate(
          catalog: testCatalogSnapshot,
          project: referenceCase.project,
          construction: construction,
        );

        expect(
          result.totalResistance,
          closeTo(referenceCase.expectedTotalResistance, 0.001),
        );
        expect(
          result.requiredResistance,
          closeTo(referenceCase.expectedRequiredResistance, 0.001),
        );
        expect(
          result.complianceIndicators.single.isPassed,
          referenceCase.expectedThermalPass,
        );
        expect(
          result.moistureCheck.totalVaporResistance,
          closeTo(referenceCase.expectedTotalVaporResistance, 0.001),
        );
        expect(
          result.moistureCheck.outwardDryingRatio,
          closeTo(referenceCase.expectedOutwardDryingRatio, 0.001),
        );
        expect(result.moistureCheck.level, referenceCase.expectedMoistureLevel);
        expect(
          result.moistureCheck.seasonalPeriods,
          hasLength(
            testCatalogSnapshot.climatePoints
                .firstWhere(
                  (item) => item.id == referenceCase.project.climatePointId,
                )
                .moistureSeasons
                .length,
          ),
        );
        expect(
          result.moistureCheck.partialPressureSeries.points,
          hasLength(construction.layers.length + 1),
        );
        expect(
          result.moistureCheck.saturationPressureSeries.points,
          hasLength(construction.layers.length + 1),
        );
      });
    }
  });

  test(
    'ignores disabled layers in thermal and moisture calculations',
    () async {
      final construction = buildWallConstruction(insulationEnabled: false);
      final project = buildTestProject(construction: construction);

      final result = await engine.calculate(
        catalog: testCatalogSnapshot,
        project: project,
        construction: construction,
      );

      expect(result.layerRows, hasLength(3));
      expect(result.moistureCheck.layerRows, hasLength(3));
      expect(result.totalResistance, closeTo(3.053862434, 0.001));
      expect(
        result.moistureCheck.totalVaporResistance,
        closeTo(2.903161436, 0.001),
      );
      expect(result.moistureCheck.partialPressureSeries.points, hasLength(4));
      expect(result.totalResistance, lessThan(result.requiredResistance));
    },
  );

  test('builds monotonic thermal, vapor and seasonal profiles', () async {
    final project = buildTestProject(
      climatePointId: 'novosibirsk',
      roomPreset: RoomPreset.attic,
    );
    final construction = project.constructions.single;

    final result = await engine.calculate(
      catalog: testCatalogSnapshot,
      project: project,
      construction: construction,
    );

    expect(
      result.temperatureSeries.points,
      hasLength(construction.layers.length + 1),
    );
    expect(
      result.moistureCheck.vaporResistanceSeries.points,
      hasLength(construction.layers.length + 1),
    );
    expect(result.moistureCheck.seasonalPeriods, hasLength(3));

    for (
      var index = 1;
      index < result.temperatureSeries.points.length;
      index++
    ) {
      expect(
        result.temperatureSeries.points[index].y,
        lessThanOrEqualTo(result.temperatureSeries.points[index - 1].y),
      );
      expect(
        result.moistureCheck.vaporResistanceSeries.points[index].y,
        greaterThanOrEqualTo(
          result.moistureCheck.vaporResistanceSeries.points[index - 1].y,
        ),
      );
    }

    for (final period in result.moistureCheck.seasonalPeriods) {
      expect(period.endAccumulationKgPerSquareMeter, greaterThanOrEqualTo(0));
    }
  });

  test(
    'reports seasonal moisture accumulation for a vapor-closed wall',
    () async {
      const vaporClosedWall = Construction(
        id: 'vapor-closed-wall',
        title: 'Стена с паронепроницаемой облицовкой',
        elementKind: ConstructionElementKind.wall,
        layers: [
          ConstructionLayer(
            id: 'plaster',
            materialId: 'gypsum_plaster',
            kind: LayerKind.solid,
            thicknessMm: 20,
          ),
          ConstructionLayer(
            id: 'aac',
            materialId: 'aac_d500',
            kind: LayerKind.masonry,
            thicknessMm: 300,
          ),
          ConstructionLayer(
            id: 'brick',
            materialId: 'facing_brick',
            kind: LayerKind.masonry,
            thicknessMm: 250,
          ),
        ],
      );
      final project = buildTestProject(construction: vaporClosedWall);

      final result = await engine.calculate(
        catalog: testCatalogSnapshot,
        project: project,
        construction: vaporClosedWall,
      );

      expect(
        result.moistureCheck.seasonalPeriods.any(
          (item) => item.hasInterstitialCondensation,
        ),
        isTrue,
      );
      expect(
        result.moistureCheck.finalAccumulationKgPerSquareMeter,
        greaterThan(0),
      );
    },
  );

  test('fails fast for invalid vapor permeability', () async {
    final invalidCatalog = CatalogSnapshot(
      climatePoints: testCatalogSnapshot.climatePoints,
      materials: [
        const MaterialEntry(
          id: 'bad_material',
          name: 'Некорректный материал',
          category: 'Тест',
          thermalConductivity: 0.2,
          vaporPermeability: 0,
        ),
      ],
      constructionTemplates: const [],
      norms: testCatalogSnapshot.norms,
      moistureRules: testCatalogSnapshot.moistureRules,
      roomKindConditions: testCatalogSnapshot.roomKindConditions,
      heatingDevices: testCatalogSnapshot.heatingDevices,
      openingCatalog: testCatalogSnapshot.openingCatalog,
      datasetVersion: 'invalid',
    );
    const construction = Construction(
      id: 'invalid-wall',
      title: 'Стена с некорректным материалом',
      elementKind: ConstructionElementKind.wall,
      layers: [
        ConstructionLayer(
          id: 'bad-layer',
          materialId: 'bad_material',
          kind: LayerKind.solid,
          thicknessMm: 100,
        ),
      ],
    );
    final project = buildTestProject(construction: construction);

    await expectLater(
      () => engine.calculate(
        catalog: invalidCatalog,
        project: project,
        construction: construction,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('invalid vapor permeability'),
        ),
      ),
    );
  });

  group('floor scenarios', () {
    Construction buildFloorConstruction(
      FloorConstructionType floorType, {
      CrawlSpaceVentilationMode? crawlSpaceVentilationMode,
    }) {
      return Construction(
        id: 'floor-${floorType.storageKey}',
        title: floorType.label,
        elementKind: ConstructionElementKind.floor,
        floorConstructionType: floorType,
        crawlSpaceVentilationMode: crawlSpaceVentilationMode,
        layers: buildWallConstruction().layers,
      );
    }

    test('floor on ground stays routed to dedicated ground-floor module', () async {
      final construction = buildFloorConstruction(FloorConstructionType.onGround);
      final project = buildTestProject(construction: construction);

      final result = await engine.calculate(
        catalog: testCatalogSnapshot,
        project: project,
        construction: construction,
      );

      expect(
        result.scenarioStatus,
        CalculationScenarioStatus.routedToGroundFloor,
      );
      expect(result.scenarioMessage, contains('Полы по грунту'));
    });

    test('floor over crawl space is supported in thermocalc', () async {
      final construction = buildFloorConstruction(
        FloorConstructionType.overCrawlSpace,
      );
      final project = buildTestProject(construction: construction);

      final result = await engine.calculate(
        catalog: testCatalogSnapshot,
        project: project,
        construction: construction,
      );

      expect(result.scenarioStatus, CalculationScenarioStatus.supported);
      expect(result.requiredResistance, greaterThan(3.0));
      expect(result.totalResistance, greaterThan(result.requiredResistance));
      expect(result.scenarioMessage, contains('не выбран режим вентиляции'));
    });

    test('crawl space ventilation mode changes resulting resistance', () async {
      final ventilatedConstruction = buildFloorConstruction(
        FloorConstructionType.overCrawlSpace,
        crawlSpaceVentilationMode: CrawlSpaceVentilationMode.ventilated,
      );
      final unventilatedConstruction = buildFloorConstruction(
        FloorConstructionType.overCrawlSpace,
        crawlSpaceVentilationMode: CrawlSpaceVentilationMode.unventilated,
      );

      final ventilatedResult = await engine.calculate(
        catalog: testCatalogSnapshot,
        project: buildTestProject(construction: ventilatedConstruction),
        construction: ventilatedConstruction,
      );
      final unventilatedResult = await engine.calculate(
        catalog: testCatalogSnapshot,
        project: buildTestProject(construction: unventilatedConstruction),
        construction: unventilatedConstruction,
      );

      expect(
        unventilatedResult.totalResistance,
        greaterThan(ventilatedResult.totalResistance),
      );
      expect(
        unventilatedResult.scenarioMessage,
        contains('промежуточную температуру техподполья'),
      );
    });

    test('floor over basement is supported in thermocalc', () async {
      final construction = buildFloorConstruction(
        FloorConstructionType.overBasement,
      );
      final project = buildTestProject(construction: construction);

      final result = await engine.calculate(
        catalog: testCatalogSnapshot,
        project: project,
        construction: construction,
      );

      expect(result.scenarioStatus, CalculationScenarioStatus.supported);
      expect(result.requiredResistance, greaterThan(3.0));
      expect(result.totalResistance, greaterThan(result.requiredResistance));
      expect(result.scenarioMessage, contains('неотапливаемым подвалом'));
    });

    test('floor over driveway is supported with stronger requirement group', () async {
      final construction = buildFloorConstruction(
        FloorConstructionType.overDriveway,
      );
      final project = buildTestProject(construction: construction);
      final basementConstruction = buildFloorConstruction(
        FloorConstructionType.overBasement,
      );
      final basementProject = buildTestProject(construction: basementConstruction);

      final result = await engine.calculate(
        catalog: testCatalogSnapshot,
        project: project,
        construction: construction,
      );
      final basementResult = await engine.calculate(
        catalog: testCatalogSnapshot,
        project: basementProject,
        construction: basementConstruction,
      );

      expect(result.scenarioStatus, CalculationScenarioStatus.supported);
      expect(result.requiredResistance, greaterThan(basementResult.requiredResistance));
      expect(result.totalResistance, lessThan(basementResult.totalResistance));
    });
  });
}
