import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/house_scheme_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'house builder screen renders rooms, elements and constructions',
    (tester) async {
      await _pumpHouseScheme(
        tester,
        projectRepository: FakeProjectRepository(),
      );

      expect(find.text('Планировка дома'), findsOneWidget);
      expect(
        find.textContaining('После выбора ограждающих конструкций'),
        findsOneWidget,
      );
      expect(find.text('Конструкции'), findsOneWidget);
      expect(
        find.textContaining(
          'задайте план дома: помещения, ограждения, окна и двери',
        ),
        findsOneWidget,
      );

      await _scrollToPlan(tester);

      expect(find.text('План дома'), findsOneWidget);
      expect(find.text('Планировочная схема'), findsOneWidget);
    },
  );

  testWidgets('house builder opens building heat loss screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHouseScheme(tester, projectRepository: FakeProjectRepository());

    await tester.scrollUntilVisible(
      find.text('Рассчитать теплопотери здания'),
      200,
    );
    await tester.tap(find.text('Рассчитать теплопотери здания'));
    await tester.pumpAndSettle();

    expect(find.text('Теплопотери здания'), findsOneWidget);
    expect(find.textContaining('Итого потерь'), findsOneWidget);
  });

  testWidgets('house builder screen renders heating devices card', (
    tester,
  ) async {
    await _pumpHouseScheme(
      tester,
      projectRepository: FakeProjectRepository(
        projects: [
          buildTestProject(
            houseModel: buildHouseModel(
              heatingDevices: [
                buildHeatingDevice(
                  id: 'device-main',
                  title: 'Радиатор в гостиной',
                  ratedPowerWatts: 1800,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await _scrollToPlan(tester);

    expect(find.text('Отопительные приборы'), findsOneWidget);
    expect(find.text('Радиатор в гостиной'), findsOneWidget);
    expect(find.textContaining('1800'), findsWidgets);
  });

  testWidgets('room movement buttons persist updated layout', (tester) async {
    final repository = FakeProjectRepository();

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _scrollToPlan(tester);

    await tester.tap(find.text('Сдвинуть вправо'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сдвинуть вниз'));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    final room = savedProject.houseModel.rooms.single;
    expect(room.layout.xMeters, 0.5);
    expect(room.layout.yMeters, 0.5);
  });

  testWidgets('floor plan editor switches selected room', (tester) async {
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Планировка дома',
            rooms: [
              buildRoom(id: 'room-a', title: 'Гостиная'),
              buildRoom(
                id: 'room-b',
                title: 'Спальня',
                kind: RoomKind.bedroom,
                layout: buildRoomLayout(xMeters: 5, yMeters: 0),
              ),
            ],
            elements: const [],
            openings: const [],
          ),
        ),
      ],
    );

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _scrollToPlan(tester);

    expect(find.text('Гостиная'), findsWidgets);
    expect(find.text('Спальня'), findsWidgets);

    await tester.tap(find.text('Спальня • 4.0×4.0 м'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Позиция: 5.0 / 0.0 м'), findsOneWidget);
  });

  testWidgets('invalid room overlap stops movement at last valid layout', (
    tester,
  ) async {
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Планировка дома',
            rooms: [
              buildRoom(
                id: 'room-a',
                title: 'Гостиная',
                layout: buildRoomLayout(
                  xMeters: 0,
                  yMeters: 0,
                  widthMeters: 4,
                  heightMeters: 4,
                ),
              ),
              buildRoom(
                id: 'room-b',
                title: 'Спальня',
                kind: RoomKind.bedroom,
                layout: buildRoomLayout(
                  xMeters: 6,
                  yMeters: 0,
                  widthMeters: 4,
                  heightMeters: 4,
                ),
              ),
            ],
            elements: const [],
            openings: const [],
          ),
        ),
      ],
    );

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _scrollToPlan(tester);

    for (var index = 0; index < 6; index++) {
      await tester.tap(find.text('Сдвинуть вправо'));
      await tester.pumpAndSettle();
    }

    final savedProject = (await repository.getProject('demo'))!;
    final room = savedProject.houseModel.rooms.firstWhere(
      (item) => item.id == 'room-a',
    );
    expect(room.layout.xMeters, 2.0);
    expect(room.layout.yMeters, 0);
  });

  testWidgets('wall placement menu persists wall placement', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Планировка дома',
            rooms: [
              buildRoom(
                layout: buildRoomLayout(widthMeters: 6, heightMeters: 4),
              ),
            ],
            elements: [
              buildEnvelopeElement(
                id: 'element-wall',
                title: 'Стена',
                areaSquareMeters: 3 * defaultRoomHeightMeters,
                construction: buildWallConstruction(),
                wallPlacement: buildWallPlacement(lengthMeters: 3),
              ),
            ],
            openings: const [],
          ),
        ),
      ],
    );

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _scrollToPlan(tester);
    for (final popupButton in tester.widgetList<PopupMenuButton<String>>(
      find.byType(PopupMenuButton<String>),
    )) {
      popupButton.onSelected?.call('right');
    }
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    final wall = savedProject.houseModel.elements.single;
    expect(wall.wallPlacement?.offsetMeters, 0.5);
    expect(wall.areaSquareMeters, closeTo(3 * defaultRoomHeightMeters, 0.0001));
  });

  testWidgets('room envelope blocks are collapsed by default and expandable', (
    tester,
  ) async {
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Планировка дома',
            rooms: [buildRoom()],
            elements: [
              buildEnvelopeElement(
                id: 'element-wall',
                title: 'Наружная стена',
                areaSquareMeters: 3 * defaultRoomHeightMeters,
                construction: buildWallConstruction(),
                wallPlacement: buildWallPlacement(lengthMeters: 3),
              ),
            ],
            openings: [
              EnvelopeOpening(
                id: 'opening-1',
                elementId: 'element-wall',
                title: 'Окно 1',
                kind: OpeningKind.window,
                areaSquareMeters: 1.5,
                heatTransferCoefficient: 1.0,
              ),
            ],
          ),
        ),
      ],
    );

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _scrollToPlan(tester);

    expect(
      find.byKey(const ValueKey('room-envelope-details-element-wall')),
      findsNothing,
    );
    expect(find.text('Окно 1'), findsNothing);

    final expandButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('room-envelope-toggle-element-wall')),
    );
    expandButton.onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('room-envelope-details-element-wall')),
      findsOneWidget,
    );
    expect(find.textContaining('сегмент 3.0 м'), findsOneWidget);
    expect(find.text('Окно 1'), findsOneWidget);

    final collapseButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('room-envelope-toggle-element-wall')),
    );
    collapseButton.onPressed?.call();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('room-envelope-details-element-wall')),
      findsNothing,
    );
    expect(find.text('Окно 1'), findsNothing);
  });

  testWidgets(
    'room envelope without openings shows empty message only expanded',
    (tester) async {
      final repository = FakeProjectRepository(
        projects: [
          buildTestProject(
            houseModel: HouseModel(
              id: 'house-model',
              title: 'Планировка дома',
              rooms: [buildRoom()],
              elements: [
                buildEnvelopeElement(
                  id: 'element-wall',
                  title: 'Наружная стена',
                  areaSquareMeters: 3 * defaultRoomHeightMeters,
                  construction: buildWallConstruction(),
                  wallPlacement: buildWallPlacement(lengthMeters: 3),
                ),
              ],
              openings: const [],
            ),
          ),
        ],
      );

      await _pumpHouseScheme(tester, projectRepository: repository);
      await _scrollToPlan(tester);

      expect(find.text('Проёмы не добавлены.'), findsNothing);

      final expandButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('room-envelope-toggle-element-wall')),
      );
      expandButton.onPressed?.call();
      await tester.pumpAndSettle();

      expect(find.text('Проёмы не добавлены.'), findsOneWidget);
    },
  );
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

Future<void> _scrollToPlan(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -700));
  await tester.pumpAndSettle();
}
