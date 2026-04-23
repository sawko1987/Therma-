import 'package:flutter_test/flutter_test.dart';
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
        layout: buildRoomLayout(xMeters: 5, yMeters: 0),
      ),
    );

    expect(updated.houseModel.rooms, hasLength(2));
    expect(updated.houseModel.rooms.last.title, 'Спальня');
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

  test('deleteConstruction allows removing the last construction', () {
    final project = buildTestProject();

    final updated = service.deleteConstruction(
      project,
      project.constructions.first.id,
    );

    expect(updated.constructions, isEmpty);
    expect(updated.effectiveSelectedConstructionIds, isEmpty);
    expect(updated.effectiveProjectConstructionSelections, isEmpty);
  });

  test('unselectConstruction allows removing the last construction', () {
    final project = buildTestProject();

    final updated = service.unselectConstruction(
      project,
      project.constructions.first.id,
    );

    expect(updated.constructions, isEmpty);
    expect(updated.effectiveSelectedConstructionIds, isEmpty);
    expect(updated.effectiveProjectConstructionSelections, isEmpty);
  });

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
            buildEnvelopeElement(
              id: 'element-wall',
              roomId: 'room-living',
              title: 'Стена гостиной',
              areaSquareMeters: 10.8,
              construction: firstConstruction,
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
          construction: secondConstruction,
          sourceConstructionId: 'roof',
          sourceConstructionTitle: secondConstruction.title,
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

  test(
    'updateRoom recomputes wall area from stored segment after height change',
    () {
      final project = buildTestProject();

      final updated = service.updateRoom(
        project,
        project.houseModel.rooms.single.copyWith(heightMeters: 3.1),
      );

      expect(updated.houseModel.elements.single.areaSquareMeters, 10.85);
    },
  );

  test(
    'updateEnvelopeWallPlacement updates derived wall area and changes placement',
    () {
      final project = buildTestProject();

      final updated = service.updateEnvelopeWallPlacement(
        project,
        project.houseModel.elements.single.id,
        buildWallPlacement(
          side: RoomSide.right,
          offsetMeters: 1,
          lengthMeters: 2.5,
        ),
      );

      expect(
        updated.houseModel.elements.single.wallPlacement?.side,
        RoomSide.right,
      );
      expect(updated.houseModel.elements.single.wallPlacement?.offsetMeters, 1);
      expect(updated.houseModel.elements.single.areaSquareMeters, 6.75);
    },
  );

  test('updateRoomLayout rejects when wall no longer fits side', () {
    final project = buildTestProject();

    expect(
      () => service.updateRoomLayout(
        project,
        defaultRoomId,
        buildRoomLayout(widthMeters: 3, heightMeters: 4),
      ),
      throwsStateError,
    );
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

  test('deleteEnvelopeElement also removes linked openings', () {
    final project = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Конструктор дома',
        rooms: [Room.defaultRoom()],
        elements: [
          buildEnvelopeElement(
            id: 'element-wall',
            title: 'Стена',
            areaSquareMeters: 10.8,
            construction: buildWallConstruction(),
            wallPlacement: buildWallPlacement(lengthMeters: 4),
          ),
        ],
        openings: [
          buildOpening(
            id: 'opening-window',
            elementId: 'element-wall',
            title: 'Окно',
            widthMeters: 1,
            heightMeters: 2,
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
          buildEnvelopeElement(
            id: 'element-wall',
            title: 'Стена',
            areaSquareMeters: 5,
            construction: buildWallConstruction(),
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
        buildOpening(
          id: 'opening-window',
          elementId: 'element-wall',
          title: 'Панорамное окно',
          widthMeters: 2,
          heightMeters: 3,
          heatTransferCoefficient: 1.0,
        ),
      ),
      throwsStateError,
    );
  });

  test(
    'updateEnvelopeElement rejects shrinking wall area below linked openings',
    () {
      final project = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Конструктор дома',
          rooms: [Room.defaultRoom()],
          elements: [
            buildEnvelopeElement(
              id: 'element-wall',
              title: 'Стена',
              areaSquareMeters: 10,
              construction: buildWallConstruction(),
              wallPlacement: buildWallPlacement(
                lengthMeters: 10 / defaultRoomHeightMeters,
              ),
            ),
          ],
          openings: [
            buildOpening(
              id: 'opening-window',
              elementId: 'element-wall',
              title: 'Окно',
              widthMeters: 2,
              heightMeters: 2.1,
              heatTransferCoefficient: 1.0,
            ),
          ],
        ),
      );

      expect(
        () => service.updateEnvelopeElement(
          project,
          project.houseModel.elements.single.copyWith(areaSquareMeters: 3.5),
        ),
        throwsStateError,
      );
    },
  );

  test('updateEnvelopeWallPlacement rejects segment outside room side', () {
    final project = buildTestProject();

    expect(
      () => service.updateEnvelopeWallPlacement(
        project,
        project.houseModel.elements.single.id,
        buildWallPlacement(offsetMeters: 1.5, lengthMeters: 3),
      ),
      throwsStateError,
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
