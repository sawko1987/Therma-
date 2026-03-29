import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/features/heating_economics/presentation/heating_economics_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('heating economics screen renders and saves tariffs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeProjectRepository(
      projects: [
        buildTestProject().copyWith(
          heatingEconomicsSettings: const HeatingEconomicsSettings(
            electricityPricePerKwh: 5.5,
            gasPricePerCubicMeter: 6.7,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: HeatingEconomicsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Шаг 3. Отопление и экономика'), findsOneWidget);
    expect(find.text('Экономика за сезон'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('electricity-price-field')),
      '9.25',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gas-price-field')),
      '8.1',
    );
    final saveButton = find.widgetWithText(FilledButton, 'Сохранить тарифы');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    expect(
      savedProject.heatingEconomicsSettings.electricityPricePerKwh,
      closeTo(9.25, 0.0001),
    );
    expect(
      savedProject.heatingEconomicsSettings.gasPricePerCubicMeter,
      closeTo(8.1, 0.0001),
    );
    expect(find.text('Тарифы сохранены.'), findsOneWidget);
  });
}
