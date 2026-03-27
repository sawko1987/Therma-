import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
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
    final source = buildTestProject(
      climatePointId: 'novosibirsk',
      roomPreset: RoomPreset.attic,
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
      restored.constructions.single.layers,
      hasLength(source.constructions.single.layers.length),
    );
    expect(
      restored.constructions.single.layers.last.kind,
      source.constructions.single.layers.last.kind,
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
      );

      await repository.saveProject(original);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.saveProject(updated);

      final projects = await repository.listProjects();
      final stored = await repository.getProject(original.id);

      expect(projects, hasLength(1));
      expect(stored?.name, 'Updated demo project');
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
    );

    await repository.saveProject(first);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repository.saveProject(renamedSecond);

    final projects = await repository.listProjects();

    expect(projects.map((item) => item.id).toList(), ['roof-project', 'demo']);
  });
}
