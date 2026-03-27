import '../models/project.dart';

class ProjectEditingService {
  const ProjectEditingService();

  Project addRoom(Project project, Room room) {
    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        rooms: [...project.houseModel.rooms, room],
      ),
    );
  }

  Project updateRoom(Project project, Room room) {
    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        rooms: [
          for (final item in project.houseModel.rooms)
            if (item.id == room.id) room else item,
        ],
      ),
    );
  }

  Project deleteRoom(Project project, String roomId) {
    final linkedElements = project.houseModel.elements
        .where((item) => item.roomId == roomId)
        .length;
    if (linkedElements > 0) {
      throw StateError(
        'Нельзя удалить помещение, пока в нем есть ограждающие элементы.',
      );
    }
    if (project.houseModel.rooms.length <= 1) {
      throw StateError('В проекте должно остаться хотя бы одно помещение.');
    }

    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        rooms: [
          for (final item in project.houseModel.rooms)
            if (item.id != roomId) item,
        ],
      ),
    );
  }

  Project addEnvelopeElement(Project project, HouseEnvelopeElement element) {
    _ensureRoomExists(project, element.roomId);
    _ensureConstructionExists(project, element.constructionId);

    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        elements: [...project.houseModel.elements, element],
      ),
    );
  }

  Project updateEnvelopeElement(Project project, HouseEnvelopeElement element) {
    _ensureRoomExists(project, element.roomId);
    _ensureConstructionExists(project, element.constructionId);

    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        elements: [
          for (final item in project.houseModel.elements)
            if (item.id == element.id) element else item,
        ],
      ),
    );
  }

  Project deleteEnvelopeElement(Project project, String elementId) {
    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        elements: [
          for (final item in project.houseModel.elements)
            if (item.id != elementId) item,
        ],
      ),
    );
  }

  Project addConstruction(Project project, Construction construction) {
    return project.copyWith(
      constructions: [...project.constructions, construction],
    );
  }

  Project updateConstruction(Project project, Construction construction) {
    return project.copyWith(
      constructions: [
        for (final item in project.constructions)
          if (item.id == construction.id) construction else item,
      ],
      houseModel: project.houseModel.copyWith(
        elements: [
          for (final element in project.houseModel.elements)
            if (element.constructionId == construction.id)
              element.copyWith(
                title: element.title,
                elementKind: construction.elementKind,
              )
            else
              element,
        ],
      ),
    );
  }

  Project deleteConstruction(Project project, String constructionId) {
    final inUse = project.houseModel.elements.any(
      (item) => item.constructionId == constructionId,
    );
    if (inUse) {
      throw StateError(
        'Нельзя удалить конструкцию, пока она используется в ограждениях.',
      );
    }
    if (project.constructions.length <= 1) {
      throw StateError('В проекте должна остаться хотя бы одна конструкция.');
    }

    return project.copyWith(
      constructions: [
        for (final item in project.constructions)
          if (item.id != constructionId) item,
      ],
    );
  }

  void _ensureRoomExists(Project project, String roomId) {
    final exists = project.houseModel.rooms.any((item) => item.id == roomId);
    if (!exists) {
      throw StateError('Помещение $roomId не найдено в проекте.');
    }
  }

  void _ensureConstructionExists(Project project, String constructionId) {
    final exists = project.constructions.any((item) => item.id == constructionId);
    if (!exists) {
      throw StateError('Конструкция $constructionId не найдена в проекте.');
    }
  }
}
