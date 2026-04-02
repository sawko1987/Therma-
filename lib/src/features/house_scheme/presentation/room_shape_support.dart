import 'dart:math' as math;

import '../../../core/models/project.dart';

RoomGeometry geometryForRoom(Room room) {
  return room.geometry ??
      RoomGeometry(
        vertices: [
          RoomGeometryPoint(
            xMeters: room.layout.xMeters,
            yMeters: room.layout.yMeters,
          ),
          RoomGeometryPoint(
            xMeters: room.layout.rightMeters,
            yMeters: room.layout.yMeters,
          ),
          RoomGeometryPoint(
            xMeters: room.layout.rightMeters,
            yMeters: room.layout.bottomMeters,
          ),
          RoomGeometryPoint(
            xMeters: room.layout.xMeters,
            yMeters: room.layout.bottomMeters,
          ),
        ],
      );
}

Room buildRoomFromShapeTemplate({
  required RoomShapeTemplate template,
  required String id,
  required String title,
  required RoomKind kind,
  required double roomHeightMeters,
  required double xMeters,
  required double yMeters,
  required double widthMeters,
  required double heightMeters,
}) {
  final snappedWidth = _snapDimension(widthMeters);
  final snappedHeight = _snapDimension(heightMeters);
  final geometry = template.instantiate(
    xMeters: xMeters,
    yMeters: yMeters,
    widthMeters: snappedWidth,
    heightMeters: snappedHeight,
  );
  final cells = rasterizeGeometryToGridCells(geometry);
  return Room(
    id: id,
    title: title,
    kind: kind,
    heightMeters: roomHeightMeters,
    layout: RoomLayoutRect.boundingBox(cells),
    cells: cells,
    geometry: geometry,
    shapeTemplateId: template.id,
  );
}

Room resizeRoomGeometry({
  required Room source,
  required double widthMeters,
  required double heightMeters,
}) {
  final baseGeometry = geometryForRoom(source);
  final resizedGeometry = baseGeometry.scaleToBounds(
    xMeters: source.layout.xMeters,
    yMeters: source.layout.yMeters,
    widthMeters: _snapDimension(widthMeters),
    heightMeters: _snapDimension(heightMeters),
  );
  final cells = rasterizeGeometryToGridCells(resizedGeometry);
  return source.copyWith(
    layout: RoomLayoutRect.boundingBox(cells),
    cells: cells,
    geometry: resizedGeometry,
  );
}

RoomShapeTemplate roomShapeTemplateFromRoom({
  required Room room,
  required String id,
  required String title,
  String description = '',
}) {
  final geometry = geometryForRoom(room);
  final bounds = geometry.bounds;
  return RoomShapeTemplate(
    id: id,
    title: title,
    description: description,
    normalizedGeometry: geometry.normalized(),
    defaultWidthMeters: bounds.widthMeters <= 0
        ? defaultRoomLayoutWidthMeters
        : bounds.widthMeters,
    defaultHeightMeters: bounds.heightMeters <= 0
        ? defaultRoomLayoutHeightMeters
        : bounds.heightMeters,
    tags: const ['custom'],
  );
}

List<RoomLayoutRect> rasterizeGeometryToGridCells(RoomGeometry geometry) {
  final bounds = geometry.bounds;
  final left = _snapToGrid(bounds.leftMeters);
  final top = _snapToGrid(bounds.topMeters);
  final right = _snapToGrid(bounds.rightMeters + roomLayoutSnapStepMeters);
  final bottom = _snapToGrid(bounds.bottomMeters + roomLayoutSnapStepMeters);
  final cells = <RoomLayoutRect>[];

  for (
    double yMeters = top;
    yMeters < bottom;
    yMeters += roomLayoutSnapStepMeters
  ) {
    for (
      double xMeters = left;
      xMeters < right;
      xMeters += roomLayoutSnapStepMeters
    ) {
      final center = RoomGeometryPoint(
        xMeters: xMeters + roomLayoutSnapStepMeters / 2,
        yMeters: yMeters + roomLayoutSnapStepMeters / 2,
      );
      if (_pointInPolygon(center, geometry.vertices)) {
        cells.add(
          RoomLayoutRect(
            xMeters: xMeters,
            yMeters: yMeters,
            widthMeters: roomLayoutSnapStepMeters,
            heightMeters: roomLayoutSnapStepMeters,
          ),
        );
      }
    }
  }

  if (cells.isNotEmpty) {
    return List.unmodifiable(cells);
  }

  return [
    RoomLayoutRect(
      xMeters: _snapToGrid(bounds.leftMeters),
      yMeters: _snapToGrid(bounds.topMeters),
      widthMeters: roomLayoutSnapStepMeters,
      heightMeters: roomLayoutSnapStepMeters,
    ),
  ];
}

double _snapDimension(double value) {
  return math.max(minimumRoomLayoutDimensionMeters, _snapToGrid(value));
}

double _snapToGrid(double value) {
  return (value / roomLayoutSnapStepMeters).round() * roomLayoutSnapStepMeters;
}

bool _pointInPolygon(RoomGeometryPoint point, List<RoomGeometryPoint> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].xMeters;
    final yi = polygon[i].yMeters;
    final xj = polygon[j].xMeters;
    final yj = polygon[j].yMeters;
    final intersects =
        ((yi > point.yMeters) != (yj > point.yMeters)) &&
        (point.xMeters <
            (xj - xi) *
                    (point.yMeters - yi) /
                    ((yj - yi) == 0 ? 1e-9 : (yj - yi)) +
                xi);
    if (intersects) {
      inside = !inside;
    }
  }
  return inside;
}
