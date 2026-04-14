import '../models/project.dart';

class ProjectEditingService {
  const ProjectEditingService();

  Project addRoom(Project project, Room room) {
    _validateRoomLayout(project.houseModel.rooms, room);
    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        rooms: [...project.houseModel.rooms, room],
      ),
    );
  }

  Project updateRoom(Project project, Room room) {
    _ensureRoomExists(project, room.id);
    final updatedRooms = [
      for (final item in project.houseModel.rooms)
        if (item.id == room.id) room else item,
    ];
    _validateRoomLayout(updatedRooms, room, roomId: room.id);
    return _syncElementsForRooms(
      project.copyWith(
        houseModel: project.houseModel.copyWith(rooms: updatedRooms),
      ),
    );
  }

  Project updateRoomLayout(
    Project project,
    String roomId,
    RoomLayoutRect layout,
  ) {
    _ensureRoomExists(project, roomId);
    final updatedRooms = [
      for (final item in project.houseModel.rooms)
        if (item.id == roomId) item.copyWith(layout: layout) else item,
    ];
    final updatedRoom = updatedRooms.firstWhere((item) => item.id == roomId);
    _validateRoomLayout(updatedRooms, updatedRoom, roomId: roomId);
    return _syncElementsForRooms(
      project.copyWith(
        houseModel: project.houseModel.copyWith(rooms: updatedRooms),
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
    final linkedHeatingDevices = project.houseModel.heatingDevices
        .where((item) => item.roomId == roomId)
        .length;
    if (linkedHeatingDevices > 0) {
      throw StateError(
        'Нельзя удалить помещение, пока в нем есть отопительные приборы.',
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
    final normalized = _normalizeElement(project, element);
    final updatedProject = project.copyWith(
      houseModel: project.houseModel.copyWith(
        elements: [...project.houseModel.elements, normalized],
      ),
    );
    _ensureAllOpeningsFit(updatedProject);
    return updatedProject;
  }

  Project updateEnvelopeElement(Project project, HouseEnvelopeElement element) {
    final normalized = _normalizeElement(project, element);
    final updatedProject = project.copyWith(
      houseModel: project.houseModel.copyWith(
        elements: [
          for (final item in project.houseModel.elements)
            if (item.id == normalized.id) normalized else item,
        ],
      ),
    );
    _ensureAllOpeningsFit(updatedProject);
    return updatedProject;
  }

  Project updateEnvelopeWallPlacement(
    Project project,
    String elementId,
    EnvelopeWallPlacement wallPlacement,
  ) {
    final element = project.houseModel.elements.firstWhere(
      (item) => item.id == elementId,
    );
    return updateEnvelopeElement(
      project,
      element.copyWith(wallPlacement: wallPlacement),
    );
  }

  Project deleteEnvelopeElement(Project project, String elementId) {
    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        elements: [
          for (final item in project.houseModel.elements)
            if (item.id != elementId) item,
        ],
        openings: [
          for (final item in project.houseModel.openings)
            if (item.elementId != elementId) item,
        ],
      ),
    );
  }

  Project addOpening(Project project, EnvelopeOpening opening) {
    _ensureElementExists(project, opening.elementId);
    _ensureOpeningFitsElement(project, opening);

    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        openings: [...project.houseModel.openings, opening],
      ),
    );
  }

  Project updateOpening(Project project, EnvelopeOpening opening) {
    _ensureElementExists(project, opening.elementId);
    _ensureOpeningFitsElement(project, opening);

    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        openings: [
          for (final item in project.houseModel.openings)
            if (item.id == opening.id) opening else item,
        ],
      ),
    );
  }

  Project deleteOpening(Project project, String openingId) {
    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        openings: [
          for (final item in project.houseModel.openings)
            if (item.id != openingId) item,
        ],
      ),
    );
  }

  Project addHeatingDevice(Project project, HeatingDevice device) {
    final normalized = _normalizeHeatingDevice(project, device);
    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        heatingDevices: [...project.houseModel.heatingDevices, normalized],
      ),
    );
  }

  Project updateHeatingDevice(Project project, HeatingDevice device) {
    _ensureHeatingDeviceExists(project, device.id);
    final normalized = _normalizeHeatingDevice(project, device);
    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        heatingDevices: [
          for (final item in project.houseModel.heatingDevices)
            if (item.id == normalized.id) normalized else item,
        ],
      ),
    );
  }

  Project deleteHeatingDevice(Project project, String heatingDeviceId) {
    _ensureHeatingDeviceExists(project, heatingDeviceId);
    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        heatingDevices: [
          for (final item in project.houseModel.heatingDevices)
            if (item.id != heatingDeviceId) item,
        ],
      ),
    );
  }

  Project addConstruction(Project project, Construction construction) {
    final selections = project.effectiveProjectConstructionSelections;
    return project.copyWith(
      constructions: [...project.constructions, construction],
      selectedConstructionIds: [
        ...project.effectiveSelectedConstructionIds,
        construction.id,
      ],
      projectConstructionSelections: [
        ...selections,
        ProjectConstructionSelection(constructionId: construction.id),
      ],
    );
  }

  Project updateConstruction(Project project, Construction construction) {
    return project.copyWith(
      constructions: [
        for (final item in project.constructions)
          if (item.id == construction.id) construction else item,
      ],
    );
  }

  Project deleteConstruction(Project project, String constructionId) {
    if (project.constructions.length <= 1) {
      throw StateError('В проекте должна остаться хотя бы одна конструкция.');
    }

    return project.copyWith(
      constructions: [
        for (final item in project.constructions)
          if (item.id != constructionId) item,
      ],
      selectedConstructionIds: [
        for (final item in project.effectiveSelectedConstructionIds)
          if (item != constructionId) item,
      ],
      projectConstructionSelections: [
        for (final item in project.effectiveProjectConstructionSelections)
          if (item.constructionId != constructionId) item,
      ],
    );
  }

  Project selectConstruction(Project project, Construction construction) {
    if (project.effectiveSelectedConstructionIds.contains(construction.id)) {
      return includeConstructionInCalculation(project, construction.id);
    }
    final existsInProject = project.constructions.any(
      (item) => item.id == construction.id,
    );
    return project.copyWith(
      constructions: existsInProject
          ? project.constructions
          : [...project.constructions, construction],
      selectedConstructionIds: [
        ...project.effectiveSelectedConstructionIds,
        construction.id,
      ],
      projectConstructionSelections: [
        ...project.effectiveProjectConstructionSelections,
        ProjectConstructionSelection(constructionId: construction.id),
      ],
    );
  }

  Project excludeConstructionFromCalculation(
    Project project,
    String constructionId,
  ) {
    final selections = project.effectiveProjectConstructionSelections;
    final hasSelection = selections.any(
      (item) => item.constructionId == constructionId,
    );
    if (!hasSelection) {
      return project;
    }
    return project.copyWith(
      projectConstructionSelections: [
        for (final item in selections)
          if (item.constructionId == constructionId)
            item.copyWith(includedInCalculation: false)
          else
            item,
      ],
    );
  }

  Project includeConstructionInCalculation(
    Project project,
    String constructionId,
  ) {
    final selections = project.effectiveProjectConstructionSelections;
    final hasSelection = selections.any(
      (item) => item.constructionId == constructionId,
    );
    if (!hasSelection) {
      return project;
    }
    return project.copyWith(
      projectConstructionSelections: [
        for (final item in selections)
          if (item.constructionId == constructionId)
            item.copyWith(includedInCalculation: true)
          else
            item,
      ],
    );
  }

  Project unselectConstruction(Project project, String constructionId) {
    final isUsedByGroundFloor = project.groundFloorCalculations.any(
      (item) => item.constructionId == constructionId,
    );
    if (isUsedByGroundFloor) {
      throw StateError(
        'Нельзя убрать конструкцию из проекта, пока она используется в расчете пола по грунту.',
      );
    }
    final selectedIds = project.effectiveSelectedConstructionIds;
    if (selectedIds.length <= 1) {
      throw StateError('В проекте должна остаться хотя бы одна конструкция.');
    }
    return project.copyWith(
      constructions: [
        for (final item in project.constructions)
          if (item.id != constructionId) item,
      ],
      selectedConstructionIds: [
        for (final item in selectedIds)
          if (item != constructionId) item,
      ],
      projectConstructionSelections: [
        for (final item in project.effectiveProjectConstructionSelections)
          if (item.constructionId != constructionId) item,
      ],
    );
  }

  Project _syncElementsForRooms(Project project) {
    final updatedProject = project.copyWith(
      houseModel: project.houseModel.copyWith(
        elements: [
          for (final element in project.houseModel.elements)
            _normalizeElement(project, element),
        ],
      ),
    );
    _ensureAllOpeningsFit(updatedProject);
    return updatedProject;
  }

  HouseEnvelopeElement _normalizeElement(
    Project project,
    HouseEnvelopeElement element,
  ) {
    _ensureRoomExists(project, element.roomId);
    final construction = element.construction;
    final effectiveKind = construction.elementKind;
    final room = project.houseModel.rooms.firstWhere(
      (item) => item.id == element.roomId,
    );

    if (effectiveKind != ConstructionElementKind.wall) {
      return element.copyWith(
        construction: construction.copyWith(elementKind: effectiveKind),
        elementKind: effectiveKind,
        clearWallOrientation: true,
        clearWallPlacement: true,
      );
    }

    if (element.wallOrientation == null) {
      throw StateError('Для наружной стены нужно указать ориентацию.');
    }
    if (element.areaSquareMeters <= 0) {
      throw StateError('Площадь стены должна быть больше нуля.');
    }
    final placement = element.wallPlacement;
    if (placement != null) {
      _ensureWallPlacementFitsRoom(room, placement);
    }
    return element.copyWith(
      construction: construction.copyWith(elementKind: effectiveKind),
      elementKind: effectiveKind,
      areaSquareMeters: element.areaSquareMeters,
      wallOrientation: element.wallOrientation,
      wallPlacement: placement,
    );
  }

  void _validateRoomLayout(List<Room> rooms, Room room, {String? roomId}) {
    final layout = room.layout;
    if (layout.xMeters < 0 || layout.yMeters < 0) {
      throw StateError('Комната не может выходить в отрицательные координаты.');
    }
    if (layout.widthMeters < minimumRoomLayoutDimensionMeters ||
        layout.heightMeters < minimumRoomLayoutDimensionMeters) {
      throw StateError(
        'Размер комнаты не может быть меньше '
        '${minimumRoomLayoutDimensionMeters.toStringAsFixed(1)} м.',
      );
    }

    for (final other in rooms) {
      if (other.id == roomId || other.id == room.id) {
        continue;
      }
      if (_rectanglesOverlap(layout, other.layout)) {
        throw StateError(
          'Комнаты не должны пересекаться на плане: '
          '${room.title} и ${other.title}.',
        );
      }
    }
  }

  bool _rectanglesOverlap(RoomLayoutRect left, RoomLayoutRect right) {
    return left.xMeters < right.rightMeters &&
        left.rightMeters > right.xMeters &&
        left.yMeters < right.bottomMeters &&
        left.bottomMeters > right.yMeters;
  }

  void _ensureRoomExists(Project project, String roomId) {
    final exists = project.houseModel.rooms.any((item) => item.id == roomId);
    if (!exists) {
      throw StateError('Помещение $roomId не найдено в проекте.');
    }
  }

  void _ensureElementExists(Project project, String elementId) {
    final exists = project.houseModel.elements.any(
      (item) => item.id == elementId,
    );
    if (!exists) {
      throw StateError('Ограждение $elementId не найдено в проекте.');
    }
  }

  void _ensureHeatingDeviceExists(Project project, String heatingDeviceId) {
    final exists = project.houseModel.heatingDevices.any(
      (item) => item.id == heatingDeviceId,
    );
    if (!exists) {
      throw StateError(
        'Отопительный прибор $heatingDeviceId не найден в проекте.',
      );
    }
  }

  void _ensureWallPlacementFitsRoom(
    Room room,
    EnvelopeWallPlacement placement,
  ) {
    if (placement.offsetMeters < 0) {
      throw StateError(
        'Смещение стены по стороне не может быть отрицательным.',
      );
    }
    if (placement.lengthMeters < roomLayoutSnapStepMeters) {
      throw StateError(
        'Длина сегмента стены должна быть не меньше '
        '${roomLayoutSnapStepMeters.toStringAsFixed(1)} м.',
      );
    }
    final sideLength = room.layout.sideLength(placement.side);
    if (placement.endMeters > sideLength + 0.0001) {
      throw StateError(
        'Сегмент стены выходит за пределы стороны комнаты ${room.title}.',
      );
    }
  }

  void _ensureAllOpeningsFit(Project project) {
    for (final element in project.houseModel.elements) {
      _ensureElementOpeningsFitArea(project, element);
    }
  }

  void _ensureElementOpeningsFitArea(
    Project project,
    HouseEnvelopeElement element,
  ) {
    final openingsArea = project.houseModel.openings
        .where((item) => item.elementId == element.id)
        .fold<double>(0, (sum, item) => sum + item.areaSquareMeters);
    if (openingsArea > element.areaSquareMeters) {
      throw StateError(
        'Площадь проемов (${openingsArea.toStringAsFixed(1)} м²) не может '
        'превышать площадь ограждения '
        '(${element.areaSquareMeters.toStringAsFixed(1)} м²).',
      );
    }
  }

  void _ensureOpeningFitsElement(Project project, EnvelopeOpening opening) {
    final element = project.houseModel.elements.firstWhere(
      (item) => item.id == opening.elementId,
    );
    final otherOpeningsArea = project.houseModel.openings
        .where(
          (item) =>
              item.elementId == opening.elementId && item.id != opening.id,
        )
        .fold<double>(0, (sum, item) => sum + item.areaSquareMeters);
    final totalArea = otherOpeningsArea + opening.areaSquareMeters;
    if (totalArea > element.areaSquareMeters) {
      throw StateError(
        'Суммарная площадь проемов (${totalArea.toStringAsFixed(1)} м²) не '
        'может превышать площадь ограждения '
        '(${element.areaSquareMeters.toStringAsFixed(1)} м²).',
      );
    }
  }

  HeatingDevice _normalizeHeatingDevice(Project project, HeatingDevice device) {
    _ensureRoomExists(project, device.roomId);
    if (device.ratedPowerWatts <= 0) {
      throw StateError('Тепловая мощность прибора должна быть больше нуля.');
    }
    return device;
  }
}
