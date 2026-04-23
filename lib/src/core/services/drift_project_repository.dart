import 'dart:convert';

import 'package:drift/drift.dart';

import '../logging/app_logging.dart';
import '../models/catalog.dart';
import '../models/project.dart';
import '../models/versioning.dart';
import '../storage/app_database.dart' as db;
import 'demo_project_seed.dart';
import 'interfaces.dart';
import 'project_migration_service.dart';

const _constructionLibraryEntryId = '__construction_library__';
const _constructionLibraryPayloadVersion = 1;
const _favoriteMaterialsEntryId = '__favorite_materials__';
const _favoriteMaterialsPayloadVersion = 1;
const _demoSeedStateEntryId = '__demo_seed_state__';
const _demoSeedStatePayloadVersion = 1;
const _objectSeedStateEntryId = '__object_seed_state__';
const _objectSeedStatePayloadVersion = 1;
const _objectEntryIdPrefix = '__object__';
const _objectPayloadVersion = 1;
const _appPreferencesEntryId = '__app_preferences__';
const _appPreferencesPayloadVersion = 1;

class DriftProjectRepository
    implements
        ProjectRepository,
        ConstructionLibraryRepository,
        ObjectRepository,
        FavoriteMaterialsRepository,
        OpeningCatalogRepository,
        AppPreferencesRepository {
  DriftProjectRepository(this._database, {AppLogger? logger})
    : _logger = logger;

  final db.AppDatabase _database;
  final AppLogger? _logger;
  final ProjectMigrationService _migrationService =
      const ProjectMigrationService();

  @override
  Future<List<Project>> listProjects() async {
    _logger?.debug('List projects', category: AppLogCategory.storage);
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
      if (_isTechnicalEntry(row.id)) {
        continue;
      }
      projects.add(await _mapRowToProject(row));
    }
    return projects;
  }

  @override
  Future<Project?> getProject(String id) async {
    if (_isTechnicalEntry(id)) {
      return null;
    }
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
    _logger?.debug(
      'Persist project entry',
      category: AppLogCategory.storage,
      context: {
        'projectId': project.id,
        'payloadJson': jsonEncode(project.toJson()),
      },
    );
    await _upsertProject(project, updatedAtEpochMs: now);
    await _mergeProjectConstructionsIntoLibrary(project.constructions);
  }

  @override
  Future<void> deleteProject(String id) async {
    if (_isTechnicalEntry(id)) {
      return;
    }
    _logger?.info(
      'Delete project entry',
      category: AppLogCategory.storage,
      context: {'projectId': id},
    );
    final query = _database.delete(_database.projectEntries)
      ..where((table) => table.id.equals(id));
    await query.go();
  }

  Future<void> _upsertProject(
    Project project, {
    required int updatedAtEpochMs,
  }) async {
    await _database
        .into(_database.projectEntries)
        .insertOnConflictUpdate(
          db.ProjectEntriesCompanion.insert(
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
    final existingSeedState = await _getDemoSeedStateRow();
    if (existingSeedState != null) {
      return;
    }

    final existing = (await listProjects()).length;

    if (existing == 0) {
      for (final project in demoProjects) {
        await saveProject(project);
      }
    }

    await _saveDemoSeedState();
  }

  Future<db.ProjectEntry?> _getDemoSeedStateRow() async {
    final query = _database.select(_database.projectEntries)
      ..where((table) => table.id.equals(_demoSeedStateEntryId));
    return query.getSingleOrNull();
  }

  Future<void> _saveDemoSeedState() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database
        .into(_database.projectEntries)
        .insertOnConflictUpdate(
          db.ProjectEntriesCompanion.insert(
            id: _demoSeedStateEntryId,
            name: 'Demo seed state',
            climatePointId: 'system',
            roomPreset: RoomPreset.livingRoom.storageKey,
            payloadJson: jsonEncode({
              'type': 'demoSeedState',
              'payloadVersion': _demoSeedStatePayloadVersion,
              'seededAtEpochMs': now,
            }),
            projectFormatVersion: currentProjectFormatVersion,
            datasetVersion: const Value(currentDatasetVersion),
            migratedFromDatasetVersion: const Value(null),
            updatedAtEpochMs: now,
          ),
        );
  }

  @override
  Future<List<Construction>> listConstructions() async {
    await _ensureLibrarySeeded();
    final row = await _getLibraryRow();
    return row == null ? const [] : _decodeLibraryRow(row);
  }

  @override
  Future<Construction?> getConstruction(String id) async {
    final constructions = await listConstructions();
    for (final construction in constructions) {
      if (construction.id == id) {
        return construction;
      }
    }
    return null;
  }

  @override
  Future<void> saveConstruction(Construction construction) async {
    _logger?.info(
      'Save construction in library store',
      category: AppLogCategory.storage,
      context: {'constructionId': construction.id, 'title': construction.title},
    );
    final constructions = await listConstructions();
    final updated = [
      for (final item in constructions)
        if (item.id == construction.id) construction else item,
      if (!constructions.any((item) => item.id == construction.id))
        construction,
    ];
    await _saveLibrary(updated);
  }

  @override
  Future<void> deleteConstruction(String id) async {
    _logger?.info(
      'Delete construction from library store',
      category: AppLogCategory.storage,
      context: {'constructionId': id},
    );
    final constructions = await listConstructions();
    await _saveLibrary([
      for (final item in constructions)
        if (item.id != id) item,
    ]);
  }

  @override
  Future<Set<String>> listFavoriteMaterialIds() async {
    final query = _database.select(_database.projectEntries)
      ..where((table) => table.id.equals(_favoriteMaterialsEntryId));
    final row = await query.getSingleOrNull();
    if (row == null) {
      return <String>{};
    }
    final payload = Map<String, dynamic>.from(
      jsonDecode(row.payloadJson) as Map,
    );
    return ((payload['favoriteMaterialIds'] as List<dynamic>?) ?? const [])
        .map((item) => item as String)
        .toSet();
  }

  @override
  Future<void> saveFavoriteMaterialIds(Set<String> ids) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database
        .into(_database.projectEntries)
        .insertOnConflictUpdate(
          db.ProjectEntriesCompanion.insert(
            id: _favoriteMaterialsEntryId,
            name: 'Favorite materials',
            climatePointId: 'favorites',
            roomPreset: RoomPreset.livingRoom.storageKey,
            payloadJson: jsonEncode({
              'type': 'favoriteMaterials',
              'payloadVersion': _favoriteMaterialsPayloadVersion,
              'favoriteMaterialIds': ids.toList(growable: false),
            }),
            projectFormatVersion: currentProjectFormatVersion,
            datasetVersion: const Value(currentDatasetVersion),
            migratedFromDatasetVersion: const Value(null),
            updatedAtEpochMs: now,
          ),
        );
  }

  @override
  Future<bool> getConstructionPickerSwipeTutorialSeen() async {
    final query = _database.select(_database.projectEntries)
      ..where((table) => table.id.equals(_appPreferencesEntryId));
    final row = await query.getSingleOrNull();
    if (row == null) {
      return false;
    }
    final payload = Map<String, dynamic>.from(
      jsonDecode(row.payloadJson) as Map,
    );
    return payload['constructionPickerSwipeTutorialSeen'] == true;
  }

  @override
  Future<void> setConstructionPickerSwipeTutorialSeen(bool seen) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database
        .into(_database.projectEntries)
        .insertOnConflictUpdate(
          db.ProjectEntriesCompanion.insert(
            id: _appPreferencesEntryId,
            name: 'App preferences',
            climatePointId: 'preferences',
            roomPreset: RoomPreset.livingRoom.storageKey,
            payloadJson: jsonEncode({
              'type': 'appPreferences',
              'payloadVersion': _appPreferencesPayloadVersion,
              'constructionPickerSwipeTutorialSeen': seen,
            }),
            projectFormatVersion: currentProjectFormatVersion,
            datasetVersion: const Value(currentDatasetVersion),
            migratedFromDatasetVersion: const Value(null),
            updatedAtEpochMs: now,
          ),
        );
  }

  @override
  Future<List<DesignObject>> listObjects() async {
    _logger?.debug('List design objects', category: AppLogCategory.storage);
    final query = _database.select(_database.projectEntries)
      ..orderBy([
        (table) => OrderingTerm(
          expression: table.updatedAtEpochMs,
          mode: OrderingMode.desc,
        ),
      ]);
    final rows = await query.get();
    return rows
        .where((row) => row.id.startsWith(_objectEntryIdPrefix))
        .map(_decodeObjectRow)
        .toList(growable: false);
  }

  @override
  Future<DesignObject?> getObject(String id) async {
    final query = _database.select(_database.projectEntries)
      ..where((table) => table.id.equals(_buildObjectEntryId(id)));
    final row = await query.getSingleOrNull();
    return row == null ? null : _decodeObjectRow(row);
  }

  @override
  Future<void> saveObject(DesignObject object) async {
    _logger?.info(
      'Save design object',
      category: AppLogCategory.storage,
      context: {
        'objectId': object.id,
        'projectId': object.projectId,
        'customerPhone': object.customerPhone,
        'address': object.address,
      },
    );
    await _database
        .into(_database.projectEntries)
        .insertOnConflictUpdate(
          db.ProjectEntriesCompanion.insert(
            id: _buildObjectEntryId(object.id),
            name: object.title,
            climatePointId: 'object',
            roomPreset: RoomPreset.livingRoom.storageKey,
            payloadJson: jsonEncode({
              'type': 'designObject',
              'payloadVersion': _objectPayloadVersion,
              'object': object.toJson(),
            }),
            projectFormatVersion: currentProjectFormatVersion,
            datasetVersion: const Value(currentDatasetVersion),
            migratedFromDatasetVersion: const Value(null),
            updatedAtEpochMs: object.updatedAtEpochMs,
          ),
        );
  }

  @override
  Future<void> deleteObject(String id) async {
    _logger?.info(
      'Delete design object',
      category: AppLogCategory.storage,
      context: {'objectId': id},
    );
    final query = _database.delete(_database.projectEntries)
      ..where((table) => table.id.equals(_buildObjectEntryId(id)));
    await query.go();
  }

  @override
  Future<void> seedObjectsIfEmpty() async {
    final existingSeedState = await _getObjectSeedStateRow();
    if (existingSeedState != null) {
      return;
    }

    final existingObjectsQuery = _database.select(_database.projectEntries)
      ..where((table) => table.id.like('$_objectEntryIdPrefix%'));
    final existingObjects = await existingObjectsQuery.get();
    if (existingObjects.isNotEmpty) {
      await _saveObjectSeedState();
      return;
    }

    final projectRows =
        await (_database.select(_database.projectEntries)..orderBy([
              (table) => OrderingTerm(
                expression: table.updatedAtEpochMs,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();

    for (final row in projectRows) {
      if (_isTechnicalEntry(row.id)) {
        continue;
      }
      final project = await _mapRowToProject(row);
      final now = DateTime.now().millisecondsSinceEpoch;
      await saveObject(
        DesignObject(
          id: 'object-${project.id}',
          title: project.name,
          address: '',
          description: '',
          customerPhone: '',
          climatePointId: project.climatePointId,
          projectId: project.id,
          updatedAtEpochMs: now,
        ),
      );
    }

    await _saveObjectSeedState();
  }

  Future<Project> _mapRowToProject(db.ProjectEntry row) async {
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

  Future<db.ProjectEntry?> _getLibraryRow() async {
    final query = _database.select(_database.projectEntries)
      ..where((table) => table.id.equals(_constructionLibraryEntryId));
    return query.getSingleOrNull();
  }

  Future<db.ProjectEntry?> _getObjectSeedStateRow() async {
    final query = _database.select(_database.projectEntries)
      ..where((table) => table.id.equals(_objectSeedStateEntryId));
    return query.getSingleOrNull();
  }

  Future<void> _saveObjectSeedState() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database
        .into(_database.projectEntries)
        .insertOnConflictUpdate(
          db.ProjectEntriesCompanion.insert(
            id: _objectSeedStateEntryId,
            name: 'Object seed state',
            climatePointId: 'system',
            roomPreset: RoomPreset.livingRoom.storageKey,
            payloadJson: jsonEncode({
              'type': 'objectSeedState',
              'payloadVersion': _objectSeedStatePayloadVersion,
              'seededAtEpochMs': now,
            }),
            projectFormatVersion: currentProjectFormatVersion,
            datasetVersion: const Value(currentDatasetVersion),
            migratedFromDatasetVersion: const Value(null),
            updatedAtEpochMs: now,
          ),
        );
  }

  Future<void> _ensureLibrarySeeded() async {
    final existing = await _getLibraryRow();
    if (existing != null) {
      return;
    }

    final query = _database.select(_database.projectEntries)
      ..where((table) => table.id.isNotValue(_constructionLibraryEntryId));
    final rows = await query.get();
    final constructionsById = <String, Construction>{};
    for (final row in rows) {
      if (_isTechnicalEntry(row.id)) {
        continue;
      }
      final project = await _mapRowToProject(row);
      for (final construction in project.constructions) {
        constructionsById.putIfAbsent(construction.id, () => construction);
      }
    }
    await _saveLibrary(constructionsById.values.toList(growable: false));
  }

  Future<void> _mergeProjectConstructionsIntoLibrary(
    List<Construction> constructions,
  ) async {
    final existing = await listConstructions();
    final merged = {
      for (final item in existing) item.id: item,
      for (final item in constructions) item.id: item,
    }.values.toList(growable: false);
    await _saveLibrary(merged);
  }

  List<Construction> _decodeLibraryRow(db.ProjectEntry row) {
    final payload = Map<String, dynamic>.from(
      jsonDecode(row.payloadJson) as Map,
    );
    final items = (payload['constructions'] as List<dynamic>? ?? const []);
    return items
        .map(
          (item) =>
              Construction.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<void> _saveLibrary(List<Construction> constructions) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database
        .into(_database.projectEntries)
        .insertOnConflictUpdate(
          db.ProjectEntriesCompanion.insert(
            id: _constructionLibraryEntryId,
            name: 'Construction library',
            climatePointId: 'library',
            roomPreset: RoomPreset.livingRoom.storageKey,
            payloadJson: jsonEncode({
              'type': 'constructionLibrary',
              'payloadVersion': _constructionLibraryPayloadVersion,
              'constructions': constructions
                  .map((item) => item.toJson())
                  .toList(growable: false),
            }),
            projectFormatVersion: currentProjectFormatVersion,
            datasetVersion: const Value(currentDatasetVersion),
            migratedFromDatasetVersion: const Value(null),
            updatedAtEpochMs: now,
          ),
        );
  }

  DesignObject _decodeObjectRow(db.ProjectEntry row) {
    final payload = Map<String, dynamic>.from(
      jsonDecode(row.payloadJson) as Map,
    );
    return DesignObject.fromJson(
      Map<String, dynamic>.from(payload['object'] as Map),
    );
  }

  bool _isTechnicalEntry(String id) {
    return id == _constructionLibraryEntryId ||
        id == _appPreferencesEntryId ||
        id == _demoSeedStateEntryId ||
        id == _objectSeedStateEntryId ||
        id == _favoriteMaterialsEntryId ||
        id.startsWith(_objectEntryIdPrefix);
  }

  String _buildObjectEntryId(String objectId) =>
      '$_objectEntryIdPrefix$objectId';

  @override
  Future<List<OpeningTypeEntry>> listEntries() async {
    _logger?.debug(
      'Load opening catalog entries from store',
      category: AppLogCategory.storage,
    );
    final rows =
        await (_database.select(_database.storedOpeningCatalogEntries)
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.updatedAtEpochMs,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return rows
        .map(
          (row) => OpeningTypeEntry.fromJson(
            Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveEntry(OpeningTypeEntry entry) async {
    _logger?.info(
      'Save opening catalog entry',
      category: AppLogCategory.storage,
      context: {'entryId': entry.id, 'title': entry.title},
    );
    await _database
        .into(_database.storedOpeningCatalogEntries)
        .insertOnConflictUpdate(
          db.StoredOpeningCatalogEntriesCompanion.insert(
            id: entry.id,
            payloadJson: jsonEncode(entry.toJson()),
            updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<void> deleteEntry(String id) async {
    _logger?.info(
      'Delete opening catalog entry',
      category: AppLogCategory.storage,
      context: {'entryId': id},
    );
    await (_database.delete(
      _database.storedOpeningCatalogEntries,
    )..where((table) => table.id.equals(id))).go();
  }
}
