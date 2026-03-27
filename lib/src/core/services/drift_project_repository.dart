import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/project.dart';
import '../storage/app_database.dart';
import 'demo_project_seed.dart';
import 'interfaces.dart';

class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(this._database);

  final AppDatabase _database;

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
    return rows.map(_mapRowToProject).toList(growable: false);
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
            updatedAtEpochMs: now,
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

  Project _mapRowToProject(ProjectEntry row) {
    final decoded = jsonDecode(row.payloadJson);
    return Project.fromJson(Map<String, dynamic>.from(decoded as Map));
  }
}
