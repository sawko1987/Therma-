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

      await _scrollToPlan(tester);

      expect(find.text('План дома'), findsOneWidget);
      expect(find.text('Ошибка commit'), findsOneWidget);
    },
  );

  testWidgets('dragging a room persists updated layout', (tester) async {
    final repository = FakeProjectRepository();

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _scrollToPlan(tester);

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

  testWidgets('room resize snaps to 0.5m grid', (tester) async {
    final repository = FakeProjectRepository();

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _scrollToPlan(tester);

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
    await _scrollToPlan(tester);

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

  testWidgets('dragging a wall segment persists wall placement', (
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
                layout: buildRoomLayout(widthMeters: 6, heightMeters: 4),
              ),
            ],
            elements: [
              HouseEnvelopeElement(
                id: 'element-wall',
                roomId: defaultRoomId,
                title: 'Стена',
                elementKind: ConstructionElementKind.wall,
                areaSquareMeters: 3 * defaultRoomHeightMeters,
                constructionId: 'wall',
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

    await _dispatchPan(
      tester,
      find.byKey(const ValueKey('floor-plan-wall-element-wall')),
      const Offset(32, 0),
    );

    final savedProject = (await repository.getProject('demo'))!;
    final wall = savedProject.houseModel.elements.single;
    expect(wall.wallPlacement?.offsetMeters, 1);
    expect(wall.areaSquareMeters, closeTo(3 * defaultRoomHeightMeters, 0.0001));
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

Future<void> _scrollToPlan(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -700));
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
    DragUpdateDetails(
      globalPosition: origin + offset,
      delta: offset,
    ),
  );
  detector.onPanEnd?.call(DragEndDetails());
  await tester.pumpAndSettle();
}
