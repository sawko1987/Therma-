import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/ground_floor_calculation.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/services/project_editing_service.dart';

import 'support/fakes.dart';

void main() {
  const service = ProjectEditingService();

  test('addRoom appends a new room to project house model', () {
    final project = buildTestProject();

    final updated = service.addRoom(
      project,
      Room(
        id: 'room-bedroom',
        title: 'Спальня',
        kind: RoomKind.bedroom,
        heightMeters: 2.7,
        layout: buildRoomLayout(xMeters: 4, yMeters: 0),
      ),
    );

    expect(updated.houseModel.rooms, hasLength(2));
    expect(updated.houseModel.rooms.last.title, 'Спальня');
  });

  test('addRoom rejects disconnected layout without shared side', () {
    final project = buildTestProject();

    expect(
      () => service.addRoom(
        project,
        Room(
          id: 'room-bedroom',
          title: 'Спальня',
          kind: RoomKind.bedroom,
          heightMeters: 2.7,
          layout: buildRoomLayout(xMeters: 6, yMeters: 0),
        ),
      ),
      throwsStateError,
    );
  });

  test('addRoom rejects overlapping layout', () {
    final project = buildTestProject();

    expect(
      () => service.addRoom(
        project,
        Room(
          id: 'room-overlap',
          title: 'Пересечение',
          kind: RoomKind.other,
          heightMeters: 2.7,
          layout: buildRoomLayout(xMeters: 2, yMeters: 2),
        ),
      ),
      throwsStateError,
    );
  });

  test('deleteRoom rejects removal when envelope elements still linked', () {
    final project = buildTestProject();

    expect(
      () => service.deleteRoom(project, project.houseModel.rooms.first.id),
      throwsStateError,
    );
  });

  test(
    'deleteConstruction rejects removal when construction is still in use',
    () {
      final project = buildTestProject();

      expect(
        () =>
            service.deleteConstruction(project, project.constructions.first.id),
        throwsStateError,
      );
    },
  );

  test('updateInternalPartitionConstruction rejects non-wall construction', () {
    final floor = Construction(
      id: 'floor',
      title: 'Пол',
      elementKind: ConstructionElementKind.floor,
      floorConstructionType: FloorConstructionType.overBasement,
      layers: buildWallConstruction().layers,
    );
    final project = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Дом',
        rooms: [Room.defaultRoom()],
        elements: const [],
        openings: const [],
      ),
    ).copyWith(constructions: [buildWallConstruction(), floor]);

    expect(
      () => service.updateInternalPartitionConstruction(project, floor.id),
      throwsStateError,
    );
  });

  test(
    'deleteConstruction retargets internal partition construction to remaining wall',
    () {
      final primaryWall = buildWallConstruction();
      final secondaryWall = primaryWall.copyWith(
        id: 'wall-secondary',
        title: 'Внутренняя перегородка',
      );
      final project =
          buildTestProject(
            construction: primaryWall,
            houseModel: HouseModel(
              id: 'house-model',
              title: 'Дом',
              rooms: [Room.defaultRoom()],
              elements: const [],
              openings: const [],
              internalPartitionConstructionId: 'wall-secondary',
            ),
          ).copyWith(
            constructions: [primaryWall, secondaryWall],
            selectedConstructionIds: [primaryWall.id, secondaryWall.id],
          );

      final updated = service.deleteConstruction(project, secondaryWall.id);

      expect(
        updated.houseModel.internalPartitionConstructionId,
        primaryWall.id,
      );
    },
  );

  test(
    'updateEnvelopeElement rebinds element to another room and construction',
    () {
      final firstConstruction = buildWallConstruction();
      final secondConstruction = Construction(
        id: 'roof',
        title: 'Кровля',
        elementKind: ConstructionElementKind.roof,
        layers: firstConstruction.layers,
      );
      final project = buildTestProject(
        construction: firstConstruction,
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Конструктор дома',
          rooms: [
            buildRoom(
              id: 'room-living',
              title: 'Гостиная',
              kind: RoomKind.livingRoom,
              heightMeters: 2.7,
              layout: buildRoomLayout(
                xMeters: 0,
                yMeters: 0,
                widthMeters: 4,
                heightMeters: 5,
              ),
            ),
            buildRoom(
              id: 'room-attic',
              title: 'Мансарда',
              kind: RoomKind.bedroom,
              heightMeters: 2.5,
              layout: buildRoomLayout(
                xMeters: 5,
                yMeters: 0,
                widthMeters: 3.5,
                heightMeters: 4,
              ),
            ),
          ],
          elements: [
            HouseEnvelopeElement(
              id: 'element-wall',
              roomId: 'room-living',
              title: 'Стена гостиной',
              elementKind: ConstructionElementKind.wall,
              areaSquareMeters: 10.8,
              constructionId: 'wall',
              wallPlacement: buildWallPlacement(lengthMeters: 4),
            ),
          ],
          openings: const [],
        ),
      ).copyWith(constructions: [firstConstruction, secondConstruction]);

      final updated = service.updateEnvelopeElement(
        project,
        project.houseModel.elements.single.copyWith(
          roomId: 'room-attic',
          constructionId: 'roof',
          elementKind: ConstructionElementKind.roof,
          clearWallPlacement: true,
        ),
      );

      expect(updated.houseModel.elements.single.roomId, 'room-attic');
      expect(updated.houseModel.elements.single.constructionId, 'roof');
      expect(
        updated.houseModel.elements.single.elementKind,
        ConstructionElementKind.roof,
      );
      expect(updated.houseModel.elements.single.wallPlacement, isNull);
    },
  );

  test('updateRoomLayout updates geometry and derived room area', () {
    final project = buildTestProject();

    final updated = service.updateRoomLayout(
      project,
      defaultRoomId,
      buildRoomLayout(
        xMeters: 2,
        yMeters: 1.5,
        widthMeters: 5,
        heightMeters: 6,
      ),
    );

    expect(updated.houseModel.rooms.single.layout.xMeters, 2);
    expect(updated.houseModel.rooms.single.layout.yMeters, 1.5);
    expect(updated.houseModel.rooms.single.areaSquareMeters, 30);
  });

  test('updateRoom syncs derived wall area from room height', () {
    final project = buildTestProject();

    final updated = service.updateRoom(
      project,
      project.houseModel.rooms.single.copyWith(heightMeters: 3.1),
    );
    final topWall = updated.houseModel.elements.firstWhere(
      (item) =>
          item.elementKind == ConstructionElementKind.wall &&
          item.lineSegment != null &&
          item.lineSegment!.startYMeters == 0 &&
          item.lineSegment!.endYMeters == 0,
    );

    expect(topWall.areaSquareMeters, closeTo(12.4, 0.001));
  });

  test('configureRoomEnvelope creates auto floor and top elements', () {
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
    final project = buildTestProject(constructions: [wall, floor, ceiling]);

    final updated = service.configureRoomEnvelope(
      project,
      roomId: defaultRoomId,
      floorConstructionId: floor.id,
      topConstructionId: ceiling.id,
    );

    expect(
      updated.houseModel.elements.any(
        (item) => item.id == 'auto-floor-room-main',
      ),
      isTrue,
    );
    expect(
      updated.houseModel.elements.any(
        (item) => item.id == 'auto-top-room-main',
      ),
      isTrue,
    );
  });

  test('updateRoom syncs auto floor and top area from room area', () {
    final wall = buildWallConstruction();
    final floor = Construction(
      id: 'floor-main',
      title: 'Пол по грунту',
      elementKind: ConstructionElementKind.floor,
      floorConstructionType: FloorConstructionType.onGround,
      layers: wall.layers,
    );
    final roof = Construction(
      id: 'roof-main',
      title: 'Теплая кровля',
      elementKind: ConstructionElementKind.roof,
      layers: wall.layers,
    );
    final configuredProject = service.configureRoomEnvelope(
      buildTestProject(constructions: [wall, floor, roof]),
      roomId: defaultRoomId,
      floorConstructionId: floor.id,
      topConstructionId: roof.id,
    );

    final updated = service.updateRoom(
      configuredProject,
      configuredProject.houseModel.rooms.single.copyWith(
        layout: buildRoomLayout(widthMeters: 5, heightMeters: 6),
      ),
    );

    final autoFloor = updated.houseModel.elements.firstWhere(
      (item) => item.id == 'auto-floor-room-main',
    );
    final autoTop = updated.houseModel.elements.firstWhere(
      (item) => item.id == 'auto-top-room-main',
    );
    expect(autoFloor.areaSquareMeters, 30);
    expect(autoTop.areaSquareMeters, 30);
  });

  test('linked ground floor calculation syncs from auto floor element', () {
    final wall = buildWallConstruction();
    final floor = Construction(
      id: 'floor-main',
      title: 'Пол по грунту',
      elementKind: ConstructionElementKind.floor,
      floorConstructionType: FloorConstructionType.onGround,
      layers: wall.layers,
    );
    final project = service.configureRoomEnvelope(
      buildTestProject(constructions: [wall, floor]),
      roomId: defaultRoomId,
      floorConstructionId: floor.id,
    );

    final updated = service.addGroundFloorCalculation(
      project,
      const GroundFloorCalculation(
        id: 'gf-main',
        title: 'Связанный пол',
        kind: GroundFloorCalculationKind.slabOnGround,
        constructionId: 'wall',
        areaSquareMeters: 1,
        perimeterMeters: 16,
        slabWidthMeters: 4,
        slabLengthMeters: 4,
        edgeInsulationWidthMeters: 0.6,
        edgeInsulationResistance: 1.5,
        houseElementId: 'auto-floor-room-main',
      ),
    );

    expect(updated.groundFloorCalculations.single.constructionId, floor.id);
    expect(updated.groundFloorCalculations.single.areaSquareMeters, 16);
  });

  test('linked ground floor calculation clears link when floor element removed', () {
    final wall = buildWallConstruction();
    final floor = Construction(
      id: 'floor-main',
      title: 'Пол по грунту',
      elementKind: ConstructionElementKind.floor,
      floorConstructionType: FloorConstructionType.onGround,
      layers: wall.layers,
    );
    final project = service.addGroundFloorCalculation(
      service.configureRoomEnvelope(
        buildTestProject(constructions: [wall, floor]),
        roomId: defaultRoomId,
        floorConstructionId: floor.id,
      ),
      const GroundFloorCalculation(
        id: 'gf-main',
        title: 'Связанный пол',
        kind: GroundFloorCalculationKind.slabOnGround,
        constructionId: 'floor-main',
        areaSquareMeters: 16,
        perimeterMeters: 16,
        slabWidthMeters: 4,
        slabLengthMeters: 4,
        edgeInsulationWidthMeters: 0.6,
        edgeInsulationResistance: 1.5,
        houseElementId: 'auto-floor-room-main',
      ),
    );

    final updated = service.deleteEnvelopeElement(project, 'auto-floor-room-main');

    expect(updated.groundFloorCalculations.single.houseElementId, isNull);
  });

  test('updateEnvelopeWallPlacement updates derived area', () {
    final project = buildTestProject();
    final sourceWall = project.houseModel.elements.firstWhere(
      (item) =>
          item.elementKind == ConstructionElementKind.wall &&
          item.lineSegment != null &&
          item.lineSegment!.startYMeters == 0 &&
          item.lineSegment!.endYMeters == 0,
    );

    final updated = service.updateEnvelopeWallPlacement(
      project,
      sourceWall.id,
      buildWallPlacement(
        side: RoomSide.right,
        offsetMeters: 1,
        lengthMeters: 2.5,
      ),
    );
    final editedWall = updated.houseModel.elements.firstWhere(
      (item) => item.id == sourceWall.id,
    );

    expect(editedWall.wallPlacement?.side, RoomSide.right);
    expect(editedWall.areaSquareMeters, 6.75);
  });

  test('updateRoomLayout rebuilds auto walls for new room size', () {
    final project = buildTestProject();
    final updated = service.updateRoomLayout(
      project,
      defaultRoomId,
      buildRoomLayout(widthMeters: 3, heightMeters: 4),
    );
    final topWall = updated.houseModel.elements.firstWhere(
      (item) =>
          item.elementKind == ConstructionElementKind.wall &&
          item.lineSegment != null &&
          item.lineSegment!.startYMeters == 0 &&
          item.lineSegment!.endYMeters == 0,
    );

    expect(topWall.lineSegment!.lengthMeters, 3);
    expect(topWall.areaSquareMeters, 3 * defaultRoomHeightMeters);
  });

  test('updateRoomLayout rejects negative coordinates', () {
    final project = buildTestProject();

    expect(
      () => service.updateRoomLayout(
        project,
        defaultRoomId,
        buildRoomLayout(xMeters: -0.5),
      ),
      throwsStateError,
    );
  });

  test('addRoomCell expands room directly on grid without temporary room', () {
    final project = buildTestProject();

    final updated = service.addRoomCell(
      project,
      defaultRoomId,
      const RoomLayoutRect(
        xMeters: 4,
        yMeters: 0,
        widthMeters: roomLayoutSnapStepMeters,
        heightMeters: roomLayoutSnapStepMeters,
      ),
    );

    expect(updated.houseModel.rooms.single.areaSquareMeters, 16.25);
    expect(updated.houseModel.rooms.single.effectiveCells, hasLength(65));
  });

  test('removeRoomCell shrinks multi-cell room and keeps it connected', () {
    final project = buildTestProject(
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
    );

    final updated = service.removeRoomCell(
      project,
      defaultRoomId,
      const RoomLayoutRect(
        xMeters: 1.0,
        yMeters: 0,
        widthMeters: roomLayoutSnapStepMeters,
        heightMeters: roomLayoutSnapStepMeters,
      ),
    );

    expect(updated.houseModel.rooms.single.effectiveCells, hasLength(2));
    expect(updated.houseModel.rooms.single.layout.widthMeters, 1.0);
  });

  test('removeRoomCell rejects disconnecting composite room', () {
    final project = buildTestProject(
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
    );

    expect(
      () => service.removeRoomCell(
        project,
        defaultRoomId,
        const RoomLayoutRect(
          xMeters: 0.5,
          yMeters: 0,
          widthMeters: roomLayoutSnapStepMeters,
          heightMeters: roomLayoutSnapStepMeters,
        ),
      ),
      throwsStateError,
    );
  });

  test('removeRoomCell rejects creating internal hole', () {
    final project = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Дом',
        rooms: [
          buildRoom(
            cells: const [
              RoomLayoutRect(
                xMeters: 0,
                yMeters: 0,
                widthMeters: 1.5,
                heightMeters: 1.5,
              ),
            ],
          ),
        ],
        elements: const [],
        openings: const [],
      ),
    );

    expect(
      () => service.removeRoomCell(
        project,
        defaultRoomId,
        const RoomLayoutRect(
          xMeters: 0.5,
          yMeters: 0.5,
          widthMeters: roomLayoutSnapStepMeters,
          heightMeters: roomLayoutSnapStepMeters,
        ),
      ),
      throwsStateError,
    );
  });

  test(
    'addRoomCell preserves opening-bound wall id when segment stays unique',
    () {
      final project = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Дом',
          rooms: [Room.defaultRoom()],
          elements: HouseModel.bootstrapFromConstructions([
            buildWallConstruction(),
          ]).elements,
          openings: const [
            EnvelopeOpening(
              id: 'opening-window',
              elementId: 'wall-room-main-0_0-0_0-4_0-0_0',
              title: 'Окно',
              kind: OpeningKind.window,
              areaSquareMeters: 2,
              heatTransferCoefficient: 1.0,
            ),
          ],
        ),
      );

      final updated = service.addRoomCell(
        project,
        defaultRoomId,
        const RoomLayoutRect(
          xMeters: 4,
          yMeters: 3.5,
          widthMeters: roomLayoutSnapStepMeters,
          heightMeters: roomLayoutSnapStepMeters,
        ),
      );

      expect(
        updated.houseModel.elements.any(
          (item) => item.id == 'wall-room-main-0_0-0_0-4_0-0_0',
        ),
        isTrue,
      );
      expect(
        updated.houseModel.openings.single.elementId,
        'wall-room-main-0_0-0_0-4_0-0_0',
      );
    },
  );

  test('deleteEnvelopeElement also removes linked openings', () {
    final project = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Конструктор дома',
        rooms: [Room.defaultRoom()],
        elements: [
          HouseEnvelopeElement(
            id: 'element-wall',
            roomId: defaultRoomId,
            title: 'Стена',
            elementKind: ConstructionElementKind.wall,
            areaSquareMeters: 10.8,
            constructionId: 'wall',
            wallPlacement: buildWallPlacement(lengthMeters: 4),
          ),
        ],
        openings: const [
          EnvelopeOpening(
            id: 'opening-window',
            elementId: 'element-wall',
            title: 'Окно',
            kind: OpeningKind.window,
            areaSquareMeters: 2,
            heatTransferCoefficient: 1.0,
          ),
        ],
      ),
    );

    final updated = service.deleteEnvelopeElement(project, 'element-wall');

    expect(updated.houseModel.elements, isEmpty);
    expect(updated.houseModel.openings, isEmpty);
  });

  test('addOpening rejects opening area larger than element area', () {
    final project = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Конструктор дома',
        rooms: [Room.defaultRoom()],
        elements: [
          HouseEnvelopeElement(
            id: 'element-wall',
            roomId: defaultRoomId,
            title: 'Стена',
            elementKind: ConstructionElementKind.wall,
            areaSquareMeters: 5,
            constructionId: 'wall',
            wallPlacement: buildWallPlacement(
              lengthMeters: 5 / defaultRoomHeightMeters,
            ),
          ),
        ],
        openings: const [],
      ),
    );

    expect(
      () => service.addOpening(
        project,
        const EnvelopeOpening(
          id: 'opening-window',
          elementId: 'element-wall',
          title: 'Панорамное окно',
          kind: OpeningKind.window,
          areaSquareMeters: 6,
          heatTransferCoefficient: 1.0,
        ),
      ),
      throwsStateError,
    );
  });

  test(
    'updateEnvelopeElement rejects shrinking wall segment below linked openings',
    () {
      final project = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Конструктор дома',
          rooms: [Room.defaultRoom()],
          elements: [
            HouseEnvelopeElement(
              id: 'element-wall',
              roomId: defaultRoomId,
              title: 'Стена',
              elementKind: ConstructionElementKind.wall,
              areaSquareMeters: 10,
              constructionId: 'wall',
              wallPlacement: buildWallPlacement(
                lengthMeters: 10 / defaultRoomHeightMeters,
              ),
            ),
          ],
          openings: const [
            EnvelopeOpening(
              id: 'opening-window',
              elementId: 'element-wall',
              title: 'Окно',
              kind: OpeningKind.window,
              areaSquareMeters: 4,
              heatTransferCoefficient: 1.0,
            ),
          ],
        ),
      );

      expect(
        () => service.updateEnvelopeElement(
          project,
          project.houseModel.elements.single.copyWith(
            wallPlacement: buildWallPlacement(lengthMeters: 1.0),
          ),
        ),
        throwsStateError,
      );
    },
  );

  test('updateEnvelopeWallPlacement rejects segment outside room side', () {
    final project = buildTestProject();
    final sourceWall = project.houseModel.elements.firstWhere(
      (item) =>
          item.elementKind == ConstructionElementKind.wall &&
          item.lineSegment != null &&
          item.lineSegment!.startYMeters == 0 &&
          item.lineSegment!.endYMeters == 0,
    );

    expect(
      () => service.updateEnvelopeWallPlacement(
        project,
        sourceWall.id,
        buildWallPlacement(offsetMeters: 1.5, lengthMeters: 3),
      ),
      throwsStateError,
    );
  });

  test('mergeRoomsAcrossPartition combines adjacent rooms into one room', () {
    final project = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Дом',
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
            heightMeters: 3.2,
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
    );

    final updated = service.mergeRoomsAcrossPartition(
      project,
      'room-a',
      'room-b',
    );

    expect(updated.houseModel.rooms, hasLength(1));
    final mergedRoom = updated.houseModel.rooms.single;
    expect(mergedRoom.id, 'room-a');
    expect(mergedRoom.heightMeters, defaultRoomHeightMeters);
    expect(mergedRoom.effectiveCells, hasLength(2));
    expect(mergedRoom.areaSquareMeters, 24);
    expect(
      updated.houseModel.elements.where(
        (item) => item.elementKind == ConstructionElementKind.wall,
      ),
      hasLength(4),
    );
  });

  test('splitExteriorWallSegment creates two auto wall spans', () {
    final project = buildTestProject();
    final topWall = project.houseModel.elements.firstWhere(
      (item) =>
          item.elementKind == ConstructionElementKind.wall &&
          item.lineSegment != null &&
          item.lineSegment!.startYMeters == 0 &&
          item.lineSegment!.endYMeters == 0,
    );

    final updated = service.splitExteriorWallSegment(project, topWall.id, 1.5);
    final splitWalls = updated.houseModel.elements
        .where(
          (item) =>
              item.elementKind == ConstructionElementKind.wall &&
              item.roomId == defaultRoomId &&
              item.lineSegment != null &&
              item.lineSegment!.startYMeters == 0 &&
              item.lineSegment!.endYMeters == 0,
        )
        .toList(growable: false);

    expect(splitWalls, hasLength(2));
    expect(
      splitWalls.fold<double>(
        0,
        (sum, item) => sum + item.lineSegment!.lengthMeters,
      ),
      closeTo(4, 0.0001),
    );
  });

  test('deleteRoom rejects removal when heating devices still linked', () {
    final project = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Дом',
        rooms: const [
          Room(
            id: 'room-a',
            title: 'Комната A',
            kind: RoomKind.livingRoom,
            heightMeters: defaultRoomHeightMeters,
            layout: RoomLayoutRect(
              xMeters: 0,
              yMeters: 0,
              widthMeters: 4,
              heightMeters: 4,
            ),
          ),
          Room(
            id: 'room-b',
            title: 'Комната B',
            kind: RoomKind.bedroom,
            heightMeters: defaultRoomHeightMeters,
            layout: RoomLayoutRect(
              xMeters: 5,
              yMeters: 0,
              widthMeters: 4,
              heightMeters: 4,
            ),
          ),
        ],
        elements: const [],
        openings: const [],
        heatingDevices: [buildHeatingDevice(id: 'device-a', roomId: 'room-a')],
      ),
    );

    expect(() => service.deleteRoom(project, 'room-a'), throwsStateError);
  });

  test('add, update and delete heating device persists room binding', () {
    final initialProject = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Дом',
        rooms: const [
          Room(
            id: 'room-a',
            title: 'Комната A',
            kind: RoomKind.livingRoom,
            heightMeters: defaultRoomHeightMeters,
            layout: RoomLayoutRect(
              xMeters: 0,
              yMeters: 0,
              widthMeters: 4,
              heightMeters: 4,
            ),
          ),
          Room(
            id: 'room-b',
            title: 'Комната B',
            kind: RoomKind.bedroom,
            heightMeters: defaultRoomHeightMeters,
            layout: RoomLayoutRect(
              xMeters: 5,
              yMeters: 0,
              widthMeters: 4,
              heightMeters: 4,
            ),
          ),
        ],
        elements: const [],
        openings: const [],
        heatingDevices: const [],
      ),
    );

    final withDevice = service.addHeatingDevice(
      initialProject,
      buildHeatingDevice(
        id: 'device-a',
        roomId: 'room-a',
        ratedPowerWatts: 1200,
      ),
    );
    expect(withDevice.houseModel.heatingDevices.single.roomId, 'room-a');
    expect(withDevice.houseModel.heatingDevices.single.ratedPowerWatts, 1200);

    final updated = service.updateHeatingDevice(
      withDevice,
      withDevice.houseModel.heatingDevices.single.copyWith(
        roomId: 'room-b',
        ratedPowerWatts: 1600,
      ),
    );
    expect(updated.houseModel.heatingDevices.single.roomId, 'room-b');
    expect(updated.houseModel.heatingDevices.single.ratedPowerWatts, 1600);

    final withoutDevice = service.deleteHeatingDevice(updated, 'device-a');
    expect(withoutDevice.houseModel.heatingDevices, isEmpty);
  });
}
