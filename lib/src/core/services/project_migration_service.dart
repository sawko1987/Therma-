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
    final roomIds = rooms.map((item) => item.id).toSet();
    final elements = houseModel.elements
        .map(
          (item) => roomIds.contains(item.roomId)
              ? item
              : item.copyWith(roomId: rooms.first.id),
        )
        .toList(growable: false);

    return houseModel.copyWith(rooms: rooms, elements: elements);
  }
}
