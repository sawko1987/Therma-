import 'package:flutter_test/flutter_test.dart';
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
        expect(
          result.moistureCheck.level,
          referenceCase.expectedMoistureLevel,
        );
      });
    }
  });

  test('ignores disabled layers in thermal and moisture calculations', () async {
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
    expect(result.moistureCheck.totalVaporResistance, closeTo(2.903161436, 0.001));
    expect(result.totalResistance, lessThan(result.requiredResistance));
  });

  test('builds monotonic thermal and vapor profiles across layer boundaries', () async {
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

    for (var index = 1; index < result.temperatureSeries.points.length; index++) {
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
  });

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
      norms: testCatalogSnapshot.norms,
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
}
