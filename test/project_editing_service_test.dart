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

    expect(updated.houseModel.elements.single.areaSquareMeters, closeTo(12.4, 0.001));
  });

  test('updateEnvelopeWallPlacement updates derived area', () {
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

    expect(updated.houseModel.elements.single.wallPlacement?.side, RoomSide.right);
    expect(updated.houseModel.elements.single.areaSquareMeters, 6.75);
  });

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
            wallPlacement: buildWallPlacement(lengthMeters: 5 / defaultRoomHeightMeters),
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
}
