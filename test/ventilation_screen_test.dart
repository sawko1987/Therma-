import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/models/ventilation_settings.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/features/ventilation/presentation/ventilation_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('ventilation screen renders and saves settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          ventilationSettings: const [
            VentilationSettings(
              id: 'vent-main',
              title: 'Базовая вентиляция',
              kind: VentilationKind.natural,
              airExchangeRate: 0.5,
              roomId: defaultRoomId,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: VentilationScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Вентиляция'), findsOneWidget);
    expect(find.text('Базовая вентиляция'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('ventilation-title')),
      'Рекуператор спальни',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ventilation-air-rate')),
      '0.70',
    );
    await tester.tap(find.byKey(const ValueKey('ventilation-save')));
    await tester.pumpAndSettle();

    final saved = (await repository.getProject('demo'))!;
    expect(saved.ventilationSettings.single.title, 'Рекуператор спальни');
    expect(saved.ventilationSettings.single.airExchangeRate, closeTo(0.7, 0.001));
    expect(find.text('Настройки вентиляции сохранены.'), findsOneWidget);
  });
}
