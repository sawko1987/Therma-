import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../logging/app_logging.dart';
import '../models/versioning.dart';

part 'app_database.g.dart';

class ProjectEntries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get climatePointId => text().named('climate_point_id')();
  TextColumn get roomPreset => text().named('room_preset')();
  TextColumn get payloadJson => text().named('payload_json')();
  IntColumn get projectFormatVersion =>
      integer().named('project_format_version')();
  TextColumn get datasetVersion => text()
      .named('dataset_version')
      .withDefault(const Constant(legacyUnversionedDatasetVersion))();
  TextColumn get migratedFromDatasetVersion =>
      text().named('migrated_from_dataset_version').nullable()();
  IntColumn get updatedAtEpochMs => integer().named('updated_at_epoch_ms')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class StoredOpeningCatalogEntries extends Table {
  TextColumn get id => text()();
  TextColumn get payloadJson => text().named('payload_json')();
  IntColumn get updatedAtEpochMs => integer().named('updated_at_epoch_ms')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class StoredHeatingDeviceCatalogEntries extends Table {
  TextColumn get id => text()();
  TextColumn get payloadJson => text().named('payload_json')();
  IntColumn get updatedAtEpochMs => integer().named('updated_at_epoch_ms')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ProjectEntries,
    StoredOpeningCatalogEntries,
    StoredHeatingDeviceCatalogEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({AppLogger? logger}) : _logger = logger, super(_openConnection());

  AppDatabase.forTesting(super.e, {AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      _logger?.info(
        'Run drift migration',
        category: AppLogCategory.storage,
        context: {'from': from, 'to': to},
      );
      if (from < 2) {
        await migrator.addColumn(projectEntries, projectEntries.datasetVersion);
        await migrator.addColumn(
          projectEntries,
          projectEntries.migratedFromDatasetVersion,
        );
      }
      if (from < 3) {
        await migrator.createTable(storedOpeningCatalogEntries);
      }
      if (from < 4) {
        await migrator.createTable(storedHeatingDeviceCatalogEntries);
      }
      _logger?.info(
        'Drift migration completed',
        category: AppLogCategory.storage,
        context: {'from': from, 'to': to},
      );
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'smartcalc_mobile');
}
