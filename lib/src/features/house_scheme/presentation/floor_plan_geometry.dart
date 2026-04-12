import '../../../core/models/project.dart';

RoomLayoutRect buildNextRoomLayout(List<Room> rooms) {
  if (rooms.isEmpty) {
    return RoomLayoutRect.defaultRect();
  }

  final maxBottom = rooms
      .map((room) => room.layout.bottomMeters)
      .reduce((value, element) => value > element ? value : element);

  return RoomLayoutRect.defaultRect(
    xMeters: 0,
    yMeters: maxBottom + roomLayoutGapMeters,
  );
}

EnvelopeWallPlacement snapWallPlacement(
  EnvelopeWallPlacement placement, {
  required double sideLength,
}) {
  final maxOffset = (sideLength - minimumRoomLayoutDimensionMeters).clamp(
    0.0,
    sideLength,
  );
  final snappedOffset = _snapMeters(
    placement.offsetMeters.clamp(0.0, maxOffset),
  );
  final rawLength = placement.lengthMeters.clamp(
    minimumRoomLayoutDimensionMeters,
    sideLength,
  );
  final snappedLength = _snapMeters(rawLength);
  final maxLength = (sideLength - snappedOffset).clamp(
    minimumRoomLayoutDimensionMeters,
    sideLength,
  );

  return placement.copyWith(
    offsetMeters: snappedOffset,
    lengthMeters: snappedLength.clamp(
      minimumRoomLayoutDimensionMeters,
      maxLength,
    ),
  );
}

double _snapMeters(double value) {
  final steps = (value / roomLayoutSnapStepMeters).round();
  return steps * roomLayoutSnapStepMeters;
}
