import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/house_scheme_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('house builder renders side navigation and sections', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHouseScheme(tester, projectRepository: FakeProjectRepository());

    expect(find.text('Сборка дома'), findsOneWidget);
    expect(find.text('Навигация по зданию'), findsOneWidget);
    expect(find.text('Общие данные'), findsWidgets);
    expect(find.text('Помещения'), findsWidgets);
    expect(find.text('Ограждающие конструкции'), findsWidgets);
  });

  testWidgets('side and main sections can be collapsed and expanded', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHouseScheme(tester, projectRepository: FakeProjectRepository());

    expect(find.byKey(const ValueKey('side-room-room-main')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('side-group-rooms-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('side-room-room-main')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('side-group-rooms-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('side-room-room-main')), findsOneWidget);

    expect(find.text('Наружная стена'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('main-section-envelope-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Наружная стена'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('main-section-envelope-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Наружная стена'), findsWidgets);
  });

  testWidgets('mobile layout opens drawer with sections', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHouseScheme(tester, projectRepository: FakeProjectRepository());

    expect(find.byKey(const ValueKey('open-sections-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-sections-button')));
    await tester.pumpAndSettle();

    expect(find.text('Навигация по зданию'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('side-group-heating-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('side-group-constructions-toggle')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('side-group-heating-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Список приборов'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('side-group-heating-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Список приборов'), findsOneWidget);
  });

  testWidgets('selecting sidebar item expands corresponding main section', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHouseScheme(tester, projectRepository: FakeProjectRepository());

    expect(find.text('Наружная стена'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('main-section-envelope-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Наружная стена'), findsNothing);

    await tester.tap(find.text('Список ограждений').first);
    await tester.pumpAndSettle();
    expect(find.text('Наружная стена'), findsWidgets);
  });

  testWidgets('room editor saves area and height via numeric fields', (
    tester,
  ) async {
    final repository = FakeProjectRepository();

    await _pumpHouseScheme(tester, projectRepository: repository);

    await tester.tap(find.text('Добавить помещение').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Кабинет');
    await tester.enterText(find.byType(TextField).at(1), '25');
    await tester.enterText(find.byType(TextField).at(2), '3.0');

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    final room = savedProject.houseModel.rooms.firstWhere(
      (item) => item.title == 'Кабинет',
    );
    expect(room.heightMeters, closeTo(3.0, 0.001));
    expect(room.areaSquareMeters, closeTo(25.0, 0.6));
  });

  testWidgets('legacy envelope items are shown in read-only block', (
    tester,
  ) async {
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          constructions: [
            Construction(
              id: 'roof',
              title: 'Кровля',
              elementKind: ConstructionElementKind.roof,
              layers: buildWallConstruction().layers,
            ),
          ],
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Конструктор дома',
            rooms: [Room.defaultRoom()],
            elements: const [
              HouseEnvelopeElement(
                id: 'legacy-wall',
                roomId: defaultRoomId,
                title: 'Старая стена',
                elementKind: ConstructionElementKind.wall,
                areaSquareMeters: 12,
                constructionId: 'roof',
                wallPlacement: null,
              ),
            ],
            openings: const [
              EnvelopeOpening(
                id: 'legacy-opening',
                elementId: 'legacy-wall',
                title: 'Старое окно',
                kind: OpeningKind.window,
                areaSquareMeters: 2,
                heatTransferCoefficient: 1.0,
              ),
            ],
          ),
        ),
      ],
    );

    await _pumpHouseScheme(tester, projectRepository: repository);

    expect(
      find.byKey(const ValueKey('legacy-read-only-block')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('legacy-read-only-block')));
    await tester.pumpAndSettle();

    expect(find.text('Старая стена'), findsOneWidget);
    expect(find.text('Старое окно'), findsOneWidget);
  });
}

Future<void> _pumpHouseScheme(
  WidgetTester tester, {
  required FakeProjectRepository projectRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        projectRepositoryProvider.overrideWithValue(projectRepository),
      ],
      child: const MaterialApp(home: HouseSchemeScreen()),
    ),
  );

  await tester.pumpAndSettle();
}
