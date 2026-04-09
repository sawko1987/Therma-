import 'dart:math' as math;

import '../models/project.dart';

class WallPlanSyncService {
  const WallPlanSyncService();

  static const double _samplingOffsetMeters = 0.05;

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
      rooms: derivedRooms.map((item) => item.room).toList(growable: false),
      derivedElements: derivedElements,
    );

    return project.copyWith(
      houseModel: project.houseModel.copyWith(
        planModelKind: HousePlanModelKind.wallGraph,
        planNodes: normalizedNodes,
        planWalls: normalizedWalls,
        planWallOpenings: normalizedOpenings,
        rooms: derivedRooms.map((item) => item.room).toList(growable: false),
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
          xMeters: _roundToPrecision(math.max(0, node.xMeters)),
          yMeters: _roundToPrecision(math.max(0, node.yMeters)),
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
            wallConstructionIds.contains(wall.constructionId) &&
            wall.startNodeId != wall.endNodeId)
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
    if (walls.isEmpty) {
      return;
    }

    final nodeMap = {for (final node in nodes) node.id: node};
    final seenWallIds = <String>{};
    final seenSegments = <String>{};
    final segmentByWallId = <String, HouseLineSegment>{};
    final degreeByNodeId = <String, int>{};

    for (final wall in walls) {
      if (!seenWallIds.add(wall.id)) {
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
      );
      if (segment.lengthMeters <= 0.0001) {
        throw StateError('Стена ${wall.id} имеет нулевую длину.');
      }

      final key = _segmentKey(segment);
      if (!seenSegments.add(key)) {
        throw StateError('Две стены не могут лежать на одном сегменте.');
      }
      segmentByWallId[wall.id] = segment;

      degreeByNodeId.update(
        wall.startNodeId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      degreeByNodeId.update(
        wall.endNodeId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final segments = segmentByWallId.entries.toList(growable: false);
    for (var i = 0; i < segments.length; i++) {
      for (var j = i + 1; j < segments.length; j++) {
        final a = segments[i].value;
        final b = segments[j].value;
        if (!_segmentsIntersect(a, b)) {
          continue;
        }
        if (_segmentsShareEndpoint(a, b)) {
          continue;
        }
        throw StateError('Стены не должны пересекаться вне общих узлов.');
      }
    }

    for (final entry in degreeByNodeId.entries) {
      if (entry.value != 2) {
        throw StateError(
          'В узле ${entry.key} сходится ${entry.value} стен(ы). '
          'Новый контурный режим поддерживает только замкнутые контуры.',
        );
      }
    }
  }

  List<_DerivedRoom> _deriveRooms({
    required List<Room> previousRooms,
    required List<PlanNode> nodes,
    required List<PlanWall> walls,
  }) {
    if (nodes.isEmpty || walls.isEmpty) {
      return const [];
    }

    final nodeMap = {for (final node in nodes) node.id: node};
    final wallsByNodeId = <String, List<PlanWall>>{};
    for (final wall in walls) {
      wallsByNodeId.putIfAbsent(wall.startNodeId, () => []).add(wall);
      wallsByNodeId.putIfAbsent(wall.endNodeId, () => []).add(wall);
    }

    final loops = <List<RoomGeometryPoint>>[];
    final visitedWallIds = <String>{};

    for (final seed in walls) {
      if (visitedWallIds.contains(seed.id)) {
        continue;
      }

      final loopPoints = <RoomGeometryPoint>[];
      var currentWall = seed;
      var currentNodeId = seed.startNodeId;
      final startNodeId = seed.startNodeId;
      var guard = 0;

      while (guard < walls.length * 4) {
        guard++;
        visitedWallIds.add(currentWall.id);

        final currentNode = nodeMap[currentNodeId]!;
        if (loopPoints.isEmpty ||
            loopPoints.last.xMeters != currentNode.xMeters ||
            loopPoints.last.yMeters != currentNode.yMeters) {
          loopPoints.add(
            RoomGeometryPoint(
              xMeters: currentNode.xMeters,
              yMeters: currentNode.yMeters,
            ),
          );
        }

        final nextNodeId = currentWall.startNodeId == currentNodeId
            ? currentWall.endNodeId
            : currentWall.startNodeId;
        final nextNode = nodeMap[nextNodeId]!;
        loopPoints.add(
          RoomGeometryPoint(
            xMeters: nextNode.xMeters,
            yMeters: nextNode.yMeters,
          ),
        );

        currentNodeId = nextNodeId;

        if (currentNodeId == startNodeId) {
          break;
        }

        final nextWalls = wallsByNodeId[currentNodeId]!
            .where((item) => item.id != currentWall.id)
            .toList(growable: false);
        if (nextWalls.length != 1) {
          throw StateError(
            'Контур в узле $currentNodeId не может быть продолжен однозначно.',
          );
        }

        currentWall = nextWalls.single;
      }

      if (loopPoints.length < 4 || currentNodeId != startNodeId) {
        throw StateError('Каждый контур должен быть замкнут.');
      }

      final vertices = loopPoints.sublist(0, loopPoints.length - 1);
      if (_signedArea(vertices).abs() <= 0.001) {
        continue;
      }

      loops.add(vertices);
    }

    final previousById = {for (final room in previousRooms) room.id: room};
    final previousCellsById = {
      for (final room in previousRooms)
        room.id: room.effectiveCells.map(_cellKey).toSet(),
    };
    final usedPreviousIds = <String>{};

    final derived = <_DerivedRoom>[];
    var nextIndex = 1;

    for (final polygon in loops) {
      final cells = _rasterizePolygonToCells(polygon);
      if (cells.isEmpty) {
        continue;
      }

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

      final room =
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
              );

      derived.add(_DerivedRoom(room: room, polygon: polygon));
      nextIndex++;
    }

    derived.sort((left, right) {
      final yCompare = left.room.layout.yMeters.compareTo(
        right.room.layout.yMeters,
      );
      if (yCompare != 0) {
        return yCompare;
      }
      return left.room.layout.xMeters.compareTo(right.room.layout.xMeters);
    });

    return derived;
  }

  List<HouseEnvelopeElement> _deriveExteriorWalls({
    required List<_DerivedRoom> rooms,
    required List<PlanNode> nodes,
    required List<PlanWall> walls,
  }) {
    final nodeMap = {for (final node in nodes) node.id: node};
    final roomById = {for (final item in rooms) item.room.id: item};
    final result = <HouseEnvelopeElement>[];

    for (final wall in walls) {
      final start = nodeMap[wall.startNodeId]!;
      final end = nodeMap[wall.endNodeId]!;
      final segment = HouseLineSegment(
        startXMeters: start.xMeters,
        startYMeters: start.yMeters,
        endXMeters: end.xMeters,
        endYMeters: end.yMeters,
      ).normalized();

      final roomId = _singleAdjacentRoomForSegment(segment, rooms);
      if (roomId == null) {
        continue;
      }
      final room = roomById[roomId]!.room;

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

  String? _singleAdjacentRoomForSegment(
    HouseLineSegment segment,
    List<_DerivedRoom> rooms,
  ) {
    final length = segment.lengthMeters;
    if (length <= 0.0001) {
      return null;
    }

    final dx = (segment.endXMeters - segment.startXMeters) / length;
    final dy = (segment.endYMeters - segment.startYMeters) / length;
    final nx = -dy;
    final ny = dx;

    final samples = math.max(2, (length / 0.4).ceil());
    final leftIds = <String>{};
    final rightIds = <String>{};

    for (var i = 0; i < samples; i++) {
      final t = (i + 0.5) / samples;
      final px =
          segment.startXMeters +
          (segment.endXMeters - segment.startXMeters) * t;
      final py =
          segment.startYMeters +
          (segment.endYMeters - segment.startYMeters) * t;

      final leftPoint = RoomGeometryPoint(
        xMeters: px + nx * _samplingOffsetMeters,
        yMeters: py + ny * _samplingOffsetMeters,
      );
      final rightPoint = RoomGeometryPoint(
        xMeters: px - nx * _samplingOffsetMeters,
        yMeters: py - ny * _samplingOffsetMeters,
      );

      for (final room in rooms) {
        if (_pointInPolygon(leftPoint, room.polygon)) {
          leftIds.add(room.room.id);
        }
        if (_pointInPolygon(rightPoint, room.polygon)) {
          rightIds.add(room.room.id);
        }
      }
    }

    if (leftIds.length == 1 && rightIds.isEmpty) {
      return leftIds.first;
    }
    if (rightIds.length == 1 && leftIds.isEmpty) {
      return rightIds.first;
    }
    return null;
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
            areaSquareMeters:
                element.id == 'auto-floor-${element.roomId}' ||
                    element.id == 'auto-top-${element.roomId}'
                ? roomById[element.roomId]!.areaSquareMeters
                : element.areaSquareMeters,
          ),
    ];

    return [...derivedElements, ...retainedManual];
  }

  List<RoomLayoutRect> _rasterizePolygonToCells(
    List<RoomGeometryPoint> polygon,
  ) {
    if (polygon.length < 3) {
      return const [];
    }

    final minX = polygon.map((item) => item.xMeters).reduce(math.min);
    final maxX = polygon.map((item) => item.xMeters).reduce(math.max);
    final minY = polygon.map((item) => item.yMeters).reduce(math.min);
    final maxY = polygon.map((item) => item.yMeters).reduce(math.max);

    final cells = <String, RoomLayoutRect>{};
    for (double y = minY; y < maxY - 0.0001; y += roomLayoutSnapStepMeters) {
      for (double x = minX; x < maxX - 0.0001; x += roomLayoutSnapStepMeters) {
        final center = RoomGeometryPoint(
          xMeters: x + roomLayoutSnapStepMeters / 2,
          yMeters: y + roomLayoutSnapStepMeters / 2,
        );
        if (!_pointInPolygon(center, polygon)) {
          continue;
        }

        final cell = RoomLayoutRect(
          xMeters: _snapToRoomStep(x),
          yMeters: _snapToRoomStep(y),
          widthMeters: roomLayoutSnapStepMeters,
          heightMeters: roomLayoutSnapStepMeters,
        );
        cells[_cellKey(cell)] = cell;
      }
    }

    if (cells.isNotEmpty) {
      return cells.values.toList(growable: false);
    }

    final fallback = RoomLayoutRect(
      xMeters: _snapToRoomStep(minX),
      yMeters: _snapToRoomStep(minY),
      widthMeters: roomLayoutSnapStepMeters,
      heightMeters: roomLayoutSnapStepMeters,
    );
    return [fallback];
  }

  bool _pointInPolygon(
    RoomGeometryPoint point,
    List<RoomGeometryPoint> polygon,
  ) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].xMeters;
      final yi = polygon[i].yMeters;
      final xj = polygon[j].xMeters;
      final yj = polygon[j].yMeters;

      final intersects =
          ((yi > point.yMeters) != (yj > point.yMeters)) &&
          (point.xMeters <
              (xj - xi) * (point.yMeters - yi) / ((yj - yi) + 1e-9) + xi);
      if (intersects) {
        inside = !inside;
      }
    }
    return inside;
  }

  bool _segmentsIntersect(HouseLineSegment a, HouseLineSegment b) {
    final p1 = RoomGeometryPoint(
      xMeters: a.startXMeters,
      yMeters: a.startYMeters,
    );
    final q1 = RoomGeometryPoint(xMeters: a.endXMeters, yMeters: a.endYMeters);
    final p2 = RoomGeometryPoint(
      xMeters: b.startXMeters,
      yMeters: b.startYMeters,
    );
    final q2 = RoomGeometryPoint(xMeters: b.endXMeters, yMeters: b.endYMeters);

    final o1 = _orientation(p1, q1, p2);
    final o2 = _orientation(p1, q1, q2);
    final o3 = _orientation(p2, q2, p1);
    final o4 = _orientation(p2, q2, q1);

    if (o1 != o2 && o3 != o4) {
      return true;
    }

    if (o1 == 0 && _onSegment(p1, p2, q1)) return true;
    if (o2 == 0 && _onSegment(p1, q2, q1)) return true;
    if (o3 == 0 && _onSegment(p2, p1, q2)) return true;
    if (o4 == 0 && _onSegment(p2, q1, q2)) return true;

    return false;
  }

  bool _segmentsShareEndpoint(HouseLineSegment a, HouseLineSegment b) {
    final pointsA = {
      '${_round(a.startXMeters)}:${_round(a.startYMeters)}',
      '${_round(a.endXMeters)}:${_round(a.endYMeters)}',
    };
    final pointsB = {
      '${_round(b.startXMeters)}:${_round(b.startYMeters)}',
      '${_round(b.endXMeters)}:${_round(b.endYMeters)}',
    };
    return pointsA.intersection(pointsB).isNotEmpty;
  }

  int _orientation(
    RoomGeometryPoint p,
    RoomGeometryPoint q,
    RoomGeometryPoint r,
  ) {
    final value =
        (q.yMeters - p.yMeters) * (r.xMeters - q.xMeters) -
        (q.xMeters - p.xMeters) * (r.yMeters - q.yMeters);
    if (value.abs() <= 1e-9) {
      return 0;
    }
    return value > 0 ? 1 : 2;
  }

  bool _onSegment(
    RoomGeometryPoint p,
    RoomGeometryPoint q,
    RoomGeometryPoint r,
  ) {
    return q.xMeters <= math.max(p.xMeters, r.xMeters) + 1e-9 &&
        q.xMeters >= math.min(p.xMeters, r.xMeters) - 1e-9 &&
        q.yMeters <= math.max(p.yMeters, r.yMeters) + 1e-9 &&
        q.yMeters >= math.min(p.yMeters, r.yMeters) - 1e-9;
  }

  double _signedArea(List<RoomGeometryPoint> polygon) {
    var sum = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final current = polygon[i];
      final next = polygon[(i + 1) % polygon.length];
      sum += current.xMeters * next.yMeters - next.xMeters * current.yMeters;
    }
    return sum / 2;
  }

  String _segmentKey(HouseLineSegment segment) {
    final aX = _roundToPrecision(segment.startXMeters);
    final aY = _roundToPrecision(segment.startYMeters);
    final bX = _roundToPrecision(segment.endXMeters);
    final bY = _roundToPrecision(segment.endYMeters);

    if (aX < bX || (aX == bX && aY <= bY)) {
      return '${_round(aX)}:${_round(aY)}:${_round(bX)}:${_round(bY)}';
    }
    return '${_round(bX)}:${_round(bY)}:${_round(aX)}:${_round(aY)}';
  }

  String _cellKey(RoomLayoutRect cell) {
    return '${_round(cell.xMeters)}:${_round(cell.yMeters)}:'
        '${_round(cell.widthMeters)}:${_round(cell.heightMeters)}';
  }

  double _roundToPrecision(double value) {
    return (value * 1000).round() / 1000;
  }

  double _snapToRoomStep(double value) {
    return (value / roomLayoutSnapStepMeters).round() *
        roomLayoutSnapStepMeters;
  }

  String _round(double value) => value.toStringAsFixed(4);
}

class _DerivedRoom {
  const _DerivedRoom({required this.room, required this.polygon});

  final Room room;
  final List<RoomGeometryPoint> polygon;
}
