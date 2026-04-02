import 'dart:math' as math;

import '../models/ground_floor_calculation.dart';
import '../models/project.dart';

class ProjectEditingService {
  const ProjectEditingService();

  String? validateRoomPlacement(
    Project project,
    Room room, {
    String? replacingRoomId,
  }) {
    try {
      final normalizedRoom = _normalizeRoom(room);
      final nextRooms = [
        for (final item in project.houseModel.rooms)
          if (item.id != replacingRoomId) item,
        normalizedRoom,
      ];
      _validateRooms(nextRooms);
      return null;
    } on StateError catch (error) {
      return error.message;
    }
  }

  Project configureRoomEnvelope(
    Project project, {
    required String roomId,
    String? floorConstructionId,
    String? topConstructionId,
  }) {
    _ensureRoomExists(project, roomId);
    if (floorConstructionId != null) {
      final floorConstruction = project.constructions.firstWhere(
        (item) => item.id == floorConstructionId,
        orElse: () =>
            throw StateError('Конструкция $floorConstructionId не найдена.'),
      );
      if (floorConstruction.elementKind != ConstructionElementKind.floor) {
        throw StateError('Для пола можно выбрать только конструкцию пола.');
      }
    }
    if (topConstructionId != null) {
      final topConstruction = project.constructions.firstWhere(
        (item) => item.id == topConstructionId,
        orElse: () =>
            throw StateError('Конструкция $topConstructionId не найдена.'),
      );
      if (topConstruction.elementKind != ConstructionElementKind.ceiling &&
          topConstruction.elementKind != ConstructionElementKind.roof) {
        throw StateError(
          'Для верхнего ограждения можно выбрать только перекрытие или кровлю.',
        );
      }
    }

    final room = project.houseModel.rooms.firstWhere(
      (item) => item.id == roomId,
    );
    final retainedElements = [
      for (final item in project.houseModel.elements)
        if (item.id != _autoFloorElementId(roomId) &&
            item.id != _autoTopElementId(roomId))
          item,
    ];
    final configuredElements = [
      ...retainedElements,
      if (floorConstructionId != null)
        _buildAutoRoomSurfaceElement(
          room: room,
          id: _autoFloorElementId(roomId),
          title: 'Пол ${room.title}',
          elementKind: ConstructionElementKind.floor,
          constructionId: floorConstructionId,
        ),
      if (topConstructionId != null)
        _buildAutoRoomSurfaceElement(
          room: room,
          id: _autoTopElementId(roomId),
          title: 'Верх ${room.title}',
          elementKind: project.constructions
              .firstWhere((item) => item.id == topConstructionId)
              .elementKind,
          constructionId: topConstructionId,
        ),
    ];
    return _syncProjectGeometry(
      project.copyWith(
        houseModel: project.houseModel.copyWith(elements: configuredElements),
      ),
    );
  }

  Project addRoom(Project project, Room room) {
    final normalizedRoom = _normalizeRoom(room);
    final updatedProject = project.copyWith(
      houseModel: project.houseModel.copyWith(
        rooms: [...project.houseModel.rooms, normalizedRoom],
      ),
    );
    return _syncProjectGeometry(updatedProject);
  }

  Project updateRoom(Project project, Room room) {
    _ensureRoomExists(project, room.id);
    final normalizedRoom = _normalizeRoom(room);
    final updatedProject = project.copyWith(
      houseModel: project.houseModel.copyWith(
        rooms: [
          for (final item in project.houseModel.rooms)
            if (item.id == room.id) normalizedRoom else item,
        ],
      ),
    );
    return _syncProjectGeometry(updatedProject);
  }

  Project updateRoomLayout(
    Project project,
    String roomId,
    RoomLayoutRect layout,
  ) {
    final room = project.houseModel.rooms.firstWhere(
      (item) => item.id == roomId,
    );
    if (room.effectiveCells.length != 1) {
      throw StateError(
        'Составное помещение нельзя менять как один прямоугольник. '
        'Используйте режим ячеек на плане.',
      );
    }
    return updateRoom(project, room.copyWith(cells: [layout], layout: layout));
  }

  Project addRoomCell(Project project, String roomId, RoomLayoutRect cell) {
    final room = project.houseModel.rooms.firstWhere(
      (item) => item.id == roomId,
    );
    final normalizedCell = _normalizeGridCell(cell);
    final existingCells = _explodeToGridCells(room.effectiveCells);
    if (_gridCellListContains(existingCells, normalizedCell)) {
      throw StateError('Ячейка уже входит в состав помещения.');
    }
    if (!_hasAdjacentCell(existingCells, normalizedCell)) {
      throw StateError(
        'Добавлять можно только соседнюю ячейку по общей стороне.',
      );
    }
    return updateRoom(
      project,
      room.copyWith(cells: [...existingCells, normalizedCell]),
    );
  }

  Project removeRoomCell(Project project, String roomId, RoomLayoutRect cell) {
    final room = project.houseModel.rooms.firstWhere(
      (item) => item.id == roomId,
    );
    final normalizedCell = _normalizeGridCell(cell);
    final existingCells = _explodeToGridCells(room.effectiveCells);
    if (!_gridCellListContains(existingCells, normalizedCell)) {
      throw StateError('Выбранная ячейка не принадлежит помещению.');
    }
    if (existingCells.length <= 1) {
      throw StateError('Нельзя удалить последнюю ячейку помещения.');
    }
    final reducedCells = [
      for (final item in existingCells)
        if (!_gridCellsEqual(item, normalizedCell)) item,
    ];
    return updateRoom(project, room.copyWith(cells: reducedCells));
  }

  Project updateInternalPartitionConstruction(
    Project project,
    String? constructionId,
  ) {
    if (constructionId != null) {
      final construction = project.constructions.firstWhere(
        (item) => item.id == constructionId,
        orElse: () =>
            throw StateError('Конструкция $constructionId не найдена.'),
      );
      if (construction.elementKind != ConstructionElementKind.wall) {
        throw StateError(
          'Для внутренней перегородки можно выбрать только стеновую конструкцию.',
        );
      }
    }
    return _syncInternalPartitionConstruction(
      project.copyWith(
        houseModel: project.houseModel.copyWith(
          internalPartitionConstructionId: constructionId,
          clearInternalPartitionConstructionId: constructionId == null,
        ),
      ),
    );
  }

