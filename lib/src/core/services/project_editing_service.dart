import 'dart:math' as math;

import '../models/project.dart';

class ProjectEditingService {
  const ProjectEditingService();

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
        'Составное помещение нельзя менять как один прямоугольник. Добавьте соседнюю ячейку и объедините комнаты заново.',
      );
    }
    return updateRoom(project, room.copyWith(cells: [layout], layout: layout));
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
            element.elementKind != ConstructionElementKind.wall)
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
          item.elementKind != ConstructionElementKind.wall,
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
    final selectedIds = project.effectiveSelectedConstructionIds;
    return project.copyWith(
      constructions: [...project.constructions, construction],
      selectedConstructionIds: [...selectedIds, construction.id],
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
    return _syncProjectGeometry(updatedProject);
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
      selectedConstructionIds: [
        for (final item in project.effectiveSelectedConstructionIds)
          if (item != constructionId) item,
      ],
    );
  }

  Project selectConstruction(Project project, Construction construction) {
    if (project.effectiveSelectedConstructionIds.contains(construction.id)) {
      return project;
    }
    return project.copyWith(
      constructions: [...project.constructions, construction],
      selectedConstructionIds: [
        ...project.effectiveSelectedConstructionIds,
        construction.id,
      ],
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
    return project.copyWith(
      constructions: [
        for (final item in project.constructions)
          if (item.id != constructionId) item,
      ],
      selectedConstructionIds: [
        for (final item in selectedIds)
          if (item != constructionId) item,
      ],
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
    final elements = [...manualElements, ...rebuiltWalls];
    final elementIds = elements.map((item) => item.id).toSet();
    final syncedProject = normalizedProject.copyWith(
      houseModel: normalizedProject.houseModel.copyWith(
        elements: elements,
        openings: normalizedProject.houseModel.openings
            .where((item) => elementIds.contains(item.elementId))
            .toList(growable: false),
      ),
    );
    _ensureAllOpeningsFit(syncedProject);
    return syncedProject;
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
          walls.add(
            _buildAutoWallElement(
              room: room,
              segment: subSegment,
              constructionId:
                  _resolveConstructionForSegment(
                    subSegment,
                    roomPreviousWalls,
                  ) ??
                  defaultWallConstructionId,
              previousWalls: roomPreviousWalls,
            ),
          );
        }
      }
    }
    return walls;
  }

  HouseEnvelopeElement _buildAutoWallElement({
    required Room room,
    required HouseLineSegment segment,
    required String constructionId,
    required List<HouseEnvelopeElement> previousWalls,
  }) {
    final normalizedSegment = segment.normalized();
    final existing = previousWalls.where(
      (item) =>
          item.lineSegment != null &&
          _segmentsEqual(item.lineSegment!, normalizedSegment),
    );
    final matched = existing.isEmpty ? null : existing.first;
    return HouseEnvelopeElement(
      id: _buildWallElementId(room.id, normalizedSegment),
      roomId: room.id,
      title: matched?.title ?? 'Стена ${room.title}',
      elementKind: ConstructionElementKind.wall,
      areaSquareMeters: normalizedSegment.lengthMeters * room.heightMeters,
      constructionId: constructionId,
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
    for (final cell in room.effectiveCells) {
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
      for (final cell in room.effectiveCells) {
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

  Room _normalizeRoom(Room room) {
    final sourceCells = room.effectiveCells.length == 1
        ? [room.layout]
        : room.effectiveCells;
    final cells = sourceCells
        .map((item) => _normalizeCell(item))
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
      return element.copyWith(
        elementKind: effectiveKind,
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
      for (final cell in room.effectiveCells) {
        if (cell.xMeters < 0 || cell.yMeters < 0) {
          throw StateError(
            'Комната не может выходить в отрицательные координаты.',
          );
        }
        if (cell.widthMeters < minimumRoomLayoutDimensionMeters ||
            cell.heightMeters < minimumRoomLayoutDimensionMeters) {
          throw StateError(
            'Размер комнаты не может быть меньше '
            '${minimumRoomLayoutDimensionMeters.toStringAsFixed(1)} м.',
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
  }

  bool _rectanglesOverlap(RoomLayoutRect left, RoomLayoutRect right) {
    return left.xMeters < right.rightMeters &&
        left.rightMeters > right.xMeters &&
        left.yMeters < right.bottomMeters &&
        left.bottomMeters > right.yMeters;
  }

  bool _roomsAreAdjacent(Room left, Room right) {
    for (final leftCell in left.effectiveCells) {
      for (final rightCell in right.effectiveCells) {
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
    final box = room.layout;
    final normalized = segment.normalized();
    final onBounds =
        (normalized.startXMeters == box.xMeters &&
            normalized.endXMeters == box.xMeters) ||
        (normalized.startXMeters == box.rightMeters &&
            normalized.endXMeters == box.rightMeters) ||
        (normalized.startYMeters == box.yMeters &&
            normalized.endYMeters == box.yMeters) ||
        (normalized.startYMeters == box.bottomMeters &&
            normalized.endYMeters == box.bottomMeters);
    if (!onBounds) {
      throw StateError(
        'Сегмент стены должен лежать на внешней границе комнаты.',
      );
    }
    if (normalized.isHorizontal) {
      if (normalized.startXMeters < box.xMeters - 0.0001 ||
          normalized.endXMeters > box.rightMeters + 0.0001) {
        throw StateError('Сегмент стены выходит за пределы комнаты.');
      }
    } else if (normalized.isVertical) {
      if (normalized.startYMeters < box.yMeters - 0.0001 ||
          normalized.endYMeters > box.bottomMeters + 0.0001) {
        throw StateError('Сегмент стены выходит за пределы комнаты.');
      }
    } else {
      throw StateError(
        'Поддерживаются только горизонтальные и вертикальные стены.',
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
