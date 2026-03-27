import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/project.dart';
import '../models/versioning.dart';
import '../storage/app_database.dart';
import 'demo_project_seed.dart';
import 'interfaces.dart';
import 'project_migration_service.dart';

class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(this._database);

  final AppDatabase _database;
  final ProjectMigrationService _migrationService = const ProjectMigrationService();

  @override
  Future<List<Project>> listProjects() async {
    final query = _database.select(_database.projectEntries)
      ..orderBy([
        (table) => OrderingTerm(
          expression: table.updatedAtEpochMs,
          mode: OrderingMode.desc,
        ),
      ]);

    final rows = await query.get();
    final projects = <Project>[];
    for (final row in rows) {
      projects.add(await _mapRowToProject(row));
    }
    return projects;
  }

  @override
  Future<Project?> getProject(String id) async {
    final query = _database.select(_database.projectEntries)
      ..where((table) => table.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapRowToProject(row);
  }

  @override
  Future<void> saveProject(Project project) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _upsertProject(project, updatedAtEpochMs: now);
  }

  Future<void> _upsertProject(
    Project project, {
    required int updatedAtEpochMs,
  }) async {
    await _database
        .into(_database.projectEntries)
        .insertOnConflictUpdate(
          ProjectEntriesCompanion.insert(
            id: project.id,
            name: project.name,
            climatePointId: project.climatePointId,
            roomPreset: project.roomPreset.storageKey,
            payloadJson: jsonEncode(project.toJson()),
            projectFormatVersion: currentProjectFormatVersion,
            datasetVersion: Value(
              project.datasetVersion ?? legacyUnversionedDatasetVersion,
            ),
            migratedFromDatasetVersion: Value(
              project.migratedFromDatasetVersion,
            ),
            updatedAtEpochMs: updatedAtEpochMs,
          ),
        );
  }

  @override
  Future<void> seedDemoProjectIfEmpty() async {
    final countExpression = _database.projectEntries.id.count();
    final query = _database.selectOnly(_database.projectEntries)
      ..addColumns([countExpression]);
    final result = await query.getSingle();
    final existing = result.read(countExpression) ?? 0;

    if (existing > 0) {
      return;
    }

    for (final project in demoProjects) {
      await saveProject(project);
    }
  }

  Future<Project> _mapRowToProject(ProjectEntry row) async {
    final decoded = jsonDecode(row.payloadJson);
    final project = Project.fromJson(Map<String, dynamic>.from(decoded as Map));
    final migrated = _migrationService.migrate(project);
    if (migrated.wasMigrated) {
      await _upsertProject(
        migrated.project,
        updatedAtEpochMs: row.updatedAtEpochMs,
      );
    }
    return migrated.project;
  }
}
