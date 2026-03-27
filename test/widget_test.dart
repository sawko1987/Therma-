import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/app/app.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('dashboard renders core project text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider
              .overrideWithValue(const NormativeThermalCalculationEngine()),
        ],
        child: const SmartCalcApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('SmartCalc Mobile'), findsOneWidget);
    expect(find.text('Локальные каталоги'), findsOneWidget);
  });
}
