import '../models/ground_floor_calculation.dart';
import '../models/project.dart';
import '../models/ventilation_settings.dart';
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
        constructions: _migrateConstructions(project),
        houseModel: _migrateHouseModel(project),
        groundFloorCalculations: _migrateGroundFloorCalculations(project),
        ventilationSettings: _migrateVentilationSettings(project),
        datasetVersion: currentDatasetVersion,
        migratedFromDatasetVersion: requiresDatasetMigration
            ? effectiveSourceDatasetVersion
            : project.migratedFromDatasetVersion,
        sourceProjectFormatVersion: currentProjectFormatVersion,
      ),
      wasMigrated: true,
    );
  }

  List<GroundFloorCalculation> _migrateGroundFloorCalculations(
    Project project,
  ) {
    if (project.sourceProjectFormatVersion >= 8) {
      if (project.sourceProjectFormatVersion >= 16) {
        return project.groundFloorCalculations;
      }
      return project.groundFloorCalculations
          .map((item) => item.copyWith(clearHouseElementId: true))
          .toList(growable: false);
    }
    return const [];
  }

  List<VentilationSettings> _migrateVentilationSettings(Project project) {
    if (project.sourceProjectFormatVersion < 18) {
      return const [];
    }
    final roomIds = project.houseModel.rooms.map((item) => item.id).toSet();
    return project.ventilationSettings
        .map(
          (item) => item.roomId == null || roomIds.contains(item.roomId)
              ? item
              : item.copyWith(clearRoomId: true),
        )
        .toList(growable: false);
  }

  List<Construction> _migrateConstructions(Project project) {
    if (project.sourceProjectFormatVersion >= 11) {
      return project.constructions;
    }
    return project.constructions
        .map((construction) {
          if (project.sourceProjectFormatVersion < 10) {
            if (construction.elementKind != ConstructionElementKind.floor ||
                construction.floorConstructionType != null) {
              return construction;
            }
            return construction.copyWith(
              floorConstructionType: FloorConstructionType.onGround,
            );
          }
          return construction;
        })
        .toList(growable: false);
  }

  HouseModel _migrateHouseModel(Project project) {
    final houseModel = project.houseModel;
    if (houseModel.planModelKind == HousePlanModelKind.wallGraph) {
      return houseModel;
    }
    if (houseModel.elements.isEmpty) {
      return HouseModel.bootstrapFromConstructions(project.constructions);
    }

    final rooms = houseModel.rooms.isEmpty
        ? [Room.defaultRoom()]
        : houseModel.rooms;
    final normalizedRooms = project.sourceProjectFormatVersion < 5
        ? _migrateRoomLayouts(rooms)
        : rooms;
    final roomsWithCells = project.sourceProjectFormatVersion < 13
        ? normalizedRooms
              .map(
                (room) => room.copyWith(
                  cells: room.effectiveCells.isEmpty
                      ? [room.layout]
                      : room.effectiveCells,
                  layout: RoomLayoutRect.boundingBox(room.effectiveCells),
                ),
              )
              .toList(growable: false)
        : normalizedRooms;
    final roomIds = roomsWithCells.map((item) => item.id).toSet();
    final normalizedElements = houseModel.elements
        .map(
          (item) => roomIds.contains(item.roomId)
              ? item
              : item.copyWith(roomId: roomsWithCells.first.id),
        )
        .toList(growable: false);
    final elements = project.sourceProjectFormatVersion < 6
        ? _migrateWallPlacements(
            rooms: roomsWithCells,
            elements: normalizedElements,
          )
        : normalizedElements;
    final wallElements = project.sourceProjectFormatVersion < 13
        ? _migrateWallSegments(rooms: roomsWithCells, elements: elements)
        : elements;
    final elementIds = wallElements.map((item) => item.id).toSet();
    final openings = houseModel.openings
        .where((item) => elementIds.contains(item.elementId))
        .map(
          (item) => project.sourceProjectFormatVersion < 15
              ? item.copyWith(leakagePreset: OpeningLeakagePreset.standard)
              : item,
        )
        .toList(growable: false);
    final heatingDevices = houseModel.heatingDevices
        .where((item) => roomIds.contains(item.roomId))
        .toList(growable: false);
    final wallConstructionIds = project.constructions
        .where((item) => item.elementKind == ConstructionElementKind.wall)
        .map((item) => item.id)
        .toSet();
    final internalPartitionConstructionId =
        houseModel.internalPartitionConstructionId;
    final normalizedInternalPartitionConstructionId =
        wallConstructionIds.contains(internalPartitionConstructionId)
        ? internalPartitionConstructionId
        : (wallConstructionIds.isEmpty ? null : wallConstructionIds.first);

    return houseModel.copyWith(
      rooms: roomsWithCells,
      elements: wallElements,
      openings: openings,
      heatingDevices: heatingDevices,
      internalPartitionConstructionId:
          normalizedInternalPartitionConstructionId,
      clearInternalPartitionConstructionId:
          normalizedInternalPartitionConstructionId == null,
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

    return elements
        .map((element) {
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
              .clamp(roomLayoutSnapStepMeters, sideLength)
              .toDouble();
          return element.copyWith(
            wallPlacement: EnvelopeWallPlacement(
              side: side,
              offsetMeters: 0,
              lengthMeters: lengthMeters,
            ),
            areaSquareMeters: lengthMeters * room.heightMeters,
          );
        })
        .toList(growable: false);
  }

  List<HouseEnvelopeElement> _migrateWallSegments({
    required List<Room> rooms,
    required List<HouseEnvelopeElement> elements,
  }) {
    final roomMap = {for (final room in rooms) room.id: room};
    return elements
        .map((element) {
          if (element.elementKind != ConstructionElementKind.wall) {
            return element.copyWith(
              source: EnvelopeElementSource.manual,
              clearLineSegment: true,
            );
          }
          final room = roomMap[element.roomId] ?? rooms.first;
          final lineSegment =
              element.lineSegment ??
              (element.wallPlacement == null
                  ? HouseLineSegment(
                      startXMeters: room.layout.xMeters,
                      startYMeters: room.layout.yMeters,
                      endXMeters: room.layout.rightMeters,
                      endYMeters: room.layout.yMeters,
                    )
                  : _lineSegmentForPlacement(room, element.wallPlacement!));
          return element.copyWith(
            lineSegment: lineSegment,
            source: EnvelopeElementSource.autoExteriorWall,
          );
        })
        .toList(growable: false);
  }

  HouseLineSegment _lineSegmentForPlacement(
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
}
