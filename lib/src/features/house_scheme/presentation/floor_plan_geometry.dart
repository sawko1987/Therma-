import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/project.dart';

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
  required Room room,
  required EnvelopeWallPlacement placement,
  required double pixelsPerMeter,
  required double canvasPadding,
  required double thicknessPixels,
}) {
  final layout = room.layout;
  final roomLeft = canvasPadding + layout.xMeters * pixelsPerMeter;
  final roomTop = canvasPadding + layout.yMeters * pixelsPerMeter;
  final widthPixels = layout.widthMeters * pixelsPerMeter;
  final heightPixels = layout.heightMeters * pixelsPerMeter;
  final offsetPixels = placement.offsetMeters * pixelsPerMeter;
  final lengthPixels = placement.lengthMeters * pixelsPerMeter;

  return switch (placement.side) {
    RoomSide.top => Rect.fromLTWH(
      roomLeft + offsetPixels,
      roomTop - thicknessPixels / 2,
      lengthPixels,
      thicknessPixels,
    ),
    RoomSide.bottom => Rect.fromLTWH(
      roomLeft + offsetPixels,
      roomTop + heightPixels - thicknessPixels / 2,
      lengthPixels,
      thicknessPixels,
    ),
    RoomSide.left => Rect.fromLTWH(
      roomLeft - thicknessPixels / 2,
      roomTop + offsetPixels,
      thicknessPixels,
      lengthPixels,
    ),
    RoomSide.right => Rect.fromLTWH(
      roomLeft + widthPixels - thicknessPixels / 2,
      roomTop + offsetPixels,
      thicknessPixels,
      lengthPixels,
    ),
  };
}
