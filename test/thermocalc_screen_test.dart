import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/core/models/versioning.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';
import 'package:smartcalc_mobile/src/features/thermocalc/presentation/thermocalc_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('thermocalc screen renders thermal and moisture sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: ThermocalcScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Нормативные показатели'), findsOneWidget);
    expect(find.text('Требуемое R'), findsOneWidget);
    expect(find.text('Сезонный влагорежим'), findsOneWidget);
    expect(find.text('Профиль парциального давления'), findsOneWidget);
    expect(find.text('Сезонный баланс влаги'), findsOneWidget);
    expect(find.text('Температурный профиль'), findsOneWidget);
    expect(find.text('Применённые нормы'), findsOneWidget);
    expect(find.text('СП 50.13330.2012'), findsAtLeastNWidgets(1));
  });

  testWidgets('thermocalc screen shows project migration label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            FakeProjectRepository(
              projects: [
                buildTestProject(
                  migratedFromDatasetVersion: 'seed-2025-12-01',
                ),
              ],
            ),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: ThermocalcScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(
        'Проект обновлен с версии seed-2025-12-01 на $currentDatasetVersion',
      ),
      findsOneWidget,
    );
  });
  testWidgets('thermocalc screen exports pdf and shows success message', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
          reportServiceProvider.overrideWithValue(FakeReportService()),
          reportFileStoreProvider.overrideWithValue(FakeReportFileStore()),
        ],
        child: const MaterialApp(home: ThermocalcScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Экспорт PDF'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('PDF сохранен:'), findsOneWidget);
    expect(find.textContaining('thermocalc_demo.pdf'), findsOneWidget);
  });

  testWidgets('thermocalc screen can render a focused construction without element context', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(
          home: ThermocalcScreen(
            constructionId: 'wall',
            showElementContext: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Конструкция: Наружная стена'), findsOneWidget);
    expect(find.textContaining('Ограждение:'), findsNothing);
    expect(find.text('Сезонный влагорежим'), findsOneWidget);
  });

  testWidgets('thermocalc screen shows export failure message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
          reportServiceProvider.overrideWithValue(
            FakeReportService(error: StateError('boom')),
          ),
          reportFileStoreProvider.overrideWithValue(FakeReportFileStore()),
        ],
        child: const MaterialApp(home: ThermocalcScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Экспорт PDF'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Не удалось экспортировать PDF'),
      findsOneWidget,
    );
  });
}