  Project mergeRoomsAcrossPartition(
    Project project,
    String primaryRoomId,
    String secondaryRoomId,
  ) {
    if (primaryRoomId == secondaryRoomId) {
      throw StateError('Нужно выбрать две разные комнаты.');
    }
    final primaryRoom = project.houseModel.rooms.firstWhere(
      (item) => item.id == primaryRoomId,
    );
    final secondaryRoom = project.houseModel.rooms.firstWhere(
      (item) => item.id == secondaryRoomId,
    );
    if (!_roomsAreAdjacent(primaryRoom, secondaryRoom)) {
      throw StateError('Комнаты не имеют общей перегородки для объединения.');
    }

    final mergedRoom = primaryRoom.copyWith(
      cells: [...primaryRoom.effectiveCells, ...secondaryRoom.effectiveCells],
      layout: RoomLayoutRect.boundingBox([
        ...primaryRoom.effectiveCells,
        ...secondaryRoom.effectiveCells,
      ]),
    );

    final transferredElements = [
      for (final element in project.houseModel.elements)
        if (element.roomId == secondaryRoomId &&
            element.elementKind != ConstructionElementKind.wall &&
            !_isAutoRoomSurfaceElement(element))
          element.copyWith(roomId: primaryRoomId)
        else if (element.roomId != secondaryRoomId)
          element,
    ];
    final transferredHeatingDevices = [
      for (final device in project.houseModel.heatingDevices)
        if (device.roomId == secondaryRoomId)
          device.copyWith(roomId: primaryRoomId, notes: device.notes)
        else
          device,
    ];

    final updatedProject = project.copyWith(
      houseModel: project.houseModel.copyWith(
        rooms: [
          for (final room in project.houseModel.rooms)
            if (room.id == primaryRoomId)
              mergedRoom
            else if (room.id != secondaryRoomId)
              room,
        ],
        elements: transferredElements,
        heatingDevices: transferredHeatingDevices,
      ),
    );
    return _syncProjectGeometry(updatedProject);
  }

  Project deleteRoom(Project project, String roomId) {
    final roomElementIds = project.houseModel.elements
        .where((item) => item.roomId == roomId)
        .map((item) => item.id)
        .toSet();
    final linkedManualElements = project.houseModel.elements.where(
      (item) =>
          item.roomId == roomId &&
          item.elementKind != ConstructionElementKind.wall &&
          !_isAutoRoomSurfaceElement(item),
    );
    if (linkedManualElements.isNotEmpty) {
      throw StateError(
        'Нельзя удалить помещение, пока в нем есть ограждающие элементы.',
      );
    }
    final linkedOpenings = project.houseModel.openings.where(
      (item) => roomElementIds.contains(item.elementId),
    );
    if (linkedOpenings.isNotEmpty) {
      throw StateError(
        'Нельзя удалить помещение, пока на его стенах есть проёмы.',
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

    final updatedProject = project.copyWith(
      houseModel: project.houseModel.copyWith(
        rooms: [
          for (final item in project.houseModel.rooms)
            if (item.id != roomId) item,
        ],
        elements: [
          for (final item in project.houseModel.elements)
            if (item.roomId != roomId || !_isAutoRoomSurfaceElement(item)) item,
        ],
      ),
    );
    return _syncProjectGeometry(updatedProject);
  }

  Project addEnvelopeElement(Project project, HouseEnvelopeElement element) {
    final normalized = _normalizeElement(project, element);
    if (normalized.elementKind == ConstructionElementKind.wall &&
        normalized.source == EnvelopeElementSource.manual) {
      throw StateError(
        'Наружные стены теперь строятся автоматически по внешнему контуру помещения.',
      );
    }
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
    final room = project.houseModel.rooms.firstWhere(
      (item) => item.id == element.roomId,
    );
    return updateEnvelopeElement(
      project,
      element.copyWith(
        wallPlacement: wallPlacement,
        lineSegment: _lineSegmentForWallPlacement(room, wallPlacement),
      ),
    );
  }

  Project splitExteriorWallSegment(
    Project project,
    String elementId,
    double splitOffsetMeters,
  ) {
    final element = project.houseModel.elements.firstWhere(
      (item) => item.id == elementId,
    );
    if (element.elementKind != ConstructionElementKind.wall ||
        element.lineSegment == null) {
      throw StateError('Разрезать можно только наружную стену с геометрией.');
    }
    final lineSegment = element.lineSegment!.normalized();
    final openings = project.houseModel.openings
        .where((item) => item.elementId == elementId)
        .toList(growable: false);
    if (openings.isNotEmpty) {
      throw StateError(
        'Нельзя разрезать сегмент стены, пока на нем есть проёмы.',
      );
    }
    final snappedOffset = _snap(splitOffsetMeters);
    if (snappedOffset <= roomLayoutSnapStepMeters ||
        snappedOffset >= lineSegment.lengthMeters - roomLayoutSnapStepMeters) {
      throw StateError(
        'Точка разреза должна делить стену на два сегмента не короче '
        '${roomLayoutSnapStepMeters.toStringAsFixed(1)} м.',
      );
    }

    final firstSegment = _splitLineSegment(
      lineSegment,
      startOffsetMeters: 0,
      endOffsetMeters: snappedOffset,
    );
    final secondSegment = _splitLineSegment(
      lineSegment,
      startOffsetMeters: snappedOffset,
      endOffsetMeters: lineSegment.lengthMeters,
    );
    final room = project.houseModel.rooms.firstWhere(
      (item) => item.id == element.roomId,
    );

    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        elements: [
          for (final item in project.houseModel.elements)
            if (item.id == elementId) ...[
              _buildAutoWallElement(
                room: room,
                segment: firstSegment,
                constructionId: element.constructionId,
                previousWalls: [element],
              ),
              _buildAutoWallElement(
                room: room,
                segment: secondSegment,
                constructionId: element.constructionId,
                previousWalls: [element],
              ),
            ] else
              item,
        ],
      ),
    );
  }

