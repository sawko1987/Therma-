import 'dart:math' as math;

import '../models/project.dart';

class WallPlanSyncService {
  const WallPlanSyncService();

  Project syncProject(
    Project project, {
    required List<PlanNode> nodes,
    required List<PlanWall> walls,
    required List<PlanWallOpening> openings,
  }) {
    final normalizedNodes = _normalizeNodes(nodes);
    final normalizedWalls = _normalizeWalls(project, normalizedNodes, walls);
    final normalizedOpenings = _normalizeOpenings(normalizedWalls, openings);
    _validateGraph(normalizedNodes, normalizedWalls);
    final derivedRooms = _deriveRooms(
      previousRooms: project.houseModel.rooms,
      nodes: normalizedNodes,
      walls: normalizedWalls,
    );
    final derivedElements = _deriveExteriorWalls(
      project: project,
      rooms: derivedRooms,
      nodes: normalizedNodes,
      walls: normalizedWalls,
    );
    final derivedOpenings = _deriveOpenings(
      elements: derivedElements,
      openings: normalizedOpenings,
    );
    final syncedElements = _syncRoomSurfaceElements(
      project: project,
      rooms: derivedRooms,
      derivedElements: derivedElements,
    );

    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        planModelKind: HousePlanModelKind.wallGraph,
        planNodes: normalizedNodes,
        planWalls: normalizedWalls,
        planWallOpenings: normalizedOpenings,
        rooms: derivedRooms,
        elements: syncedElements,
        openings: derivedOpenings,
        clearInternalPartitionConstructionId: true,
      ),
    );
  }

  List<PlanNode> _normalizeNodes(List<PlanNode> nodes) {
    return [
      for (final node in nodes)
        node.copyWith(
          xMeters: _snap(math.max(0, node.xMeters)),
          yMeters: _snap(math.max(0, node.yMeters)),
        ),
    ];
  }

  List<PlanWall> _normalizeWalls(
    Project project,
    List<PlanNode> nodes,
    List<PlanWall> walls,
  ) {
    final nodeIds = nodes.map((item) => item.id).toSet();
    final wallConstructionIds = project.constructions
        .where((item) => item.elementKind == ConstructionElementKind.wall)
        .map((item) => item.id)
        .toSet();
    return [
      for (final wall in walls)
        if (nodeIds.contains(wall.startNodeId) &&
            nodeIds.contains(wall.endNodeId) &&
            wallConstructionIds.contains(wall.constructionId))
          wall,
    ];
  }

  List<PlanWallOpening> _normalizeOpenings(
    List<PlanWall> walls,
    List<PlanWallOpening> openings,
  ) {
    final wallIds = walls.map((item) => item.id).toSet();
    return [
      for (final opening in openings)
        if (wallIds.contains(opening.wallId)) opening,
    ];
  }

  void _validateGraph(List<PlanNode> nodes, List<PlanWall> walls) {
    final nodeMap = {for (final node in nodes) node.id: node};
    final seenWalls = <String>{};
    final segments = <String, HouseLineSegment>{};
    for (final wall in walls) {
      if (!seenWalls.add(wall.id)) {
        throw StateError('Стена ${wall.id} дублируется в плане.');
      }
      final start = nodeMap[wall.startNodeId];
      final end = nodeMap[wall.endNodeId];
      if (start == null || end == null) {
        throw StateError('Стена ${wall.id} ссылается на несуществующий узел.');
      }
      final segment = HouseLineSegment(
        startXMeters: start.xMeters,
        startYMeters: start.yMeters,
        endXMeters: end.xMeters,
        endYMeters: end.yMeters,
      ).normalized();
      if ((!segment.isHorizontal && !segment.isVertical) ||
          segment.lengthMeters <= 0) {
        throw StateError('Поддерживаются только горизонтальные и вертикальные стены.');
      }
      final segmentKey = _segmentKey(segment);
      if (segments.containsKey(segmentKey)) {
        throw StateError('Две стены не могут лежать на одном сегменте.');
      }
      segments[segmentKey] = segment;
    }

    final segmentList = segments.values.toList(growable: false);
    for (var i = 0; i < segmentList.length; i++) {
      for (var j = i + 1; j < segmentList.length; j++) {
        if (_segmentsConflict(segmentList[i], segmentList[j])) {
          throw StateError('Стены не должны пересекаться вне общих узлов.');
        }
      }
    }
  }

  bool _segmentsConflict(HouseLineSegment left, HouseLineSegment right) {
    final a = left.normalized();
    final b = right.normalized();
    if (a.isHorizontal && b.isHorizontal && a.startYMeters == b.startYMeters) {
      final overlapStart = math.max(a.startXMeters, b.startXMeters);
      final overlapEnd = math.min(a.endXMeters, b.endXMeters);
      return overlapEnd - overlapStart > 0.0001 &&
          !_segmentsShareOnlyEndpoint(a, b);
    }
    if (a.isVertical && b.isVertical && a.startXMeters == b.startXMeters) {
      final overlapStart = math.max(a.startYMeters, b.startYMeters);
      final overlapEnd = math.min(a.endYMeters, b.endYMeters);
      return overlapEnd - overlapStart > 0.0001 &&
          !_segmentsShareOnlyEndpoint(a, b);
    }
    if (a.isHorizontal && b.isVertical) {
      final intersects = b.startXMeters > a.startXMeters &&
          b.startXMeters < a.endXMeters &&
          a.startYMeters > b.startYMeters &&
          a.startYMeters < b.endYMeters;
      return intersects;
    }
    if (a.isVertical && b.isHorizontal) {
      return _segmentsConflict(b, a);
    }
    return false;
  }

  bool _segmentsShareOnlyEndpoint(HouseLineSegment left, HouseLineSegment right) {
    final points = {
      '${left.startXMeters}:${left.startYMeters}',
      '${left.endXMeters}:${left.endYMeters}',
    };
    var shared = 0;
    for (final point in [
      '${right.startXMeters}:${right.startYMeters}',
      '${right.endXMeters}:${right.endYMeters}',
    ]) {
      if (points.contains(point)) {
        shared++;
      }
    }
    return shared == 1;
  }

  List<Room> _deriveRooms({
    required List<Room> previousRooms,
    required List<PlanNode> nodes,
    required List<PlanWall> walls,
  }) {
    if (nodes.isEmpty || walls.isEmpty) {
      return const [];
    }
    final nodeMap = {for (final node in nodes) node.id: node};
    final intSegments = [
      for (final wall in walls)
        _segmentToGrid(
          HouseLineSegment(
            startXMeters: nodeMap[wall.startNodeId]!.xMeters,
            startYMeters: nodeMap[wall.startNodeId]!.yMeters,
            endXMeters: nodeMap[wall.endNodeId]!.xMeters,
            endYMeters: nodeMap[wall.endNodeId]!.yMeters,
          ).normalized(),
        ),
    ];
    final maxX = intSegments.fold<int>(0, (sum, item) => math.max(sum, item.maxX));
    final maxY = intSegments.fold<int>(0, (sum, item) => math.max(sum, item.maxY));
    final blocked = <String>{};
    for (final segment in intSegments) {
      if (segment.isHorizontal) {
        for (var x = segment.minX; x < segment.maxX; x++) {
          blocked.add('h:$x:${segment.minY}');
        }
      } else {
        for (var y = segment.minY; y < segment.maxY; y++) {
          blocked.add('v:${segment.minX}:$y');
        }
      }
    }

    final visited = <String>{};
    final outsideQueue = <_GridCell>[_GridCell(-1, -1)];
    while (outsideQueue.isNotEmpty) {
      final current = outsideQueue.removeLast();
      final key = current.key;
      if (!visited.add(key)) {
        continue;
      }
      for (final neighbor in current.neighbors) {
        if (neighbor.x < -1 ||
            neighbor.y < -1 ||
            neighbor.x > maxX ||
            neighbor.y > maxY) {
          continue;
        }
        if (_isBlocked(current, neighbor, blocked)) {
          continue;
        }
        if (!visited.contains(neighbor.key)) {
          outsideQueue.add(neighbor);
        }
      }
    }

    final roomRegions = <List<_GridCell>>[];
    final interiorVisited = <String>{};
    for (var x = 0; x < maxX; x++) {
      for (var y = 0; y < maxY; y++) {
        final cell = _GridCell(x, y);
        if (visited.contains(cell.key) || !interiorVisited.add(cell.key)) {
          continue;
        }
        final region = <_GridCell>[];
        final queue = <_GridCell>[cell];
        while (queue.isNotEmpty) {
          final current = queue.removeLast();
          if (visited.contains(current.key)) {
            continue;
          }
          region.add(current);
          for (final neighbor in current.neighbors) {
            if (neighbor.x < 0 ||
                neighbor.y < 0 ||
                neighbor.x >= maxX ||
                neighbor.y >= maxY ||
                visited.contains(neighbor.key) ||
                _isBlocked(current, neighbor, blocked) ||
                !interiorVisited.add(neighbor.key)) {
              continue;
            }
            queue.add(neighbor);
          }
        }
        if (region.isNotEmpty) {
          roomRegions.add(region);
        }
      }
    }

    final previousById = {for (final room in previousRooms) room.id: room};
    final previousCellsById = {
      for (final room in previousRooms)
        room.id: room.effectiveCells.map(_cellKey).toSet(),
    };
    final usedPreviousIds = <String>{};
    final rooms = <Room>[];
    var nextIndex = 1;
    for (final region in roomRegions) {
      final cells = [
        for (final cell in region)
          RoomLayoutRect(
            xMeters: cell.x * roomLayoutSnapStepMeters,
            yMeters: cell.y * roomLayoutSnapStepMeters,
            widthMeters: roomLayoutSnapStepMeters,
            heightMeters: roomLayoutSnapStepMeters,
          ),
      ];
      String? matchedId;
      var bestOverlap = 0;
      final currentKeys = cells.map(_cellKey).toSet();
      for (final entry in previousCellsById.entries) {
        if (usedPreviousIds.contains(entry.key)) {
          continue;
        }
        final overlap = currentKeys.intersection(entry.value).length;
        if (overlap > bestOverlap) {
          bestOverlap = overlap;
          matchedId = entry.key;
        }
      }
      final previous = matchedId == null ? null : previousById[matchedId];
      if (matchedId != null) {
        usedPreviousIds.add(matchedId);
      }
      rooms.add(
        (previous ??
                Room(
                  id: 'room-${DateTime.now().microsecondsSinceEpoch}-$nextIndex',
                  title: 'Помещение $nextIndex',
                  kind: RoomKind.livingRoom,
                  heightMeters: defaultRoomHeightMeters,
                  layout: RoomLayoutRect.boundingBox(cells),
                  cells: cells,
                ))
            .copyWith(
              layout: RoomLayoutRect.boundingBox(cells),
              cells: cells,
              clearGeometry: true,
              clearShapeTemplateId: true,
            ),
      );
      nextIndex++;
    }
    rooms.sort((left, right) {
      final yCompare = left.layout.yMeters.compareTo(right.layout.yMeters);
      if (yCompare != 0) {
        return yCompare;
      }
      return left.layout.xMeters.compareTo(right.layout.xMeters);
    });
    return rooms;
  }

  List<HouseEnvelopeElement> _deriveExteriorWalls({
    required Project project,
    required List<Room> rooms,
    required List<PlanNode> nodes,
    required List<PlanWall> walls,
  }) {
    final nodeMap = {for (final node in nodes) node.id: node};
    final roomByCell = <String, Room>{};
    for (final room in rooms) {
      for (final cell in room.effectiveCells) {
        roomByCell[_cellKey(cell)] = room;
      }
    }
    final result = <HouseEnvelopeElement>[];
    for (final wall in walls) {
      final segment = HouseLineSegment(
        startXMeters: nodeMap[wall.startNodeId]!.xMeters,
        startYMeters: nodeMap[wall.startNodeId]!.yMeters,
        endXMeters: nodeMap[wall.endNodeId]!.xMeters,
        endYMeters: nodeMap[wall.endNodeId]!.yMeters,
      ).normalized();
      final adjacentRooms = _roomsAdjacentToSegment(segment, roomByCell)
          .toSet()
          .toList(growable: false);
      if (adjacentRooms.length != 1) {
        continue;
      }
      final room = adjacentRooms.single;
      result.add(
        HouseEnvelopeElement(
          id: 'wall-${wall.id}',
          roomId: room.id,
          title: 'Стена ${room.title}',
          elementKind: ConstructionElementKind.wall,
          areaSquareMeters: segment.lengthMeters * room.heightMeters,
          constructionId: wall.constructionId,
          lineSegment: segment,
          source: EnvelopeElementSource.autoExteriorWall,
        ),
      );
    }
    return result;
  }

  List<EnvelopeOpening> _deriveOpenings({
    required List<HouseEnvelopeElement> elements,
    required List<PlanWallOpening> openings,
  }) {
    final elementByWallId = {
      for (final element in elements)
        if (element.id.startsWith('wall-')) element.id.substring(5): element,
    };
    final result = <EnvelopeOpening>[];
    for (final opening in openings) {
      final element = elementByWallId[opening.wallId];
      if (element == null) {
        continue;
      }
      result.add(
        EnvelopeOpening(
          id: 'opening-${opening.id}',
          elementId: element.id,
          title: opening.title,
          kind: opening.kind,
          areaSquareMeters: opening.areaSquareMeters,
          heatTransferCoefficient: opening.heatTransferCoefficient,
          leakagePreset: opening.leakagePreset,
        ),
      );
    }
    return result;
  }

  List<HouseEnvelopeElement> _syncRoomSurfaceElements({
    required Project project,
    required List<Room> rooms,
    required List<HouseEnvelopeElement> derivedElements,
  }) {
    final roomById = {for (final room in rooms) room.id: room};
    final retainedManual = [
      for (final element in project.houseModel.elements)
        if (element.elementKind != ConstructionElementKind.wall &&
            roomById.containsKey(element.roomId))
          element.copyWith(
            areaSquareMeters: element.id == 'auto-floor-${element.roomId}' ||
                    element.id == 'auto-top-${element.roomId}'
                ? roomById[element.roomId]!.areaSquareMeters
                : element.areaSquareMeters,
          ),
    ];
    return [...derivedElements, ...retainedManual];
  }

  List<Room> _roomsAdjacentToSegment(
    HouseLineSegment segment,
    Map<String, Room> roomByCell,
  ) {
    final rooms = <Room>[];
    if (segment.isHorizontal) {
      final y = _toGrid(segment.startYMeters);
      for (var x = _toGrid(segment.startXMeters); x < _toGrid(segment.endXMeters); x++) {
        final above = roomByCell['$x:$y'];
        final below = roomByCell['$x:${y - 1}'];
        if (above != null) {
          rooms.add(above);
        }
        if (below != null) {
          rooms.add(below);
        }
      }
      return rooms;
    }
    final x = _toGrid(segment.startXMeters);
    for (var y = _toGrid(segment.startYMeters); y < _toGrid(segment.endYMeters); y++) {
      final right = roomByCell['$x:$y'];
      final left = roomByCell['${x - 1}:$y'];
      if (right != null) {
        rooms.add(right);
      }
      if (left != null) {
        rooms.add(left);
      }
    }
    return rooms;
  }

  _GridSegment _segmentToGrid(HouseLineSegment segment) {
    return _GridSegment(
      minX: _toGrid(math.min(segment.startXMeters, segment.endXMeters)),
      minY: _toGrid(math.min(segment.startYMeters, segment.endYMeters)),
      maxX: _toGrid(math.max(segment.startXMeters, segment.endXMeters)),
      maxY: _toGrid(math.max(segment.startYMeters, segment.endYMeters)),
      isHorizontal: segment.isHorizontal,
    );
  }

  bool _isBlocked(_GridCell current, _GridCell neighbor, Set<String> blocked) {
    if (current.x == neighbor.x) {
      final x = current.x;
      final y = math.max(current.y, neighbor.y);
      return blocked.contains('h:$x:$y');
    }
    final x = math.max(current.x, neighbor.x);
    final y = current.y;
    return blocked.contains('v:$x:$y');
  }

  int _toGrid(double meters) => (meters / roomLayoutSnapStepMeters).round();

  String _segmentKey(HouseLineSegment segment) {
    final normalized = segment.normalized();
    return '${normalized.startXMeters}:${normalized.startYMeters}:${normalized.endXMeters}:${normalized.endYMeters}';
  }

  String _cellKey(RoomLayoutRect cell) {
    return '${cell.xMeters}:${cell.yMeters}:${cell.widthMeters}:${cell.heightMeters}';
  }

  double _snap(double value) {
    return (value / roomLayoutSnapStepMeters).round() * roomLayoutSnapStepMeters;
  }
}

class _GridCell {
  const _GridCell(this.x, this.y);

  final int x;
  final int y;

  String get key => '$x:$y';

  List<_GridCell> get neighbors => [
    _GridCell(x - 1, y),
    _GridCell(x + 1, y),
    _GridCell(x, y - 1),
    _GridCell(x, y + 1),
  ];
}

class _GridSegment {
  const _GridSegment({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.isHorizontal,
  });

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
  final bool isHorizontal;
}
