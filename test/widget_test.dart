import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/app/app.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/models/versioning.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'dashboard renders persisted projects and switches active project',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final roofConstruction = Construction(
        id: 'roof',
        title: 'Кровля',
        elementKind: ConstructionElementKind.roof,
        layers: buildWallConstruction().layers,
      );
      final secondProject = Project(
        id: 'roof-project',
        name: 'Новосибирск / кровля',
        climatePointId: 'novosibirsk',
        roomPreset: RoomPreset.attic,
        datasetVersion: currentDatasetVersion,
        migratedFromDatasetVersion: 'seed-2025-12-01',
        houseModel: HouseModel.bootstrapFromConstructions([roofConstruction]),
        constructions: [roofConstruction],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              FakeCatalogRepository(),
            ),
            projectRepositoryProvider.overrideWithValue(
              FakeProjectRepository(
                projects: [buildTestProject(), secondProject],
              ),
            ),
            thermalCalculationEngineProvider.overrideWithValue(
              const NormativeThermalCalculationEngine(),
            ),
          ],
          child: const SmartCalcApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SmartCalc Mobile'), findsOneWidget);
      expect(find.text('Сохранённые проекты'), findsOneWidget);
      expect(find.text('Открыть схему дома'), findsOneWidget);
      expect(find.text('Активный проект: Demo project'), findsOneWidget);
      expect(find.textContaining('seed-2025-12-01'), findsOneWidget);

      final secondProjectFinder = find.widgetWithText(
        ListTile,
        'Новосибирск / кровля',
      );
      await tester.tap(secondProjectFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Активный проект: Новосибирск / кровля'),
        findsOneWidget,
      );
    },
  );

  testWidgets('dashboard opens house scheme screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const SmartCalcApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Открыть схему дома'), 200);
    await tester.tap(find.text('Открыть схему дома'));
    await tester.pumpAndSettle();

    expect(find.text('Схема дома'), findsOneWidget);
    expect(find.text('Элементы дома'), findsOneWidget);
  });
}
