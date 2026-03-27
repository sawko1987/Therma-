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
      const Room(
        id: 'room-bedroom',
        title: 'Спальня',
        kind: RoomKind.bedroom,
        areaSquareMeters: 16,
        heightMeters: 2.7,
      ),
    );

    expect(updated.houseModel.rooms, hasLength(2));
    expect(updated.houseModel.rooms.last.title, 'Спальня');
  });

  test('deleteRoom rejects removal when envelope elements still linked', () {
    final project = buildTestProject();

    expect(
      () => service.deleteRoom(project, project.houseModel.rooms.first.id),
      throwsStateError,
    );
  });

  test('deleteConstruction rejects removal when construction is still in use', () {
    final project = buildTestProject();

    expect(
      () =>
          service.deleteConstruction(project, project.constructions.first.id),
      throwsStateError,
    );
  });

  test('updateEnvelopeElement rebinds element to another room and construction', () {
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
        rooms: const [
          Room(
            id: 'room-living',
            title: 'Гостиная',
            kind: RoomKind.livingRoom,
            areaSquareMeters: 20,
            heightMeters: 2.7,
          ),
          Room(
            id: 'room-attic',
            title: 'Мансарда',
            kind: RoomKind.bedroom,
            areaSquareMeters: 14,
            heightMeters: 2.5,
          ),
        ],
        elements: const [
          HouseEnvelopeElement(
            id: 'element-wall',
            roomId: 'room-living',
            title: 'Стена гостиной',
            elementKind: ConstructionElementKind.wall,
            areaSquareMeters: 24,
            constructionId: 'wall',
          ),
        ],
      ),
    ).copyWith(constructions: [firstConstruction, secondConstruction]);

    final updated = service.updateEnvelopeElement(
      project,
      project.houseModel.elements.single.copyWith(
        roomId: 'room-attic',
        constructionId: 'roof',
        elementKind: ConstructionElementKind.roof,
      ),
    );

    expect(updated.houseModel.elements.single.roomId, 'room-attic');
    expect(updated.houseModel.elements.single.constructionId, 'roof');
    expect(updated.houseModel.elements.single.elementKind, ConstructionElementKind.roof);
  });
}
