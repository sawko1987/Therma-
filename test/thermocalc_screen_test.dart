import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
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
}
