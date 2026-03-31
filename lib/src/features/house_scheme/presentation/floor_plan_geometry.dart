import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/project.dart';

const double defaultPlacedRoomWidthMeters = 3.0;
const double defaultPlacedRoomHeightMeters = 3.0;

RoomLayoutRect buildNextRoomLayout(List<Room> rooms) {
  if (rooms.isEmpty) {
    return RoomLayoutRect.defaultRect();
  }
  final lastRoom = rooms.last;
  return RoomLayoutRect.defaultRect(
    xMeters: lastRoom.layout.rightMeters + roomLayoutGapMeters,
    yMeters: lastRoom.layout.yMeters,
  );
}

RoomLayoutRect buildFirstAvailableRoomLayout(
  List<Room> rooms, {
  double widthMeters = defaultPlacedRoomWidthMeters,
  double heightMeters = defaultPlacedRoomHeightMeters,
}) {
  final normalized = snapRoomLayout(
    RoomLayoutRect(
      xMeters: 0,
      yMeters: 0,
      widthMeters: widthMeters,
      heightMeters: heightMeters,
    ),
  );
  if (rooms.isEmpty) {
    return normalized;
  }

  final maxRightMeters = rooms.fold<double>(
    normalized.widthMeters + roomLayoutGapMeters * 4,
    (maxValue, room) => math.max(maxValue, room.layout.rightMeters),
  );
  final maxBottomMeters = rooms.fold<double>(
    normalized.heightMeters + roomLayoutGapMeters * 4,
    (maxValue, room) => math.max(maxValue, room.layout.bottomMeters),
  );
  final limitX =
      maxRightMeters + normalized.widthMeters + roomLayoutGapMeters * 4;
  final limitY =
      maxBottomMeters + normalized.heightMeters + roomLayoutGapMeters * 4;

  for (
    double yMeters = 0;
    yMeters <= limitY;
    yMeters += roomLayoutSnapStepMeters
  ) {
    for (
      double xMeters = 0;
      xMeters <= limitX;
      xMeters += roomLayoutSnapStepMeters
    ) {
      final candidate = normalized.copyWith(xMeters: xMeters, yMeters: yMeters);
      final overlaps = rooms.any(
        (room) => layoutsOverlap(candidate, room.layout),
      );
      if (!overlaps) {
        return candidate;
      }
    }
  }

  return buildNextRoomLayout(rooms);
}

RoomLayoutRect snapRoomLayout(RoomLayoutRect layout) {
  return RoomLayoutRect(
    xMeters: math.max(0, snapToStep(layout.xMeters)),
    yMeters: math.max(0, snapToStep(layout.yMeters)),
    widthMeters: math.max(
      minimumRoomLayoutDimensionMeters,
      snapToStep(layout.widthMeters),
    ),
    heightMeters: math.max(
      minimumRoomLayoutDimensionMeters,
      snapToStep(layout.heightMeters),
    ),
  );
}

double snapToStep(double value) {
  return (value / roomLayoutSnapStepMeters).round() * roomLayoutSnapStepMeters;
}

bool layoutsEqual(RoomLayoutRect left, RoomLayoutRect right) {
  return left.xMeters == right.xMeters &&
      left.yMeters == right.yMeters &&
      left.widthMeters == right.widthMeters &&
      left.heightMeters == right.heightMeters;
}

bool layoutsOverlap(RoomLayoutRect left, RoomLayoutRect right) {
  return left.xMeters < right.rightMeters &&
      left.rightMeters > right.xMeters &&
      left.yMeters < right.bottomMeters &&
      left.bottomMeters > right.yMeters;
}

