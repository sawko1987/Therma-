import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/features/ground_floor/presentation/ground_floor_screen.dart';
import 'package:smartcalc_mobile/src/core/models/ground_floor_calculation.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
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

  testWidgets('ground floor screen renders persisted calculation', (
    tester,
  ) async {
    final floor = buildFloorConstruction();
    final project = buildTestProject(
      constructions: [floor],
      groundFloorCalculations: const [
        GroundFloorCalculation(
          id: 'ground-a',
          title: 'Пол первого этажа',
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            FakeProjectRepository(projects: [project]),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: GroundFloorScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Полы по грунту'), findsOneWidget);
    expect(find.text('Пол первого этажа'), findsWidgets);
    expect(find.text('Результат'), findsOneWidget);
  });

  testWidgets('ground floor screen saves edited values', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final floor = buildFloorConstruction();
    final project = buildTestProject(
      constructions: [floor],
      groundFloorCalculations: const [
        GroundFloorCalculation(
          id: 'ground-a',
          title: 'Пол первого этажа',
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
    final repository = FakeProjectRepository(projects: [project]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(repository),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: GroundFloorScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ground-floor-title')),
      'Пол гостиной',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('ground-floor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ground-floor-save')));
    await tester.pumpAndSettle();

    final stored = (await repository.listProjects()).single;
    expect(stored.groundFloorCalculations.single.title, 'Пол гостиной');
  });
}
