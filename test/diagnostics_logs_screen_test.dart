import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen opens diagnostics logs screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Диагностика и логи'));
    await tester.pumpAndSettle();

    expect(find.text('Диагностика и логи'), findsOneWidget);
    expect(find.text('Фильтрация'), findsOneWidget);
  });
}
