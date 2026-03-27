import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/house_scheme_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('house builder screen renders rooms, elements and constructions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
        ],
        child: const MaterialApp(home: HouseSchemeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Сборка дома'), findsOneWidget);
    expect(find.text('Конструктор дома'), findsOneWidget);
    expect(find.text('Конструкции'), findsOneWidget);
    expect(find.textContaining('помещения, ограждения и переиспользуемые конструкции'), findsOneWidget);
  });
}
