import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

@DriftDatabase(tables: [ProjectEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(
          projectEntries,
          projectEntries.datasetVersion,
        );
        await migrator.addColumn(
          projectEntries,
          projectEntries.migratedFromDatasetVersion,
        );
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'smartcalc_mobile');
}
