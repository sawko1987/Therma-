import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/house_scheme_screen.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/widgets/wall_graph_editor.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('wall-first editor renders for new projects', (tester) async {
    await _pumpHouseScheme(
      tester,
      projectRepository: FakeProjectRepository(
        projects: [_buildWallGraphProject()],
      ),
    );

    await _scrollToPlanner(tester);

    expect(find.text('Сборка дома'), findsOneWidget);
    expect(find.text('Новый контур'), findsOneWidget);
    expect(find.text('Открыть редактор'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wall-graph-overview-preview')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('wall-graph-canvas')), findsNothing);
    expect(find.text('Legacy-план заблокирован'), findsNothing);
  });

  testWidgets('legacy room cell projects are blocked in planner', (
    tester,
  ) async {
    await _pumpHouseScheme(
      tester,
      projectRepository: FakeProjectRepository(projects: [buildTestProject()]),
    );

    await _scrollToLegacyBlock(tester);

    expect(find.text('Legacy-план заблокирован'), findsOneWidget);
    expect(find.text('Новый контур'), findsNothing);
  });

  testWidgets('drawing a closed contour creates a room and walls', (
    tester,
  ) async {
    final repository = FakeProjectRepository(
      projects: [_buildEmptyWallGraphProject()],
    );

    await _pumpEditorScreen(
      tester,
      projectRepository: repository,
      startInDrawMode: true,
    );

    await tester.pumpAndSettle();

    await _tapCanvasPoint(tester, const Offset(60, 60));
    await _tapCanvasPoint(tester, const Offset(204, 60));
    await _tapCanvasPoint(tester, const Offset(204, 168));
    await _tapCanvasPoint(tester, const Offset(60, 168));
    await _tapCanvasPoint(tester, const Offset(60, 60));

    await tester.tap(
      find.byKey(const ValueKey('wall-graph-commit-contour-button')),
    );
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    expect(savedProject.houseModel.planWalls, hasLength(4));
    expect(savedProject.houseModel.rooms, hasLength(1));
    expect(savedProject.houseModel.rooms.single.areaSquareMeters, 12);
  });

  testWidgets('selected room updates title and height', (tester) async {
    final repository = FakeProjectRepository(
      projects: [_buildWallGraphProject()],
    );

    await _pumpEditorScreen(tester, projectRepository: repository);

    await _tapCanvasPoint(tester, const Offset(96, 96));
    await tester.pumpAndSettle();

    expect(find.text('Помещение'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('wall-graph-room-title-field')),
      'Кухня',
    );
    await tester.enterText(
      find.byKey(const ValueKey('wall-graph-room-height-field')),
      '3.1',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('wall-graph-save-room-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wall-graph-save-room-button')));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    expect(savedProject.houseModel.rooms.single.title, 'Кухня');
    expect(savedProject.houseModel.rooms.single.heightMeters, 3.1);
  });

  testWidgets('multi select walls applies wall construction in batch', (
    tester,
  ) async {
    final primaryWall = buildWallConstruction();
    final secondaryWall = buildWallConstruction(
      insulationEnabled: false,
    ).copyWith(id: 'wall-alt', title: 'Альтернативная стена');
    final repository = FakeProjectRepository(
      projects: [
        _buildWallGraphProject(
          wallConstruction: primaryWall,
          extraConstructions: [secondaryWall],
        ),
      ],
    );

    await _pumpEditorScreen(tester, projectRepository: repository);

    await tester.longPress(find.byKey(const ValueKey('wall-graph-wall-w-top')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wall-graph-wall-w-right')));
    await tester.pumpAndSettle();

    expect(find.text('Выбрано стен: 2'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('wall-graph-wall-construction-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('wall-graph-wall-construction-field')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Альтернативная стена').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Альтернативная стена').last);
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    final updatedWalls = savedProject.houseModel.planWalls
        .where((wall) => wall.id == 'w-top' || wall.id == 'w-right')
        .toList(growable: false);
    expect(updatedWalls, hasLength(2));
    expect(
      updatedWalls.every((wall) => wall.constructionId == secondaryWall.id),
      isTrue,
    );
  });

  testWidgets('selected wall adds window opening', (tester) async {
    final repository = FakeProjectRepository(
      projects: [_buildWallGraphProject()],
    );

    await _pumpEditorScreen(tester, projectRepository: repository);

    await tester.tap(find.byKey(const ValueKey('wall-graph-wall-w-top')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('wall-graph-add-window-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('wall-graph-add-window-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('wall-graph-save-opening-button')),
    );
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    expect(savedProject.houseModel.planWallOpenings, hasLength(1));
    expect(savedProject.houseModel.planWallOpenings.single.wallId, 'w-top');
    expect(
      savedProject.houseModel.planWallOpenings.single.kind,
      OpeningKind.window,
    );
  });

  testWidgets('house builder opens building heat loss screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHouseScheme(
      tester,
      projectRepository: FakeProjectRepository(
        projects: [_buildWallGraphProject()],
      ),
    );

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
  });

  testWidgets('overview opens separate wall graph editor screen', (
    tester,
  ) async {
    await _pumpHouseScheme(
      tester,
      projectRepository: FakeProjectRepository(
        projects: [_buildWallGraphProject()],
      ),
    );

    await _scrollToPlanner(tester);
    await tester.tap(
      find.byKey(const ValueKey('open-wall-graph-editor-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Редактор плана'), findsOneWidget);
    expect(find.byKey(const ValueKey('wall-graph-canvas')), findsOneWidget);
    expect(find.textContaining('План строится стенами'), findsOneWidget);
  });

  testWidgets('new contour button opens editor already in draw mode', (
    tester,
  ) async {
    final repository = FakeProjectRepository(
      projects: [_buildEmptyWallGraphProject()],
    );

    await _pumpHouseScheme(tester, projectRepository: repository);
    await _scrollToPlanner(tester);

    await tester.tap(
      find.byKey(const ValueKey('open-wall-graph-create-contour-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Редактор плана'), findsOneWidget);
    expect(find.text('Отменить контур'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wall-graph-commit-contour-button')),
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

Future<void> _tapCanvasPoint(WidgetTester tester, Offset localOffset) async {
  final canvas = find.byKey(const ValueKey('wall-graph-canvas'));
  final topLeft = tester.getTopLeft(canvas);
  await tester.tapAt(topLeft + localOffset);
  await tester.pumpAndSettle();
}

Future<void> _scrollToPlanner(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('open-wall-graph-create-contour-button')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpEditorScreen(
  WidgetTester tester, {
  required FakeProjectRepository projectRepository,
  bool startInDrawMode = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        projectRepositoryProvider.overrideWithValue(projectRepository),
      ],
      child: MaterialApp(
        home: WallGraphEditorScreen(
          project: (await projectRepository.getProject('demo'))!,
          catalog: testCatalogSnapshot,
          startInDrawMode: startInDrawMode,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _scrollToLegacyBlock(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Legacy-план заблокирован'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Project _buildEmptyWallGraphProject() {
  final wall = buildWallConstruction();
  return buildTestProject(
    constructions: [wall],
    houseModel: HouseModel.emptyWallGraph(),
  );
}

Project _buildWallGraphProject({
  Construction? wallConstruction,
  List<Construction> extraConstructions = const [],
}) {
  final wall = wallConstruction ?? buildWallConstruction();
  final floor = Construction(
    id: 'floor-main',
    title: 'Пол по грунту',
    elementKind: ConstructionElementKind.floor,
    floorConstructionType: FloorConstructionType.onGround,
    layers: wall.layers,
  );
  final top = Construction(
    id: 'top-main',
    title: 'Чердачное перекрытие',
    elementKind: ConstructionElementKind.ceiling,
    layers: wall.layers,
  );
  return buildTestProject(
    constructions: [wall, floor, top, ...extraConstructions],
    houseModel: HouseModel(
      id: 'house-model',
      title: 'Конструктор дома',
      planModelKind: HousePlanModelKind.wallGraph,
      planNodes: const [
        PlanNode(id: 'n1', xMeters: 0, yMeters: 0),
        PlanNode(id: 'n2', xMeters: 4, yMeters: 0),
        PlanNode(id: 'n3', xMeters: 4, yMeters: 3),
        PlanNode(id: 'n4', xMeters: 0, yMeters: 3),
      ],
      planWalls: [
        PlanWall(
          id: 'w-top',
          startNodeId: 'n1',
          endNodeId: 'n2',
          constructionId: wall.id,
        ),
        PlanWall(
          id: 'w-right',
          startNodeId: 'n2',
          endNodeId: 'n3',
          constructionId: wall.id,
        ),
        PlanWall(
          id: 'w-bottom',
          startNodeId: 'n3',
          endNodeId: 'n4',
          constructionId: wall.id,
        ),
        PlanWall(
          id: 'w-left',
          startNodeId: 'n4',
          endNodeId: 'n1',
          constructionId: wall.id,
        ),
      ],
      rooms: [
        buildRoom(
          id: 'room-main',
          title: 'Гостиная',
          layout: buildRoomLayout(
            xMeters: 0,
            yMeters: 0,
            widthMeters: 4,
            heightMeters: 3,
          ),
        ),
      ],
      elements: const [],
      openings: const [],
    ),
  );
}
