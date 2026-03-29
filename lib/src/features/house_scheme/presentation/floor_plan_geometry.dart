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
  final partitions = <String, RoomPartitionSegment>{};
  for (var roomIndex = 0; roomIndex < rooms.length; roomIndex++) {
    final room = rooms[roomIndex];
    for (
      var otherIndex = roomIndex + 1;
      otherIndex < rooms.length;
      otherIndex++
    ) {
      final other = rooms[otherIndex];
      for (final roomCell in room.effectiveCells) {
        for (final otherCell in other.effectiveCells) {
          for (final roomEdge in _cellEdges(roomCell)) {
            for (final otherEdge in _cellEdges(otherCell)) {
              if (_segmentsEqual(roomEdge, otherEdge)) {
                final normalized = roomEdge.normalized();
                final key =
                    '${room.id}:${other.id}:${normalized.startXMeters}:${normalized.startYMeters}:${normalized.endXMeters}:${normalized.endYMeters}';
                partitions[key] = RoomPartitionSegment(
                  primaryRoomId: room.id,
                  secondaryRoomId: other.id,
                  segment: normalized,
                );
              }
            }
          }
        }
      }
    }
  }
  return partitions.values.toList(growable: false);
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
