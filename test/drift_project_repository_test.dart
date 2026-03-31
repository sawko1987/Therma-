import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/models/versioning.dart';
import 'package:smartcalc_mobile/src/core/services/drift_project_repository.dart';
import 'package:smartcalc_mobile/src/core/storage/app_database.dart';

import 'support/fakes.dart';

void main() {
  late AppDatabase database;
  late DriftProjectRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftProjectRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('project json round-trip preserves layers and enum values', () {
    final source =
        buildTestProject(
          climatePointId: 'novosibirsk',
          roomPreset: RoomPreset.attic,
          construction: Construction(
            id: 'crawl-floor',
            title: 'Пол над техподпольем',
            elementKind: ConstructionElementKind.floor,
            floorConstructionType: FloorConstructionType.overCrawlSpace,
            crawlSpaceVentilationMode: CrawlSpaceVentilationMode.ventilated,
            layers: buildWallConstruction().layers,
          ),
        ).copyWith(
          customMaterials: const [
            MaterialEntry(
              id: 'custom-material-1',
              name: 'Мой материал',
              category: 'Пользовательские',
              thermalConductivity: 0.031,
              vaporPermeability: 0.1,
              aliases: ['тест'],
            ),
          ],
        );

    final restored = Project.fromJson(source.toJson());

    expect(restored.id, source.id);
    expect(restored.name, source.name);
    expect(restored.climatePointId, source.climatePointId);
    expect(restored.roomPreset, source.roomPreset);
    expect(restored.constructions, hasLength(source.constructions.length));
    expect(
      restored.constructions.single.elementKind,
      source.constructions.single.elementKind,
    );
    expect(
      restored.constructions.single.floorConstructionType,
      source.constructions.single.floorConstructionType,
    );
    expect(
      restored.constructions.single.crawlSpaceVentilationMode,
      source.constructions.single.crawlSpaceVentilationMode,
    );
    expect(
      restored.constructions.single.layers,
      hasLength(source.constructions.single.layers.length),
    );
    expect(
      restored.constructions.single.layers.last.kind,
      source.constructions.single.layers.last.kind,
    );
    expect(restored.houseModel.elements, hasLength(1));
    final restoredElement = restored.houseModel.elements.single;
    expect(restoredElement.constructionId, source.constructions.single.id);
    expect(restoredElement.elementKind, ConstructionElementKind.floor);
    expect(restoredElement.wallPlacement, isNull);
    expect(restored.houseModel.rooms.single.layout.xMeters, 0);
    expect(restored.houseModel.rooms.single.layout.widthMeters, 4);
    expect(restored.customMaterials, hasLength(1));
    expect(restored.customMaterials.single.id, 'custom-material-1');
    expect(
      restored.heatingEconomicsSettings.electricityPricePerKwh,
      defaultElectricityPricePerKwh,
    );
    expect(
      restored.heatingEconomicsSettings.gasBoilerEfficiency,
      defaultGasBoilerEfficiency,
    );
    expect(restored.datasetVersion, currentDatasetVersion);
    expect(restored.migratedFromDatasetVersion, isNull);
  });

  test('saveProject preserves multi-cell rooms and segmented walls', () async {
    final source = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Дом',
        rooms: [
          buildRoom(
            cells: const [
              RoomLayoutRect(
                xMeters: 0,
                yMeters: 0,
                widthMeters: 0.5,
                heightMeters: 0.5,
              ),
              RoomLayoutRect(
                xMeters: 0.5,
                yMeters: 0,
                widthMeters: 0.5,
                heightMeters: 0.5,
              ),
              RoomLayoutRect(
                xMeters: 0.5,
                yMeters: 0.5,
                widthMeters: 0.5,
                heightMeters: 0.5,
              ),
            ],
          ),
        ],
        elements: const [
          HouseEnvelopeElement(
            id: 'wall-top-a',
            roomId: defaultRoomId,
            title: 'Стена A',
            elementKind: ConstructionElementKind.wall,
            areaSquareMeters: 1.35,
            constructionId: 'wall',
            lineSegment: HouseLineSegment(
              startXMeters: 0,
              startYMeters: 0,
              endXMeters: 0.5,
              endYMeters: 0,
            ),
            source: EnvelopeElementSource.autoExteriorWall,
          ),
          HouseEnvelopeElement(
            id: 'wall-top-b',
            roomId: defaultRoomId,
            title: 'Стена B',
            elementKind: ConstructionElementKind.wall,
            areaSquareMeters: 1.35,
            constructionId: 'wall',
            lineSegment: HouseLineSegment(
              startXMeters: 0.5,
              startYMeters: 0,
              endXMeters: 1.0,
              endYMeters: 0,
            ),
            source: EnvelopeElementSource.autoExteriorWall,
          ),
        ],
        openings: const [
          EnvelopeOpening(
            id: 'opening-window',
            elementId: 'wall-top-a',
            title: 'Окно',
            kind: OpeningKind.window,
            areaSquareMeters: 0.4,
            heatTransferCoefficient: 1.0,
          ),
        ],
      ),
    );

    await repository.saveProject(source);
    final restored = await repository.getProject(source.id);

    expect(restored, isNotNull);
    expect(restored!.houseModel.rooms.single.effectiveCells, hasLength(3));
    expect(
      restored.houseModel.elements.map((item) => item.id),
      containsAll(['wall-top-a', 'wall-top-b']),
    );
    expect(restored.houseModel.openings.single.elementId, 'wall-top-a');
  });

  test('project json accepts legacy payload without dataset version', () {
    final legacyPayload = {
      'projectFormatVersion': 1,
      'id': 'legacy',
      'name': 'Legacy project',
      'climatePointId': 'moscow',
      'roomPreset': 'livingRoom',
      'constructions': [
        {
          'id': 'wall',
          'title': 'Наружная стена',
          'elementKind': 'wall',
          'layers': [
            {
              'id': 'aac',
              'materialId': 'aac_d500',
              'kind': 'masonry',
              'thicknessMm': 375,
              'enabled': true,
            },
          ],
        },
      ],
    };

    final restored = Project.fromJson(legacyPayload);

    expect(restored.datasetVersion, isNull);
    expect(restored.migratedFromDatasetVersion, isNull);
    expect(restored.houseModel.elements, hasLength(4));
    expect(restored.customMaterials, isEmpty);
    expect(restored.sourceProjectFormatVersion, 1);
    expect(restored.heatingEconomicsSettings.heatPumpCop, defaultHeatPumpCop);
  });

  test('project json defaults opening leakage preset for legacy payload', () {
    final legacyPayload = {
      'projectFormatVersion': 14,
      'id': 'legacy-opening',
      'name': 'Legacy opening project',
      'climatePointId': 'moscow',
      'roomPreset': 'livingRoom',
      'constructions': [
        {
          'id': 'wall',
          'title': 'Наружная стена',
          'elementKind': 'wall',
          'layers': [
            {
              'id': 'aac',
              'materialId': 'aac_d500',
              'kind': 'masonry',
              'thicknessMm': 375,
              'enabled': true,
            },
          ],
        },
      ],
      'houseModel': {
        'id': 'house-model',
        'title': 'Дом',
        'rooms': [Room.defaultRoom().toJson()],
        'elements': [
          const HouseEnvelopeElement(
            id: 'wall-main',
            roomId: defaultRoomId,
            title: 'Стена',
            elementKind: ConstructionElementKind.wall,
            areaSquareMeters: 10,
            constructionId: 'wall',
          ).toJson(),
        ],
        'openings': [
          const {
            'id': 'opening-window',
            'elementId': 'wall-main',
            'title': 'Окно',
            'kind': 'window',
            'areaSquareMeters': 2.0,
            'heatTransferCoefficient': 1.0,
          },
        ],
      },
    };

    final restored = Project.fromJson(legacyPayload);

    expect(
      restored.houseModel.openings.single.leakagePreset,
      OpeningLeakagePreset.standard,
    );
  });

  test('project json rejects future project format version', () {
    expect(
      () => Project.fromJson({
        'projectFormatVersion': currentProjectFormatVersion + 1,
        'id': 'future',
        'name': 'Future project',
        'climatePointId': 'moscow',
        'roomPreset': 'livingRoom',
        'constructions': const [],
      }),
      throwsStateError,
    );
  });

  test('seedDemoProjectIfEmpty inserts demo project only once', () async {
    await repository.seedDemoProjectIfEmpty();
    final firstPass = await repository.listProjects();

    await repository.seedDemoProjectIfEmpty();
    final secondPass = await repository.listProjects();

    expect(firstPass, hasLength(1));
    expect(secondPass, hasLength(1));
    expect(secondPass.single.id, 'demo-project');
    expect(secondPass.single.datasetVersion, currentDatasetVersion);
    expect(secondPass.single.houseModel.elements, hasLength(1));
  });

  test(
    'saveProject updates existing row instead of inserting duplicate',
    () async {
      final original = buildTestProject();
      final updated = Project(
        id: original.id,
        name: 'Updated demo project',
        climatePointId: original.climatePointId,
        roomPreset: original.roomPreset,
        constructions: original.constructions,
        houseModel: original.houseModel,
      );

      await repository.saveProject(original);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.saveProject(updated);

      final projects = await repository.listProjects();
      final stored = await repository.getProject(original.id);

      expect(projects, hasLength(1));
      expect(stored?.name, 'Updated demo project');
      expect(stored?.datasetVersion, currentDatasetVersion);
    },
  );

  test('listProjects returns most recently updated project first', () async {
    final first = buildTestProject();
    final second = buildTestProject(
      climatePointId: 'novosibirsk',
      roomPreset: RoomPreset.attic,
      construction: Construction(
        id: 'roof',
        title: 'Кровля',
        elementKind: ConstructionElementKind.roof,
        layers: first.constructions.single.layers,
      ),
    );
    final renamedSecond = Project(
      id: 'roof-project',
      name: 'Новосибирск / кровля',
      climatePointId: second.climatePointId,
      roomPreset: second.roomPreset,
      constructions: second.constructions,
      houseModel: second.houseModel,
    );

    await repository.saveProject(first);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repository.saveProject(renamedSecond);

    final projects = await repository.listProjects();

    expect(projects.map((item) => item.id).toList(), ['roof-project', 'demo']);
  });

  test(
    'getProject auto-migrates legacy dataset version and persists it',
    () async {
      final legacyProject = buildTestProject(datasetVersion: 'seed-2025-12-01');

      await database
          .into(database.projectEntries)
          .insert(
            ProjectEntriesCompanion.insert(
              id: legacyProject.id,
              name: legacyProject.name,
              climatePointId: legacyProject.climatePointId,
              roomPreset: legacyProject.roomPreset.storageKey,
              payloadJson: jsonEncode(legacyProject.toJson()),
              projectFormatVersion: currentProjectFormatVersion,
              datasetVersion: Value(legacyProject.datasetVersion!),
              updatedAtEpochMs: 123,
            ),
          );

      final migrated = await repository.getProject(legacyProject.id);
      final storedRow = await (database.select(
        database.projectEntries,
      )..where((table) => table.id.equals(legacyProject.id))).getSingle();

      expect(migrated?.datasetVersion, currentDatasetVersion);
      expect(migrated?.migratedFromDatasetVersion, 'seed-2025-12-01');
      expect(migrated?.houseModel.elements, hasLength(4));
      expect(
        migrated?.houseModel.elements.every(
          (element) => element.lineSegment != null,
        ),
        isTrue,
      );
      expect(migrated?.houseModel.rooms.single.layout.widthMeters, 4);
      expect(storedRow.datasetVersion, currentDatasetVersion);
      expect(storedRow.migratedFromDatasetVersion, 'seed-2025-12-01');
      expect(storedRow.updatedAtEpochMs, 123);
    },
  );

  test(
    'listProjects auto-migrates legacy payload without dataset version and house model',
    () async {
      final legacyProject = buildTestProject();
      final legacyPayload = Map<String, dynamic>.from(legacyProject.toJson())
        ..['projectFormatVersion'] = 1
        ..remove('houseModel')
        ..remove('datasetVersion')
        ..remove('migratedFromDatasetVersion');

      await database
          .into(database.projectEntries)
          .insert(
            ProjectEntriesCompanion.insert(
              id: legacyProject.id,
              name: legacyProject.name,
              climatePointId: legacyProject.climatePointId,
              roomPreset: legacyProject.roomPreset.storageKey,
              payloadJson: jsonEncode(legacyPayload),
              projectFormatVersion: 1,
              datasetVersion: const Value(legacyUnversionedDatasetVersion),
              updatedAtEpochMs: 456,
            ),
          );

      final projects = await repository.listProjects();

      expect(projects.single.datasetVersion, currentDatasetVersion);
      expect(
        projects.single.migratedFromDatasetVersion,
        legacyUnversionedDatasetVersion,
      );
      expect(projects.single.houseModel.elements, hasLength(4));
      expect(
        projects.single.houseModel.elements.every(
          (element) => element.lineSegment != null,
        ),
        isTrue,
      );
      expect(
        projects.single.sourceProjectFormatVersion,
        currentProjectFormatVersion,
      );
      expect(projects.single.houseModel.rooms.single.layout.widthMeters, 4);
    },
  );

  test(
    'getProject migrates legacy opening leakage preset and persists it',
    () async {
      final source = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Дом',
          rooms: [Room.defaultRoom()],
          elements: const [
            HouseEnvelopeElement(
              id: 'wall-main',
              roomId: defaultRoomId,
              title: 'Стена',
              elementKind: ConstructionElementKind.wall,
              areaSquareMeters: 10,
              constructionId: 'wall',
            ),
          ],
          openings: const [
            EnvelopeOpening(
              id: 'opening-window',
              elementId: 'wall-main',
              title: 'Окно',
              kind: OpeningKind.window,
              areaSquareMeters: 2,
              heatTransferCoefficient: 1.0,
            ),
          ],
        ),
      );
      final legacyPayload = Map<String, dynamic>.from(source.toJson())
        ..['projectFormatVersion'] = 14;
      final openings =
          ((legacyPayload['houseModel'] as Map<String, dynamic>)['openings']
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      openings[0].remove('leakagePreset');

      await database
          .into(database.projectEntries)
          .insert(
            ProjectEntriesCompanion.insert(
              id: source.id,
              name: source.name,
              climatePointId: source.climatePointId,
              roomPreset: source.roomPreset.storageKey,
              payloadJson: jsonEncode(legacyPayload),
              projectFormatVersion: 14,
              datasetVersion: Value(source.datasetVersion!),
              updatedAtEpochMs: 999,
            ),
          );

      final restored = await repository.getProject(source.id);
      final storedRow = await (database.select(
        database.projectEntries,
      )..where((table) => table.id.equals(source.id))).getSingle();
      final storedProject = Project.fromJson(jsonDecode(storedRow.payloadJson));

      expect(
        restored?.houseModel.openings.single.leakagePreset,
        OpeningLeakagePreset.standard,
      );
      expect(
        storedProject.houseModel.openings.single.leakagePreset,
        OpeningLeakagePreset.standard,
      );
      expect(restored?.sourceProjectFormatVersion, currentProjectFormatVersion);
    },
  );

  test('database migration from schema v1 preserves legacy rows', () async {
    final tempDir = await Directory.systemTemp.createTemp('therma_db_test');
    addTearDown(() async {
      await tempDir.delete(recursive: true);
    });

    final dbFile = File('${tempDir.path}/app.sqlite');
    final legacyProject = buildTestProject();
    final legacyPayload = Map<String, dynamic>.from(legacyProject.toJson())
      ..['projectFormatVersion'] = 1
      ..remove('houseModel')
      ..remove('datasetVersion')
      ..remove('migratedFromDatasetVersion');

    final legacyDatabase = NativeDatabase(dbFile);
    await legacyDatabase.ensureOpen(const _NoopExecutorUser());
    await legacyDatabase.runCustom(
      'CREATE TABLE project_entries ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'name TEXT NOT NULL, '
      'climate_point_id TEXT NOT NULL, '
      'room_preset TEXT NOT NULL, '
      'payload_json TEXT NOT NULL, '
      'project_format_version INTEGER NOT NULL, '
      'updated_at_epoch_ms INTEGER NOT NULL'
      ')',
      const [],
    );
    await legacyDatabase.runCustom(
      'INSERT INTO project_entries '
      '(id, name, climate_point_id, room_preset, payload_json, '
      'project_format_version, updated_at_epoch_ms) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        legacyProject.id,
        legacyProject.name,
        legacyProject.climatePointId,
        legacyProject.roomPreset.storageKey,
        jsonEncode(legacyPayload),
        1,
        789,
      ],
    );
    await legacyDatabase.close();

    final migratedDatabase = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(() async {
      await migratedDatabase.close();
    });
    final migratedRepository = DriftProjectRepository(migratedDatabase);

    final projects = await migratedRepository.listProjects();
    final storedRow = await migratedDatabase
        .select(migratedDatabase.projectEntries)
        .getSingle();

    expect(projects.single.datasetVersion, currentDatasetVersion);
    expect(
      projects.single.migratedFromDatasetVersion,
      legacyUnversionedDatasetVersion,
    );
    expect(projects.single.houseModel.elements, hasLength(4));
    expect(storedRow.datasetVersion, currentDatasetVersion);
    expect(
      storedRow.migratedFromDatasetVersion,
      legacyUnversionedDatasetVersion,
    );
  });

  test('favorite materials are stored globally', () async {
    await repository.saveFavoriteMaterialIds({'custom-material-1', 'aac_d500'});

    final restored = await repository.listFavoriteMaterialIds();

    expect(restored, containsAll(['custom-material-1', 'aac_d500']));
  });
}

class _NoopExecutorUser implements QueryExecutorUser {
  const _NoopExecutorUser();

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
