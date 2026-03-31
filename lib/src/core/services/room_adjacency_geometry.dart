import '../models/project.dart';

class SharedRoomBoundary {
  const SharedRoomBoundary({
    required this.primaryRoomId,
    required this.secondaryRoomId,
    required this.segment,
  });

  final String primaryRoomId;
  final String secondaryRoomId;
  final HouseLineSegment segment;
}

List<SharedRoomBoundary> buildSharedRoomBoundaries(List<Room> rooms) {
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

  final mergedPartitions = <SharedRoomBoundary>[];
  for (final entry in partitions.entries) {
    final roomIds = entry.key.split(':');
    for (final segment in _mergeLineSegments(entry.value)) {
      mergedPartitions.add(
        SharedRoomBoundary(
          primaryRoomId: roomIds.first,
          secondaryRoomId: roomIds.last,
          segment: segment,
        ),
      );
    }
  }
  return mergedPartitions;
}

List<RoomLayoutRect> explodeRoomCells(List<RoomLayoutRect> cells) {
  final unique = <String, RoomLayoutRect>{};
  for (final source in cells) {
    final normalized = RoomLayoutRect(
      xMeters: source.xMeters,
      yMeters: source.yMeters,
      widthMeters: source.widthMeters,
      heightMeters: source.heightMeters,
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
