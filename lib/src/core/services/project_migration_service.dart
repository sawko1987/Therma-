import '../models/project.dart';
import '../models/versioning.dart';

class MigratedProject {
  const MigratedProject({required this.project, required this.wasMigrated});

  final Project project;
  final bool wasMigrated;
}

class ProjectMigrationService {
  const ProjectMigrationService();

  MigratedProject migrate(Project project) {
    final requiresFormatMigration =
        project.sourceProjectFormatVersion < currentProjectFormatVersion;
    final sourceDatasetVersion = project.datasetVersion;
    final effectiveSourceDatasetVersion =
        sourceDatasetVersion ?? legacyUnversionedDatasetVersion;
    final requiresDatasetMigration =
        sourceDatasetVersion == null ||
        sourceDatasetVersion != currentDatasetVersion;
    final requiresMigration =
        requiresFormatMigration || requiresDatasetMigration;

    if (!requiresMigration) {
      return MigratedProject(project: project, wasMigrated: false);
    }

    return MigratedProject(
      project: project.copyWith(
        houseModel: _migrateHouseModel(project),
        datasetVersion: currentDatasetVersion,
        migratedFromDatasetVersion: requiresDatasetMigration
            ? effectiveSourceDatasetVersion
            : project.migratedFromDatasetVersion,
        sourceProjectFormatVersion: currentProjectFormatVersion,
      ),
      wasMigrated: true,
    );
  }

  HouseModel _migrateHouseModel(Project project) {
    final houseModel = project.houseModel;
    if (houseModel.elements.isEmpty) {
      return HouseModel.bootstrapFromConstructions(project.constructions);
    }

    final rooms = houseModel.rooms.isEmpty
        ? [Room.defaultRoom()]
        : houseModel.rooms;
    final normalizedRooms = project.sourceProjectFormatVersion < 5
        ? _migrateRoomLayouts(rooms)
        : rooms;
    final roomIds = normalizedRooms.map((item) => item.id).toSet();
    final normalizedElements = houseModel.elements
        .map(
          (item) => roomIds.contains(item.roomId)
              ? item
              : item.copyWith(roomId: normalizedRooms.first.id),
        )
        .toList(growable: false);
    final elements = project.sourceProjectFormatVersion < 6
        ? _migrateWallPlacements(
            rooms: normalizedRooms,
            elements: normalizedElements,
          )
        : normalizedElements;
    final elementIds = elements.map((item) => item.id).toSet();
    final openings = houseModel.openings
        .where((item) => elementIds.contains(item.elementId))
        .toList(growable: false);
    final heatingDevices = houseModel.heatingDevices
        .where((item) => roomIds.contains(item.roomId))
        .toList(growable: false);

    return houseModel.copyWith(
      rooms: normalizedRooms,
      elements: elements,
      openings: openings,
      heatingDevices: heatingDevices,
    );
  }

  List<Room> _migrateRoomLayouts(List<Room> rooms) {
    var cursorX = 0.0;
    final migratedRooms = <Room>[];
    for (final room in rooms) {
      final layout = RoomLayoutRect.squareFromArea(
        room.areaSquareMeters,
        xMeters: cursorX,
        yMeters: 0,
      );
      migratedRooms.add(room.copyWith(layout: layout));
      cursorX = layout.rightMeters + roomLayoutGapMeters;
    }
    return migratedRooms;
  }

  List<HouseEnvelopeElement> _migrateWallPlacements({
    required List<Room> rooms,
    required List<HouseEnvelopeElement> elements,
  }) {
    final roomMap = {for (final room in rooms) room.id: room};
    final roomWallIndexes = <String, int>{};

    return elements.map((element) {
      if (element.elementKind != ConstructionElementKind.wall) {
        return element.copyWith(clearWallPlacement: true);
      }
      final room = roomMap[element.roomId] ?? rooms.first;
      final wallIndex = roomWallIndexes.update(
        room.id,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      final side = RoomSide.values[wallIndex % RoomSide.values.length];
      final sideLength = room.layout.sideLength(side);
      final requestedLength = element.areaSquareMeters / room.heightMeters;
      final lengthMeters = requestedLength
          .clamp(
            roomLayoutSnapStepMeters,
            sideLength,
          )
          .toDouble();
      return element.copyWith(
        wallPlacement: EnvelopeWallPlacement(
          side: side,
          offsetMeters: 0,
          lengthMeters: lengthMeters,
        ),
        areaSquareMeters: lengthMeters * room.heightMeters,
      );
    }).toList(growable: false);
  }
}
