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

      expect(find.text('Сборка дома'), findsOneWidget);
      expect(find.text('Конструктор дома'), findsOneWidget);
      expect(find.text('Конструкции'), findsOneWidget);
      expect(
        find.textContaining(
          'помещения, ограждения, окна/двери и переиспользуемые конструкции',
        ),
        findsOneWidget,
      );

      await _scrollToPlanLauncher(tester);

      expect(find.text('Открыть редактор плана'), findsOneWidget);
      expect(find.text('Помещения и ограждения'), findsOneWidget);
    },
  );

  testWidgets('house builder opens building heat loss screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHouseScheme(tester, projectRepository: FakeProjectRepository());

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('open-building-heat-loss-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('open-building-heat-loss-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Теплопотери здания'), findsOneWidget);
    expect(find.textContaining('Итого потерь'), findsOneWidget);
    expect(find.text('Инфильтрация'), findsWidgets);
  });

  testWidgets('house builder summary handles long partition construction title', (
    tester,
  ) async {
    final longWall = buildWallConstruction().copyWith(
      title:
          'Очень длинная внутренняя перегородка с демонстрационно длинным названием для проверки отсутствия переполнения в dropdown',
    );
    final houseModel = HouseModel.bootstrapFromConstructions([
      longWall,
    ]).copyWith(internalPartitionConstructionId: longWall.id);
    final project = buildTestProject(
      constructions: [longWall],
      houseModel: houseModel,
    );

    await _pumpHouseScheme(
      tester,
      projectRepository: FakeProjectRepository(projects: [project]),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
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

    await _openPlanEditor(tester);

    expect(find.text('Редактор плана'), findsOneWidget);
    expect(find.text('План дома'), findsOneWidget);
    expect(
      find.textContaining(
        'Комната может состоять из нескольких соседних ячеек',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('close-house-plan-editor-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Отопительные приборы'), findsOneWidget);
    expect(find.text('Радиатор в гостиной'), findsOneWidget);
    expect(find.textContaining('1800'), findsWidgets);
  });

  testWidgets('dragging a room persists updated layout', (tester) async {
    final repository = FakeProjectRepository();

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _openPlanEditor(tester);

    await _dispatchPan(
      tester,
      find.byKey(const ValueKey('floor-plan-room-room-main')),
      const Offset(64, 32),
    );

    final savedProject = (await repository.getProject('demo'))!;
    final room = savedProject.houseModel.rooms.single;
    expect(room.layout.xMeters, 2);
    expect(room.layout.yMeters, 1);
  });

  testWidgets('add room uses draft placement and envelope assignment flow', (
    tester,
  ) async {
    final wall = buildWallConstruction();
    final floor = Construction(
      id: 'floor-main',
      title: 'Пол по грунту',
      elementKind: ConstructionElementKind.floor,
      floorConstructionType: FloorConstructionType.onGround,
      layers: wall.layers,
    );
    final ceiling = Construction(
      id: 'ceiling-main',
      title: 'Чердачное перекрытие',
      elementKind: ConstructionElementKind.ceiling,
      layers: wall.layers,
    );
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          constructions: [wall, floor, ceiling],
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Конструктор дома',
            rooms: [
              buildRoom(
                id: 'room-a',
                title: 'Комната A',
                layout: buildRoomLayout(
                  xMeters: 0,
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
    await _scrollToPlanLauncher(tester);

    await tester.tap(
      find.byKey(const ValueKey('add-room-via-plan-editor-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-room-placement-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-room-placement-button')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить ограждения'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить ограждения'));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    expect(savedProject.houseModel.rooms, hasLength(2));
    final createdRoom = savedProject.houseModel.rooms.last;
    expect(createdRoom.layout.widthMeters, 3);
    expect(createdRoom.layout.heightMeters, 3);
    expect(createdRoom.layout.xMeters, 4);
    expect(createdRoom.layout.yMeters, 0);
    expect(
      savedProject.houseModel.elements.any(
        (item) => item.id == 'auto-floor-${createdRoom.id}',
      ),
      isTrue,
    );
    expect(
      savedProject.houseModel.elements.any(
        (item) => item.id == 'auto-top-${createdRoom.id}',
      ),
      isTrue,
    );
  });

  testWidgets('room resize snaps to 0.5m grid', (tester) async {
    final repository = FakeProjectRepository();

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _openPlanEditor(tester);

    await _dispatchPan(
      tester,
      find.byKey(const ValueKey('floor-plan-room-resize-room-main')),
      const Offset(16, 16),
    );

    final savedProject = (await repository.getProject('demo'))!;
    final room = savedProject.houseModel.rooms.single;
    expect(room.layout.widthMeters, 4.5);
    expect(room.layout.heightMeters, 4.5);
  });

  testWidgets('selected room editor updates dimensions and height', (
    tester,
  ) async {
    final repository = FakeProjectRepository();

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _openPlanEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('selected-room-width-field')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('selected-room-height-field')),
      '6',
    );
    await tester.enterText(
      find.byKey(const ValueKey('selected-room-z-field')),
      '3.1',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('selected-room-save-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selected-room-save-button')));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    final room = savedProject.houseModel.rooms.single;
    expect(room.layout.widthMeters, 5);
    expect(room.layout.heightMeters, 6);
    expect(room.heightMeters, 3.1);
  });

  testWidgets('invalid room overlap rolls back draft and shows error', (
    tester,
  ) async {
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Конструктор дома',
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
    await _openPlanEditor(tester);

    await _dispatchPan(
      tester,
      find.byKey(const ValueKey('floor-plan-room-room-a')),
      const Offset(256, 0),
    );

    expect(
      find.byKey(const ValueKey('floor-plan-inline-error')),
      findsOneWidget,
    );
    expect(find.textContaining('Комнаты не должны пересекаться'), findsWidgets);

    final savedProject = (await repository.getProject('demo'))!;
    final room = savedProject.houseModel.rooms.firstWhere(
      (item) => item.id == 'room-a',
    );
    expect(room.layout.xMeters, 0);
    expect(room.layout.yMeters, 0);
  });

  testWidgets('tapping a wall segment splits exterior wall into two spans', (
    tester,
  ) async {
    final repository = FakeProjectRepository();

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _openPlanEditor(tester);

    await tester.tap(
      find.byKey(
        const ValueKey('floor-plan-wall-wall-room-main-0_0-0_0-4_0-0_0'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('split-wall-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('split-wall-button')));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    final topWalls = savedProject.houseModel.elements
        .where(
          (item) =>
              item.elementKind == ConstructionElementKind.wall &&
              item.lineSegment != null &&
              item.lineSegment!.startYMeters == 0 &&
              item.lineSegment!.endYMeters == 0,
        )
        .toList(growable: false);
    expect(topWalls, hasLength(2));
    expect(
      topWalls.fold<double>(
        0,
        (sum, item) => sum + item.lineSegment!.lengthMeters,
      ),
      closeTo(4, 0.0001),
    );
  });

  testWidgets('tapping a partition merges adjacent rooms', (tester) async {
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Конструктор дома',
            rooms: [
              buildRoom(
                id: 'room-a',
                title: 'Комната A',
                layout: buildRoomLayout(
                  xMeters: 0,
                  yMeters: 0,
                  widthMeters: 4,
                  heightMeters: 4,
                ),
              ),
              buildRoom(
                id: 'room-b',
                title: 'Комната B',
                kind: RoomKind.bedroom,
                layout: buildRoomLayout(
                  xMeters: 4,
                  yMeters: 0,
                  widthMeters: 2,
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
    await _openPlanEditor(tester);

    await tester.tap(
      find.byKey(const ValueKey('floor-plan-partition-4.0-0.0-4.0-4.0')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('merge-rooms-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('merge-rooms-button')));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    expect(savedProject.houseModel.rooms, hasLength(1));
    expect(savedProject.houseModel.rooms.single.effectiveCells, hasLength(2));
    expect(savedProject.houseModel.rooms.single.areaSquareMeters, 24);
  });

  testWidgets('cell edit mode adds a neighboring 0.5m cell to selected room', (
    tester,
  ) async {
    final repository = FakeProjectRepository();

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _openPlanEditor(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('cell-edit-add-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cell-edit-add-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('floor-plan-cell-add-4.0-0.0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('floor-plan-cell-add-4.0-0.0')));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    expect(savedProject.houseModel.rooms.single.areaSquareMeters, 16.25);
  });

  testWidgets('cell edit mode shows inline error for invalid removal', (
    tester,
  ) async {
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Дом',
            rooms: [
              buildRoom(
                cells: const [
                  RoomLayoutRect(
                    xMeters: 0,
                    yMeters: 0,
                    widthMeters: 0.5,
                    heightMeters: 0.5,
                  ),
                  RoomLayoutRect(
                    xMeters: 0.5,
                    yMeters: 0,
                    widthMeters: 0.5,
                    heightMeters: 0.5,
                  ),
                  RoomLayoutRect(
                    xMeters: 1.0,
                    yMeters: 0,
                    widthMeters: 0.5,
                    heightMeters: 0.5,
                  ),
                ],
              ),
            ],
            elements: const [],
            openings: const [],
          ),
        ),
      ],
    );

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _openPlanEditor(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('cell-edit-remove-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cell-edit-remove-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('floor-plan-cell-remove-0.5-0.0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('floor-plan-cell-remove-0.5-0.0')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('floor-plan-inline-error')),
      findsOneWidget,
    );
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

Future<void> _scrollToPlanLauncher(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('open-house-plan-editor-button')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openPlanEditor(WidgetTester tester) async {
  await _scrollToPlanLauncher(tester);
  await tester.tap(find.byKey(const ValueKey('open-house-plan-editor-button')));
  await tester.pumpAndSettle();
}

Future<void> _dispatchPan(
  WidgetTester tester,
  Finder finder,
  Offset offset,
) async {
  final detector = tester.widget<GestureDetector>(finder);
  final origin = tester.getCenter(finder);
  detector.onPanStart?.call(DragStartDetails(globalPosition: origin));
  detector.onPanUpdate?.call(
    DragUpdateDetails(globalPosition: origin + offset, delta: offset),
  );
  detector.onPanEnd?.call(DragEndDetails());
  await tester.pumpAndSettle();
}