List<RoomLayoutRect> explodeRoomCells(List<RoomLayoutRect> cells) {
  final unique = <String, RoomLayoutRect>{};
  for (final source in cells) {
    final normalized = RoomLayoutRect(
      xMeters: math.max(0, snapToStep(source.xMeters)),
      yMeters: math.max(0, snapToStep(source.yMeters)),
      widthMeters: math.max(
        roomLayoutSnapStepMeters,
        snapToStep(source.widthMeters),
      ),
      heightMeters: math.max(
        roomLayoutSnapStepMeters,
        snapToStep(source.heightMeters),
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
  final result = unique.values.toList(growable: false);
  result.sort((left, right) {
    final yCompare = left.yMeters.compareTo(right.yMeters);
    if (yCompare != 0) {
      return yCompare;
    }
    return left.xMeters.compareTo(right.xMeters);
  });
  return result;
}

List<RoomLayoutRect> buildRoomCellEditTargets(
  List<Room> rooms,
  Room room, {
  required bool removing,
}) {
  final roomCells = explodeRoomCells(room.effectiveCells);
  if (removing) {
    return roomCells;
  }
  final occupied = <String>{
    for (final otherRoom in rooms)
      for (final cell in explodeRoomCells(otherRoom.effectiveCells))
        _gridCellKey(cell),
  };
  final candidates = <String, RoomLayoutRect>{};
  for (final cell in roomCells) {
    for (final neighbor in _neighborCells(cell)) {
      final key = _gridCellKey(neighbor);
      if (!occupied.contains(key) &&
          neighbor.xMeters >= 0 &&
          neighbor.yMeters >= 0) {
        candidates[key] = neighbor;
      }
    }
  }
  return candidates.values.toList(growable: false);
}

class RoomPartitionSegment {
  const RoomPartitionSegment({
    required this.primaryRoomId,
    required this.secondaryRoomId,
    required this.segment,
  });

  final String primaryRoomId;
  final String secondaryRoomId;
  final HouseLineSegment segment;
}

double deltaMetersForSide(RoomSide side, Offset delta, double pixelsPerMeter) {
  return switch (side) {
        RoomSide.top || RoomSide.bottom => delta.dx,
        RoomSide.left || RoomSide.right => delta.dy,
      } /
      pixelsPerMeter;
}

EnvelopeWallPlacement snapWallPlacement(
  EnvelopeWallPlacement placement, {
  required double sideLength,
}) {
  final snappedLength = math.min(
    sideLength,
    math.max(roomLayoutSnapStepMeters, snapToStep(placement.lengthMeters)),
  );
  final maxOffset = math.max(0.0, sideLength - snappedLength);
  return EnvelopeWallPlacement(
    side: placement.side,
    offsetMeters: math.min(
      maxOffset,
      math.max(0.0, snapToStep(placement.offsetMeters)),
    ),
    lengthMeters: snappedLength,
  );
}

bool wallPlacementsEqual(
  EnvelopeWallPlacement left,
  EnvelopeWallPlacement right,
) {
  return left.side == right.side &&
      left.offsetMeters == right.offsetMeters &&
      left.lengthMeters == right.lengthMeters;
}

Rect wallSegmentRect({
  required HouseLineSegment segment,
  required double pixelsPerMeter,
  required double canvasPadding,
  required double thicknessPixels,
}) {
  final normalized = segment.normalized();
  final left = canvasPadding + normalized.startXMeters * pixelsPerMeter;
  final top = canvasPadding + normalized.startYMeters * pixelsPerMeter;
  final width =
      (normalized.endXMeters - normalized.startXMeters).abs() * pixelsPerMeter;
  final height =
      (normalized.endYMeters - normalized.startYMeters).abs() * pixelsPerMeter;

  if (normalized.isHorizontal) {
    return Rect.fromLTWH(
      left,
      top - thicknessPixels / 2,
      width,
      thicknessPixels,
    );
  }
  return Rect.fromLTWH(
    left - thicknessPixels / 2,
    top,
    thicknessPixels,
    height,
  );
}

List<RoomPartitionSegment> buildRoomPartitions(List<Room> rooms) {
  final partitions = <String, List<HouseLineSegment>>{};
  for (var roomIndex = 0; roomIndex < rooms.length; roomIndex++) {
    final room = rooms[roomIndex];
    for (
      var otherIndex = roomIndex + 1;
      otherIndex < rooms.length;
      otherIndex++
    ) {
      final other = rooms[otherIndex];
      for (final roomCell in explodeRoomCells(room.effectiveCells)) {
        for (final otherCell in explodeRoomCells(other.effectiveCells)) {
          for (final roomEdge in _cellEdges(roomCell)) {
            for (final otherEdge in _cellEdges(otherCell)) {
              if (_segmentsEqual(roomEdge, otherEdge)) {
                final normalized = roomEdge.normalized();
                final key = '${room.id}:${other.id}';
                partitions.putIfAbsent(key, () => []).add(normalized);
              }
            }
          }
        }
      }
    }
  }
  final mergedPartitions = <RoomPartitionSegment>[];
  for (final entry in partitions.entries) {
    final roomIds = entry.key.split(':');
    for (final segment in _mergeLineSegments(entry.value)) {
      mergedPartitions.add(
        RoomPartitionSegment(
          primaryRoomId: roomIds.first,
          secondaryRoomId: roomIds.last,
          segment: segment,
        ),
      );
    }
  }
  return mergedPartitions;
}

List<RoomLayoutRect> _neighborCells(RoomLayoutRect cell) => [
  cell.copyWith(xMeters: cell.xMeters - roomLayoutSnapStepMeters),
  cell.copyWith(xMeters: cell.xMeters + roomLayoutSnapStepMeters),
  cell.copyWith(yMeters: cell.yMeters - roomLayoutSnapStepMeters),
  cell.copyWith(yMeters: cell.yMeters + roomLayoutSnapStepMeters),
];

String _gridCellKey(RoomLayoutRect cell) =>
    '${cell.xMeters}:${cell.yMeters}:${cell.widthMeters}:${cell.heightMeters}';

List<HouseLineSegment> _mergeLineSegments(List<HouseLineSegment> segments) {
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

double splitOffsetForSegmentTap(
  HouseLineSegment segment,
  Offset localPosition,
  double pixelsPerMeter,
) {
  final normalized = segment.normalized();
  final raw = normalized.isHorizontal
      ? localPosition.dx / pixelsPerMeter
      : localPosition.dy / pixelsPerMeter;
  return snapToStep(raw);
}

List<HouseLineSegment> _cellEdges(RoomLayoutRect cell) => [
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

bool _segmentsEqual(HouseLineSegment left, HouseLineSegment right) {
  final a = left.normalized();
  final b = right.normalized();
  return a.startXMeters == b.startXMeters &&
      a.startYMeters == b.startYMeters &&
      a.endXMeters == b.endXMeters &&
      a.endYMeters == b.endYMeters;
}
