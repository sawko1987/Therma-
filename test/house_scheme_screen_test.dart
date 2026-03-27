import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/house_scheme_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('house scheme screen renders semantic house elements', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
        ],
        child: const MaterialApp(home: HouseSchemeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Схема дома'), findsOneWidget);
    expect(find.text('Базовая схема дома'), findsOneWidget);
    expect(find.text('Элементы дома'), findsOneWidget);
    expect(find.text('Наружная стена'), findsAtLeastNWidgets(1));
    expect(find.textContaining('100.0 м²'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Phase 2 base'), findsOneWidget);
  });
}