  Project deleteEnvelopeElement(Project project, String elementId) {
    final element = project.houseModel.elements.firstWhere(
      (item) => item.id == elementId,
    );
    if (element.source == EnvelopeElementSource.autoExteriorWall) {
      throw StateError(
        'Автоматический наружный сегмент нельзя удалить вручную.',
      );
    }
    return _syncGroundFloorCalculationLinks(
      project.copyWith(
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

  Project addGroundFloorCalculation(
    Project project,
    GroundFloorCalculation calculation,
  ) {
    final normalized = _normalizeGroundFloorCalculation(project, calculation);
    return _syncGroundFloorCalculationLinks(
      project.copyWith(
        groundFloorCalculations: [
          ...project.groundFloorCalculations,
          normalized,
        ],
      ),
    );
  }

  Project updateGroundFloorCalculation(
    Project project,
    GroundFloorCalculation calculation,
  ) {
    final normalized = _normalizeGroundFloorCalculation(
      project,
      calculation,
      replacingCalculationId: calculation.id,
    );
    return _syncGroundFloorCalculationLinks(
      project.copyWith(
        groundFloorCalculations: [
          for (final item in project.groundFloorCalculations)
            if (item.id == calculation.id) normalized else item,
        ],
      ),
    );
  }

  Project deleteGroundFloorCalculation(Project project, String calculationId) {
    return project.copyWith(
      groundFloorCalculations: [
        for (final item in project.groundFloorCalculations)
          if (item.id != calculationId) item,
      ],
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
    final selectedIds = project.effectiveSelectedConstructionIds;
    return _syncInternalPartitionConstruction(
      project.copyWith(
        constructions: [...project.constructions, construction],
        selectedConstructionIds: [...selectedIds, construction.id],
      ),
    );
  }

  Project updateConstruction(Project project, Construction construction) {
    final updatedProject = project.copyWith(
      constructions: [
        for (final item in project.constructions)
          if (item.id == construction.id) construction else item,
      ],
      houseModel: project.houseModel.copyWith(
        elements: [
          for (final element in project.houseModel.elements)
            if (element.constructionId == construction.id)
              _retargetElementForConstruction(
                project: project,
                element: element,
                construction: construction,
              )
            else
              element,
        ],
      ),
    );
    return _syncInternalPartitionConstruction(
      _syncProjectGeometry(updatedProject),
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

    return _syncInternalPartitionConstruction(
      project.copyWith(
        constructions: [
          for (final item in project.constructions)
            if (item.id != constructionId) item,
        ],
        selectedConstructionIds: [
          for (final item in project.effectiveSelectedConstructionIds)
            if (item != constructionId) item,
        ],
      ),
    );
  }

  Project selectConstruction(Project project, Construction construction) {
    if (project.effectiveSelectedConstructionIds.contains(construction.id)) {
      return project;
    }
    return _syncInternalPartitionConstruction(
      project.copyWith(
        constructions: [...project.constructions, construction],
        selectedConstructionIds: [
          ...project.effectiveSelectedConstructionIds,
          construction.id,
        ],
      ),
    );
  }

  Project unselectConstruction(Project project, String constructionId) {
    final isUsedByElements = project.houseModel.elements.any(
      (item) => item.constructionId == constructionId,
    );
    if (isUsedByElements) {
      throw StateError(
        'Нельзя убрать конструкцию из проекта, пока она используется в ограждениях.',
      );
    }
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
    return _syncInternalPartitionConstruction(
      project.copyWith(
        constructions: [
          for (final item in project.constructions)
            if (item.id != constructionId) item,
        ],
        selectedConstructionIds: [
          for (final item in selectedIds)
            if (item != constructionId) item,
        ],
      ),
    );
  }

  Project _syncProjectGeometry(Project project) {
    final normalizedRooms = project.houseModel.rooms
        .map(_normalizeRoom)
        .toList(growable: false);
    _validateRooms(normalizedRooms);

    final normalizedProject = project.copyWith(
      houseModel: project.houseModel.copyWith(rooms: normalizedRooms),
    );
    final manualElements = normalizedProject.houseModel.elements
        .where((item) => item.elementKind != ConstructionElementKind.wall)
        .map((item) => _normalizeElement(normalizedProject, item))
        .toList(growable: false);
    final previousWallElements = normalizedProject.houseModel.elements
        .where((item) => item.elementKind == ConstructionElementKind.wall)
        .map(
          (item) => item.source == EnvelopeElementSource.autoExteriorWall
              ? item.copyWith(lineSegment: item.lineSegment?.normalized())
              : _normalizeElement(normalizedProject, item),
        )
        .toList(growable: false);
    final rebuiltWalls = _buildAutoExteriorWalls(
      normalizedProject,
      previousWallElements,
    );
    final syncedRoomSurfaces = _syncAutoRoomSurfaceElements(
      normalizedProject,
      manualElements,
    );
    final elements = [...syncedRoomSurfaces, ...rebuiltWalls];
    final elementIds = elements.map((item) => item.id).toSet();
    final syncedProject = normalizedProject.copyWith(
      houseModel: normalizedProject.houseModel.copyWith(
        elements: elements,
        openings: normalizedProject.houseModel.openings
            .where((item) => elementIds.contains(item.elementId))
            .toList(growable: false),
      ),
    );
    final projectWithSyncedGroundFloorLinks = _syncGroundFloorCalculationLinks(
      syncedProject,
    );
    _ensureAllOpeningsFit(projectWithSyncedGroundFloorLinks);
    return projectWithSyncedGroundFloorLinks;
  }

  List<HouseEnvelopeElement> _buildAutoExteriorWalls(
    Project project,
    List<HouseEnvelopeElement> previousWalls,
  ) {
    final defaultWallConstructionId = _defaultWallConstructionId(project);
    if (defaultWallConstructionId == null) {
      return previousWalls
          .where((item) => item.elementKind == ConstructionElementKind.wall)
          .toList(growable: false);
    }

    final globalCounts = _buildGlobalEdgeCounts(project.houseModel.rooms);
    final walls = <HouseEnvelopeElement>[];
    for (final room in project.houseModel.rooms) {
      final baseSegments = _mergeSegments(
        _collectExteriorCellEdges(room, globalCounts),
      );
      final roomPreviousWalls = previousWalls
          .where((item) => item.roomId == room.id && item.lineSegment != null)
          .toList(growable: false);
      final openingAreasByWallId = _buildOpeningAreasByWallId(
        project,
        roomPreviousWalls,
      );
      final nextSegments = <HouseLineSegment>[];
      for (final segment in baseSegments) {
        final splitPoints = _buildSplitPointsForSegment(
          segment,
          roomPreviousWalls,
        );
        for (var index = 0; index < splitPoints.length - 1; index++) {
          final subSegment = _splitLineSegment(
            segment,
            startOffsetMeters: splitPoints[index],
            endOffsetMeters: splitPoints[index + 1],
          );
          if (subSegment.lengthMeters < roomLayoutSnapStepMeters - 0.0001) {
            continue;
          }
          nextSegments.add(subSegment);
        }
      }
      final matchedPreviousWalls = _matchPreviousWallsToSegments(
        previousWalls: roomPreviousWalls,
        nextSegments: nextSegments,
        openingAreasByWallId: openingAreasByWallId,
      );
      for (final subSegment in nextSegments) {
        walls.add(
          _buildAutoWallElement(
            room: room,
            segment: subSegment,
            constructionId:
                _resolveConstructionForSegment(subSegment, roomPreviousWalls) ??
                defaultWallConstructionId,
            previousWalls: roomPreviousWalls,
            matchedPreviousWall:
                matchedPreviousWalls[_segmentKey(subSegment.normalized())],
          ),
        );
      }
    }
    return walls;
  }

  HouseEnvelopeElement _buildAutoWallElement({
    required Room room,
    required HouseLineSegment segment,
    required String constructionId,
    required List<HouseEnvelopeElement> previousWalls,
    HouseEnvelopeElement? matchedPreviousWall,
  }) {
    final normalizedSegment = segment.normalized();
    final existing = previousWalls.where(
      (item) =>
          item.lineSegment != null &&
          _segmentsEqual(item.lineSegment!, normalizedSegment),
    );
    final matched =
        matchedPreviousWall ?? (existing.isEmpty ? null : existing.first);
    return HouseEnvelopeElement(
      id: matched?.id ?? _buildWallElementId(room.id, normalizedSegment),
      roomId: room.id,
      title: matched?.title ?? 'Стена ${room.title}',
      elementKind: ConstructionElementKind.wall,
      areaSquareMeters: normalizedSegment.lengthMeters * room.heightMeters,
      constructionId: matched?.constructionId ?? constructionId,
      lineSegment: normalizedSegment,
      source: EnvelopeElementSource.autoExteriorWall,
    );
  }

  String? _resolveConstructionForSegment(
    HouseLineSegment segment,
    List<HouseEnvelopeElement> previousWalls,
  ) {
    for (final wall in previousWalls) {
      final previousSegment = wall.lineSegment;
      if (previousSegment == null) {
        continue;
      }
      if (_segmentsEqual(previousSegment, segment) ||
          _segmentContains(previousSegment, segment)) {
        return wall.constructionId;
      }
    }
    return null;
  }

  Map<String, double> _buildOpeningAreasByWallId(
    Project project,
    List<HouseEnvelopeElement> roomPreviousWalls,
  ) {
    final wallIds = roomPreviousWalls.map((item) => item.id).toSet();
    final totals = <String, double>{};
    for (final opening in project.houseModel.openings) {
      if (!wallIds.contains(opening.elementId)) {
        continue;
      }
      totals.update(
        opening.elementId,
        (value) => value + opening.areaSquareMeters,
        ifAbsent: () => opening.areaSquareMeters,
      );
    }
    return totals;
  }

  Map<String, HouseEnvelopeElement> _matchPreviousWallsToSegments({
    required List<HouseEnvelopeElement> previousWalls,
    required List<HouseLineSegment> nextSegments,
    required Map<String, double> openingAreasByWallId,
  }) {
    final matchedBySegmentKey = <String, HouseEnvelopeElement>{};
    final claimedSegmentKeys = <String>{};
    for (final wall in previousWalls) {
      final previousSegment = wall.lineSegment?.normalized();
      if (previousSegment == null) {
        continue;
      }
      final candidates = nextSegments
          .where((segment) {
            final normalized = segment.normalized();
            return _segmentsEqual(previousSegment, normalized) ||
                _segmentContains(previousSegment, normalized) ||
                _segmentContains(normalized, previousSegment);
          })
          .toList(growable: false);
      final openingArea = openingAreasByWallId[wall.id];
      if (candidates.length != 1) {
        if (openingArea != null) {
          throw StateError(
            'Нельзя изменить форму помещения: сегмент стены с проёмами '
            'теряет однозначную привязку.',
          );
        }
        continue;
      }
      final segment = candidates.single.normalized();
      final segmentKey = _segmentKey(segment);
      if (openingArea != null &&
          openingArea > segment.lengthMeters * _heightForWallSegment(wall)) {
        throw StateError(
          'Нельзя изменить форму помещения: проёмы больше нового сегмента стены.',
        );
      }
      if (claimedSegmentKeys.contains(segmentKey)) {
        if (openingArea != null) {
          throw StateError(
            'Нельзя изменить форму помещения: сегмент стены с проёмами '
            'получает неоднозначного наследника.',
          );
        }
        continue;
      }
      claimedSegmentKeys.add(segmentKey);
      matchedBySegmentKey[segmentKey] = wall;
    }
    return matchedBySegmentKey;
  }

  double _heightForWallSegment(HouseEnvelopeElement wall) {
    final segment = wall.lineSegment;
    if (segment == null || segment.lengthMeters <= 0) {
      return defaultRoomHeightMeters;
    }
    return wall.areaSquareMeters / segment.lengthMeters;
  }

  List<double> _buildSplitPointsForSegment(
    HouseLineSegment baseSegment,
    List<HouseEnvelopeElement> previousWalls,
  ) {
    final points = <double>{0, _snap(baseSegment.lengthMeters)};
    for (final wall in previousWalls) {
      final previousSegment = wall.lineSegment;
      if (previousSegment == null ||
          !_segmentsAreCollinear(baseSegment, previousSegment) ||
          !_segmentContains(baseSegment, previousSegment)) {
        continue;
      }
      points.add(
        _offsetOnSegment(
          baseSegment,
          previousSegment.startXMeters,
          previousSegment.startYMeters,
        ),
      );
      points.add(
        _offsetOnSegment(
          baseSegment,
          previousSegment.endXMeters,
          previousSegment.endYMeters,
        ),
      );
    }
    final sorted = points.toList()..sort();
    return sorted;
  }

  List<HouseLineSegment> _collectExteriorCellEdges(
    Room room,
    Map<String, int> globalCounts,
  ) {
    final segments = <HouseLineSegment>[];
    for (final cell in _explodeToGridCells(room.effectiveCells)) {
      for (final edge in _edgesForCell(cell)) {
        if ((globalCounts[_edgeKey(edge)] ?? 0) == 1) {
          segments.add(edge);
        }
      }
    }
    return segments;
  }

  Map<String, int> _buildGlobalEdgeCounts(List<Room> rooms) {
    final counts = <String, int>{};
    for (final room in rooms) {
      for (final cell in _explodeToGridCells(room.effectiveCells)) {
        for (final edge in _edgesForCell(cell)) {
          counts.update(
            _edgeKey(edge),
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }
    return counts;
  }

  List<HouseLineSegment> _mergeSegments(List<HouseLineSegment> segments) {
    final horizontals = <double, List<HouseLineSegment>>{};
    final verticals = <double, List<HouseLineSegment>>{};
    for (final segment in segments.map((item) => item.normalized())) {
      if (segment.isHorizontal) {
        horizontals.putIfAbsent(segment.startYMeters, () => []).add(segment);
      } else {
        verticals.putIfAbsent(segment.startXMeters, () => []).add(segment);
      }
    }

    final merged = <HouseLineSegment>[];
    for (final entry in horizontals.entries) {
      final items = entry.value
        ..sort((a, b) => a.startXMeters.compareTo(b.startXMeters));
      var cursor = items.first;
      for (final item in items.skip(1)) {
        if ((item.startXMeters - cursor.endXMeters).abs() < 0.0001) {
          cursor = cursor.copyWith(endXMeters: item.endXMeters);
        } else {
          merged.add(cursor);
          cursor = item;
        }
      }
      merged.add(cursor);
    }
    for (final entry in verticals.entries) {
      final items = entry.value
        ..sort((a, b) => a.startYMeters.compareTo(b.startYMeters));
      var cursor = items.first;
      for (final item in items.skip(1)) {
        if ((item.startYMeters - cursor.endYMeters).abs() < 0.0001) {
          cursor = cursor.copyWith(endYMeters: item.endYMeters);
        } else {
          merged.add(cursor);
          cursor = item;
        }
      }
      merged.add(cursor);
    }
    return merged;
  }

  List<HouseLineSegment> _edgesForCell(RoomLayoutRect cell) => [
    HouseLineSegment(
      startXMeters: cell.xMeters,
      startYMeters: cell.yMeters,
      endXMeters: cell.rightMeters,
      endYMeters: cell.yMeters,
    ),
    HouseLineSegment(
      startXMeters: cell.xMeters,
      startYMeters: cell.bottomMeters,
      endXMeters: cell.rightMeters,
      endYMeters: cell.bottomMeters,
    ),
    HouseLineSegment(
      startXMeters: cell.xMeters,
      startYMeters: cell.yMeters,
      endXMeters: cell.xMeters,
      endYMeters: cell.bottomMeters,
    ),
    HouseLineSegment(
      startXMeters: cell.rightMeters,
      startYMeters: cell.yMeters,
      endXMeters: cell.rightMeters,
      endYMeters: cell.bottomMeters,
    ),
  ];

  String _edgeKey(HouseLineSegment segment) {
    final normalized = segment.normalized();
    return '${_f(normalized.startXMeters)}:${_f(normalized.startYMeters)}:${_f(normalized.endXMeters)}:${_f(normalized.endYMeters)}';
  }

  String _buildWallElementId(String roomId, HouseLineSegment segment) {
    final normalized = segment.normalized();
    return 'wall-$roomId-${_f(normalized.startXMeters)}-${_f(normalized.startYMeters)}-${_f(normalized.endXMeters)}-${_f(normalized.endYMeters)}';
  }

  String _f(double value) => value.toStringAsFixed(1).replaceAll('.', '_');

  String _segmentKey(HouseLineSegment segment) {
    final normalized = segment.normalized();
    return '${_f(normalized.startXMeters)}:${_f(normalized.startYMeters)}:${_f(normalized.endXMeters)}:${_f(normalized.endYMeters)}';
  }

  String _gridCellKey(RoomLayoutRect cell) =>
      '${_f(cell.xMeters)}:${_f(cell.yMeters)}';

  bool _gridCellsEqual(RoomLayoutRect left, RoomLayoutRect right) =>
      left.xMeters == right.xMeters &&
      left.yMeters == right.yMeters &&
      left.widthMeters == right.widthMeters &&
      left.heightMeters == right.heightMeters;

  bool _gridCellListContains(
    List<RoomLayoutRect> cells,
    RoomLayoutRect target,
  ) => cells.any((item) => _gridCellsEqual(item, target));

  Room _normalizeRoom(Room room) {
    final sourceCells = room.effectiveCells.length == 1
        ? [room.layout]
        : room.effectiveCells;
    final cells = sourceCells
        .map(
          (item) => room.effectiveCells.length == 1
              ? _normalizeCell(item)
              : RoomLayoutRect(
                  xMeters: _snap(item.xMeters),
                  yMeters: _snap(item.yMeters),
                  widthMeters: math.max(
                    roomLayoutSnapStepMeters,
                    _snap(item.widthMeters),
                  ),
                  heightMeters: math.max(
                    roomLayoutSnapStepMeters,
                    _snap(item.heightMeters),
                  ),
                ),
        )
        .toList(growable: false);
    return room.copyWith(
      cells: cells,
      layout: RoomLayoutRect.boundingBox(cells),
    );
  }

  RoomLayoutRect _normalizeCell(RoomLayoutRect cell) {
    return RoomLayoutRect(
      xMeters: _snap(cell.xMeters),
      yMeters: _snap(cell.yMeters),
      widthMeters: math.max(
        minimumRoomLayoutDimensionMeters,
        _snap(cell.widthMeters),
      ),
      heightMeters: math.max(
        minimumRoomLayoutDimensionMeters,
        _snap(cell.heightMeters),
      ),
    );
  }

  RoomLayoutRect _normalizeGridCell(RoomLayoutRect cell) {
    final normalized = RoomLayoutRect(
      xMeters: _snap(cell.xMeters),
      yMeters: _snap(cell.yMeters),
      widthMeters: roomLayoutSnapStepMeters,
      heightMeters: roomLayoutSnapStepMeters,
    );
    return normalized;
  }

  List<RoomLayoutRect> _explodeToGridCells(List<RoomLayoutRect> cells) {
    final unique = <String, RoomLayoutRect>{};
    for (final source in cells) {
      final normalized = RoomLayoutRect(
        xMeters: _snap(source.xMeters),
        yMeters: _snap(source.yMeters),
        widthMeters: math.max(
          roomLayoutSnapStepMeters,
          _snap(source.widthMeters),
        ),
        heightMeters: math.max(
          roomLayoutSnapStepMeters,
          _snap(source.heightMeters),
        ),
      );
      final startX = (normalized.xMeters / roomLayoutSnapStepMeters).round();
      final endX = (normalized.rightMeters / roomLayoutSnapStepMeters).round();
      final startY = (normalized.yMeters / roomLayoutSnapStepMeters).round();
      final endY = (normalized.bottomMeters / roomLayoutSnapStepMeters).round();
      for (var x = startX; x < endX; x++) {
        for (var y = startY; y < endY; y++) {
          final cell = RoomLayoutRect(
            xMeters: x * roomLayoutSnapStepMeters,
            yMeters: y * roomLayoutSnapStepMeters,
            widthMeters: roomLayoutSnapStepMeters,
            heightMeters: roomLayoutSnapStepMeters,
          );
          unique[_gridCellKey(cell)] = cell;
        }
      }
    }
    final exploded = unique.values.toList(growable: false);
    exploded.sort((left, right) {
      final yCompare = left.yMeters.compareTo(right.yMeters);
      if (yCompare != 0) {
        return yCompare;
      }
      return left.xMeters.compareTo(right.xMeters);
    });
    return exploded;
  }

  bool _hasAdjacentCell(List<RoomLayoutRect> cells, RoomLayoutRect target) {
    return cells.any((item) {
      final sameRow =
          item.yMeters == target.yMeters &&
          (item.xMeters - target.xMeters).abs() == roomLayoutSnapStepMeters;
      final sameColumn =
          item.xMeters == target.xMeters &&
          (item.yMeters - target.yMeters).abs() == roomLayoutSnapStepMeters;
      return sameRow || sameColumn;
    });
  }

  double _snap(double value) =>
      (value / roomLayoutSnapStepMeters).round() * roomLayoutSnapStepMeters;

  HouseEnvelopeElement _normalizeElement(
    Project project,
    HouseEnvelopeElement element,
  ) {
    _ensureRoomExists(project, element.roomId);
    _ensureConstructionExists(project, element.constructionId);
    final construction = project.constructions.firstWhere(
      (item) => item.id == element.constructionId,
    );
    final effectiveKind = construction.elementKind;
    final room = project.houseModel.rooms.firstWhere(
      (item) => item.id == element.roomId,
    );

    if (effectiveKind != ConstructionElementKind.wall) {
      final normalizedArea = _isAutoRoomSurfaceElement(element)
          ? room.areaSquareMeters
          : element.areaSquareMeters;
      return element.copyWith(
        elementKind: effectiveKind,
        areaSquareMeters: normalizedArea,
        clearWallPlacement: true,
        clearLineSegment: true,
        source: EnvelopeElementSource.manual,
      );
    }

    final lineSegment =
        element.lineSegment ??
        (element.wallPlacement == null
            ? null
            : _lineSegmentForWallPlacement(room, element.wallPlacement!));
    if (lineSegment == null) {
      throw StateError('Для наружной стены нужна геометрическая привязка.');
    }
    _ensureLineSegmentFitsRoom(room, lineSegment);
    return element.copyWith(
      elementKind: effectiveKind,
      areaSquareMeters: lineSegment.lengthMeters * room.heightMeters,
      lineSegment: lineSegment.normalized(),
      source: element.source == EnvelopeElementSource.autoExteriorWall
          ? EnvelopeElementSource.autoExteriorWall
          : EnvelopeElementSource.manual,
    );
  }

  HouseEnvelopeElement _retargetElementForConstruction({
    required Project project,
    required HouseEnvelopeElement element,
    required Construction construction,
  }) {
    if (construction.elementKind != ConstructionElementKind.wall) {
      return element.copyWith(
        elementKind: construction.elementKind,
        clearWallPlacement: true,
        clearLineSegment: true,
      );
    }

    final room = project.houseModel.rooms.firstWhere(
      (item) => item.id == element.roomId,
    );
    final lineSegment =
        element.lineSegment ??
        (element.wallPlacement == null
            ? HouseLineSegment(
                startXMeters: room.layout.xMeters,
                startYMeters: room.layout.yMeters,
                endXMeters: room.layout.rightMeters,
                endYMeters: room.layout.yMeters,
              )
            : _lineSegmentForWallPlacement(room, element.wallPlacement!));
    return element.copyWith(
      elementKind: construction.elementKind,
      lineSegment: lineSegment,
      source: EnvelopeElementSource.autoExteriorWall,
    );
  }

  void _validateRooms(List<Room> rooms) {
    final allCells =
        <({String roomId, String roomTitle, RoomLayoutRect cell})>[];
    for (final room in rooms) {
      final explodedCells = _explodeToGridCells(room.effectiveCells);
      final uniqueCellKeys = explodedCells.map(_gridCellKey).toSet();
      if (uniqueCellKeys.length != explodedCells.length) {
        throw StateError(
          'Комната ${room.title} содержит пересекающиеся ячейки.',
        );
      }
      if (!_gridCellsFormConnectedShape(explodedCells)) {
        throw StateError(
          'Комната ${room.title} должна оставаться одной связной фигурой.',
        );
      }
      if (_gridCellsContainHole(explodedCells)) {
        throw StateError(
          'Комната ${room.title} не должна содержать внутренних пустот.',
        );
      }
      for (final cell in explodedCells) {
        if (cell.xMeters < 0 || cell.yMeters < 0) {
          throw StateError(
            'Комната не может выходить в отрицательные координаты.',
          );
        }
        if (cell.widthMeters < roomLayoutSnapStepMeters ||
            cell.heightMeters < roomLayoutSnapStepMeters) {
          throw StateError(
            'Размер комнаты не может быть меньше '
            '${roomLayoutSnapStepMeters.toStringAsFixed(1)} м.',
          );
        }
        allCells.add((roomId: room.id, roomTitle: room.title, cell: cell));
      }
    }

    for (var index = 0; index < allCells.length; index++) {
      final current = allCells[index];
      for (
        var otherIndex = index + 1;
        otherIndex < allCells.length;
        otherIndex++
      ) {
        final other = allCells[otherIndex];
        if (_rectanglesOverlap(current.cell, other.cell)) {
          throw StateError(
            'Комнаты не должны пересекаться на плане: '
            '${current.roomTitle} и ${other.roomTitle}.',
          );
        }
      }
    }

    if (rooms.length > 1 && !_roomsFormConnectedHouse(rooms)) {
      throw StateError(
        'Все помещения должны образовывать единый связный план дома.',
      );
    }
  }

  bool _rectanglesOverlap(RoomLayoutRect left, RoomLayoutRect right) {
    return left.xMeters < right.rightMeters &&
        left.rightMeters > right.xMeters &&
        left.yMeters < right.bottomMeters &&
        left.bottomMeters > right.yMeters;
  }

  bool _roomsAreAdjacent(Room left, Room right) {
    for (final leftCell in _explodeToGridCells(left.effectiveCells)) {
      for (final rightCell in _explodeToGridCells(right.effectiveCells)) {
        for (final leftEdge in _edgesForCell(leftCell)) {
          for (final rightEdge in _edgesForCell(rightCell)) {
            if (_segmentsEqual(leftEdge, rightEdge)) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _roomsFormConnectedHouse(List<Room> rooms) {
    if (rooms.isEmpty) {
      return true;
    }
    final visited = <String>{};
    final queue = <Room>[rooms.first];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!visited.add(current.id)) {
        continue;
      }
      for (final candidate in rooms) {
        if (candidate.id != current.id &&
            !visited.contains(candidate.id) &&
            _roomsAreAdjacent(current, candidate)) {
          queue.add(candidate);
        }
      }
    }
    return visited.length == rooms.length;
  }

  List<HouseEnvelopeElement> _syncAutoRoomSurfaceElements(
    Project project,
    List<HouseEnvelopeElement> elements,
  ) {
    final roomsById = {
      for (final room in project.houseModel.rooms) room.id: room,
    };
    return [
      for (final element in elements)
        if (!_isAutoRoomSurfaceElement(element))
          element
        else if (roomsById[element.roomId] case final Room room)
          element.copyWith(areaSquareMeters: room.areaSquareMeters),
    ];
  }

  HouseEnvelopeElement _buildAutoRoomSurfaceElement({
    required Room room,
    required String id,
    required String title,
    required ConstructionElementKind elementKind,
    required String constructionId,
  }) {
    return HouseEnvelopeElement(
      id: id,
      roomId: room.id,
      title: title,
      elementKind: elementKind,
      areaSquareMeters: room.areaSquareMeters,
      constructionId: constructionId,
    );
  }

  bool _isAutoRoomSurfaceElement(HouseEnvelopeElement element) =>
      element.id == _autoFloorElementId(element.roomId) ||
      element.id == _autoTopElementId(element.roomId);

  String _autoFloorElementId(String roomId) => 'auto-floor-$roomId';

  String _autoTopElementId(String roomId) => 'auto-top-$roomId';

  void _ensureRoomExists(Project project, String roomId) {
    final exists = project.houseModel.rooms.any((item) => item.id == roomId);
    if (!exists) {
      throw StateError('Помещение $roomId не найдено в проекте.');
    }
  }

  void _ensureConstructionExists(Project project, String constructionId) {
    final exists = project.constructions.any(
      (item) => item.id == constructionId,
    );
    if (!exists) {
      throw StateError('Конструкция $constructionId не найдена в проекте.');
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

  void _ensureLineSegmentFitsRoom(Room room, HouseLineSegment segment) {
    final normalized = segment.normalized();
    if (!normalized.isHorizontal && !normalized.isVertical) {
      throw StateError(
        'Поддерживаются только горизонтальные и вертикальные стены.',
      );
    }
    final exteriorSegments = _buildRoomExteriorSegments(room);
    final fitsExterior = exteriorSegments.any(
      (item) => _segmentContains(item, normalized),
    );
    if (!fitsExterior) {
      throw StateError(
        'Сегмент стены должен лежать на внешней границе комнаты.',
      );
    }
  }

  bool _gridCellsFormConnectedShape(List<RoomLayoutRect> cells) {
    if (cells.isEmpty) {
      return false;
    }
    final cellMap = {for (final cell in cells) _gridCellKey(cell): cell};
    final queue = <RoomLayoutRect>[cells.first];
    final visited = <String>{};
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final key = _gridCellKey(current);
      if (!visited.add(key)) {
        continue;
      }
      for (final neighbor in _neighborCells(current)) {
        final matched = cellMap[_gridCellKey(neighbor)];
        if (matched != null && !visited.contains(_gridCellKey(matched))) {
          queue.add(matched);
        }
      }
    }
    return visited.length == cells.length;
  }

  bool _gridCellsContainHole(List<RoomLayoutRect> cells) {
    if (cells.isEmpty) {
      return false;
    }
    final occupancy = <String>{for (final cell in cells) _gridCellKey(cell)};
    final minX = cells.map((item) => item.xMeters).reduce(math.min);
    final maxX = cells.map((item) => item.xMeters).reduce(math.max);
    final minY = cells.map((item) => item.yMeters).reduce(math.min);
    final maxY = cells.map((item) => item.yMeters).reduce(math.max);
    final queue = <RoomLayoutRect>[
      RoomLayoutRect(
        xMeters: minX - roomLayoutSnapStepMeters,
        yMeters: minY - roomLayoutSnapStepMeters,
        widthMeters: roomLayoutSnapStepMeters,
        heightMeters: roomLayoutSnapStepMeters,
      ),
    ];
    final visited = <String>{};
    final minVisitX = minX - roomLayoutSnapStepMeters;
    final maxVisitX = maxX + roomLayoutSnapStepMeters;
    final minVisitY = minY - roomLayoutSnapStepMeters;
    final maxVisitY = maxY + roomLayoutSnapStepMeters;
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final key = _gridCellKey(current);
      if (!visited.add(key)) {
        continue;
      }
      for (final neighbor in _neighborCells(current)) {
        if (neighbor.xMeters < minVisitX - 0.0001 ||
            neighbor.xMeters > maxVisitX + 0.0001 ||
            neighbor.yMeters < minVisitY - 0.0001 ||
            neighbor.yMeters > maxVisitY + 0.0001) {
          continue;
        }
        final neighborKey = _gridCellKey(neighbor);
        if (occupancy.contains(neighborKey) || visited.contains(neighborKey)) {
          continue;
        }
        queue.add(neighbor);
      }
    }
    for (double x = minX; x <= maxX + 0.0001; x += roomLayoutSnapStepMeters) {
      for (double y = minY; y <= maxY + 0.0001; y += roomLayoutSnapStepMeters) {
        final candidate = RoomLayoutRect(
          xMeters: _snap(x),
          yMeters: _snap(y),
          widthMeters: roomLayoutSnapStepMeters,
          heightMeters: roomLayoutSnapStepMeters,
        );
        final key = _gridCellKey(candidate);
        if (!occupancy.contains(key) && !visited.contains(key)) {
          return true;
        }
      }
    }
    return false;
  }

  List<RoomLayoutRect> _neighborCells(RoomLayoutRect cell) => [
    cell.copyWith(xMeters: cell.xMeters - roomLayoutSnapStepMeters),
    cell.copyWith(xMeters: cell.xMeters + roomLayoutSnapStepMeters),
    cell.copyWith(yMeters: cell.yMeters - roomLayoutSnapStepMeters),
    cell.copyWith(yMeters: cell.yMeters + roomLayoutSnapStepMeters),
  ];

  List<HouseLineSegment> _buildRoomExteriorSegments(Room room) {
    final cells = _explodeToGridCells(room.effectiveCells);
    final counts = <String, int>{};
    final edgesByKey = <String, HouseLineSegment>{};
    for (final cell in cells) {
      for (final edge in _edgesForCell(cell)) {
        final key = _edgeKey(edge);
        counts.update(key, (value) => value + 1, ifAbsent: () => 1);
        edgesByKey.putIfAbsent(key, () => edge.normalized());
      }
    }
    return _mergeSegments([
      for (final entry in counts.entries)
        if (entry.value == 1) edgesByKey[entry.key]!,
    ]);
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

  String? _defaultWallConstructionId(Project project) {
    final selectedIds = project.effectiveSelectedConstructionIds.toSet();
    final selectedWall = project.constructions.where(
      (item) =>
          item.elementKind == ConstructionElementKind.wall &&
          selectedIds.contains(item.id),
    );
    if (selectedWall.isNotEmpty) {
      return selectedWall.first.id;
    }
    final anyWall = project.constructions.where(
      (item) => item.elementKind == ConstructionElementKind.wall,
    );
    return anyWall.isEmpty ? null : anyWall.first.id;
  }

  Project _syncInternalPartitionConstruction(Project project) {
    final currentId = project.houseModel.internalPartitionConstructionId;
    final selectedWallIds = project.constructions
        .where((item) => item.elementKind == ConstructionElementKind.wall)
        .map((item) => item.id)
        .toSet();
    final resolvedId = selectedWallIds.contains(currentId)
        ? currentId
        : _defaultWallConstructionId(project);
    return _syncGroundFloorCalculationLinks(
      project.copyWith(
        houseModel: project.houseModel.copyWith(
          internalPartitionConstructionId: resolvedId,
          clearInternalPartitionConstructionId: resolvedId == null,
        ),
      ),
    );
  }

  Project _syncGroundFloorCalculationLinks(Project project) {
    final floorElementsById = {
      for (final element in project.houseModel.elements)
        if (element.elementKind == ConstructionElementKind.floor) element.id: element,
    };
    final claimedElementIds = <String>{};
    final syncedCalculations = project.groundFloorCalculations
        .map((calculation) {
          final houseElementId = calculation.houseElementId;
          if (houseElementId == null) {
            return calculation;
          }
          final linkedElement = floorElementsById[houseElementId];
          if (linkedElement == null ||
              claimedElementIds.contains(houseElementId)) {
            return calculation.copyWith(clearHouseElementId: true);
          }
          claimedElementIds.add(houseElementId);
          return calculation.copyWith(
            constructionId: linkedElement.constructionId,
            areaSquareMeters: linkedElement.areaSquareMeters,
          );
        })
        .toList(growable: false);
    return project.copyWith(groundFloorCalculations: syncedCalculations);
  }

  GroundFloorCalculation _normalizeGroundFloorCalculation(
    Project project,
    GroundFloorCalculation calculation, {
    String? replacingCalculationId,
  }) {
    _ensureConstructionExists(project, calculation.constructionId);
    final houseElementId = calculation.houseElementId;
    if (houseElementId == null) {
      return calculation;
    }
    final element = project.houseModel.elements.firstWhere(
      (item) => item.id == houseElementId,
      orElse: () => throw StateError(
        'Ограждение $houseElementId не найдено в модели дома.',
      ),
    );
    if (element.elementKind != ConstructionElementKind.floor) {
      throw StateError('Связать расчет можно только с floor-элементом дома.');
    }
    final hasDuplicateLink = project.groundFloorCalculations.any(
      (item) =>
          item.id != replacingCalculationId &&
          item.houseElementId == houseElementId,
    );
    if (hasDuplicateLink) {
      throw StateError(
        'Для этого floor-элемента уже существует связанный расчет пола.',
      );
    }
    _ensureConstructionExists(project, element.constructionId);
    return calculation.copyWith(
      constructionId: element.constructionId,
      areaSquareMeters: element.areaSquareMeters,
    );
  }

  HouseLineSegment _lineSegmentForWallPlacement(
    Room room,
    EnvelopeWallPlacement placement,
  ) {
    final layout = room.layout;
    return switch (placement.side) {
      RoomSide.top => HouseLineSegment(
        startXMeters: layout.xMeters + placement.offsetMeters,
        startYMeters: layout.yMeters,
        endXMeters: layout.xMeters + placement.endMeters,
        endYMeters: layout.yMeters,
      ),
      RoomSide.bottom => HouseLineSegment(
        startXMeters: layout.xMeters + placement.offsetMeters,
        startYMeters: layout.bottomMeters,
        endXMeters: layout.xMeters + placement.endMeters,
        endYMeters: layout.bottomMeters,
      ),
      RoomSide.left => HouseLineSegment(
        startXMeters: layout.xMeters,
        startYMeters: layout.yMeters + placement.offsetMeters,
        endXMeters: layout.xMeters,
        endYMeters: layout.yMeters + placement.endMeters,
      ),
      RoomSide.right => HouseLineSegment(
        startXMeters: layout.rightMeters,
        startYMeters: layout.yMeters + placement.offsetMeters,
        endXMeters: layout.rightMeters,
        endYMeters: layout.yMeters + placement.endMeters,
      ),
    };
  }

  HouseLineSegment _splitLineSegment(
    HouseLineSegment lineSegment, {
    required double startOffsetMeters,
    required double endOffsetMeters,
  }) {
    if (lineSegment.isHorizontal) {
      final start = math.min(lineSegment.startXMeters, lineSegment.endXMeters);
      final y = lineSegment.startYMeters;
      return HouseLineSegment(
        startXMeters: start + startOffsetMeters,
        startYMeters: y,
        endXMeters: start + endOffsetMeters,
        endYMeters: y,
      );
    }
    final start = math.min(lineSegment.startYMeters, lineSegment.endYMeters);
    final x = lineSegment.startXMeters;
    return HouseLineSegment(
      startXMeters: x,
      startYMeters: start + startOffsetMeters,
      endXMeters: x,
      endYMeters: start + endOffsetMeters,
    );
  }

  bool _segmentsAreCollinear(HouseLineSegment left, HouseLineSegment right) {
    final a = left.normalized();
    final b = right.normalized();
    if (a.isHorizontal && b.isHorizontal) {
      return a.startYMeters == b.startYMeters;
    }
    if (a.isVertical && b.isVertical) {
      return a.startXMeters == b.startXMeters;
    }
    return false;
  }

  bool _segmentContains(HouseLineSegment outer, HouseLineSegment inner) {
    final a = outer.normalized();
    final b = inner.normalized();
    if (!_segmentsAreCollinear(a, b)) {
      return false;
    }
    if (a.isHorizontal) {
      return b.startXMeters >= a.startXMeters - 0.0001 &&
          b.endXMeters <= a.endXMeters + 0.0001;
    }
    return b.startYMeters >= a.startYMeters - 0.0001 &&
        b.endYMeters <= a.endYMeters + 0.0001;
  }

  bool _segmentsEqual(HouseLineSegment left, HouseLineSegment right) {
    final a = left.normalized();
    final b = right.normalized();
    return a.startXMeters == b.startXMeters &&
        a.startYMeters == b.startYMeters &&
        a.endXMeters == b.endXMeters &&
        a.endYMeters == b.endYMeters;
  }

  double _offsetOnSegment(
    HouseLineSegment segment,
    double xMeters,
    double yMeters,
  ) {
    final normalized = segment.normalized();
    return normalized.isHorizontal
        ? _snap(xMeters - normalized.startXMeters)
        : _snap(yMeters - normalized.startYMeters);
  }
}
