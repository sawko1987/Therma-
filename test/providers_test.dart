import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/core/models/ground_floor_calculation.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/features/construction_library/presentation/material_catalog_support.dart';

import 'support/fakes.dart';

void main() {
  test('selectedProjectProvider follows selectedObjectProvider', () async {
    final roofConstruction = Construction(
      id: 'roof',
      title: 'Кровля',
      elementKind: ConstructionElementKind.roof,
      layers: buildWallConstruction().layers,
    );
    final secondProject = Project(
      id: 'roof-project',
      name: 'Новосибирск / кровля',
      climatePointId: 'novosibirsk',
      roomPreset: RoomPreset.attic,
      houseModel: HouseModel.bootstrapFromConstructions([roofConstruction]),
      constructions: [roofConstruction],
    );

    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository(projects: [buildTestProject(), secondProject]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final initialProject = await container.read(selectedProjectProvider.future);
    expect(initialProject?.id, 'demo');

    container
        .read(selectedObjectIdProvider.notifier)
        .select('object-roof-project');

    final selectedProject = await container.read(
      selectedProjectProvider.future,
    );
    expect(selectedProject?.id, 'roof-project');
    expect(selectedProject?.name, 'Новосибирск / кровля');
  });

  test('selectedGroundFloorCalculationProvider respects selected id', () async {
    final floor = Construction(
      id: 'floor',
      title: 'Пол',
      elementKind: ConstructionElementKind.floor,
      floorConstructionType: FloorConstructionType.onGround,
      layers: buildWallConstruction().layers,
    );
    final project = buildTestProject(
      constructions: [floor],
      groundFloorCalculations: const [
        GroundFloorCalculation(
          id: 'a',
          title: 'A',
          kind: GroundFloorCalculationKind.slabOnGround,
          constructionId: 'floor',
          areaSquareMeters: 25,
          perimeterMeters: 20,
          slabWidthMeters: 5,
          slabLengthMeters: 5,
          edgeInsulationWidthMeters: 0.6,
          edgeInsulationResistance: 1.5,
        ),
        GroundFloorCalculation(
          id: 'b',
          title: 'B',
          kind: GroundFloorCalculationKind.slabOnGround,
          constructionId: 'floor',
          areaSquareMeters: 36,
          perimeterMeters: 24,
          slabWidthMeters: 6,
          slabLengthMeters: 6,
          edgeInsulationWidthMeters: 0.8,
          edgeInsulationResistance: 2.1,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository(projects: [project]),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(selectedGroundFloorCalculationIdProvider.notifier)
        .select('b');
    final selected = await container.read(
      selectedGroundFloorCalculationProvider.future,
    );
    expect(selected?.id, 'b');
  });

  test('catalogSnapshotProvider merges project custom materials', () async {
    final project = buildTestProject().copyWith(
      customMaterials: const [
        MaterialEntry(
          id: 'custom-material-1',
          name: 'Мой утеплитель',
          category: 'Пользовательские',
          thermalConductivity: 0.031,
          vaporPermeability: 0.12,
          aliases: ['мой'],
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository(projects: [project]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final catalog = await container.read(catalogSnapshotProvider.future);

    expect(
      catalog.materials.any((item) => item.id == 'custom-material-1'),
      isTrue,
    );
    expect(catalog.constructionTemplates, isNotEmpty);
  });

  test('materialCatalogEntriesProvider marks edited seeded material', () async {
    final project = buildTestProject().copyWith(
      customMaterials: const [
        MaterialEntry(
          id: 'aac_d500',
          name: 'Газобетон D500 (переопределен)',
          category: 'Блоки',
          thermalConductivity: 0.13,
          vaporPermeability: 0.22,
          applications: [MaterialApplication.wall, MaterialApplication.floor],
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository(projects: [project]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final entries = await container.read(materialCatalogEntriesProvider.future);
    final material = entries.firstWhere((item) => item.material.id == 'aac_d500');

    expect(material.isCustom, isTrue);
    expect(material.isSeedOverride, isTrue);
    expect(material.seedMaterial, isNotNull);
  });

  test('filterMaterialCatalogEntries filters by application', () {
    final entries = [
      MaterialCatalogEntry(
        material: const MaterialEntry(
          id: 'floor-material',
          name: 'Материал пола',
          category: 'Тест',
          thermalConductivity: 0.1,
          vaporPermeability: 0.1,
          applications: [MaterialApplication.floor],
        ),
        source: MaterialCatalogSource.seed,
        isFavorite: false,
      ),
      MaterialCatalogEntry(
        material: const MaterialEntry(
          id: 'wall-material',
          name: 'Материал стены',
          category: 'Тест',
          thermalConductivity: 0.1,
          vaporPermeability: 0.1,
          applications: [MaterialApplication.wall],
        ),
        source: MaterialCatalogSource.seed,
        isFavorite: false,
      ),
    ];

    final filtered = filterMaterialCatalogEntries(
      entries,
      const MaterialFilterState(application: MaterialApplication.floor),
    );

    expect(filtered, hasLength(1));
    expect(filtered.single.material.id, 'floor-material');
  });

  test('constructionLibraryProvider includes seeded templates', () async {
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
      ],
    );
    addTearDown(container.dispose);

    final library = await container.read(constructionLibraryProvider.future);

    expect(library.any((item) => item.id == 'template-wall'), isTrue);
    expect(library.any((item) => item.id == 'wall'), isTrue);
  });

  test('deleting last object keeps selected project empty', () async {
    final repository = FakeProjectRepository(projects: [buildTestProject()]);
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(repository),
        constructionLibraryRepositoryProvider.overrideWithValue(repository),
        objectRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final object = await container.read(selectedObjectProvider.future);
    expect(object, isNotNull);

    await container.read(projectEditorProvider).deleteObject(object!.id);

    final selectedObject = await container.read(selectedObjectProvider.future);
    final selectedProject = await container.read(selectedProjectProvider.future);

    expect(selectedObject, isNull);
    expect(selectedProject, isNull);
  });

  test(
    'library construction deletion succeeds after deleting last object and project',
    () async {
      final repository = FakeProjectRepository(projects: [buildTestProject()]);
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          constructionLibraryRepositoryProvider.overrideWithValue(repository),
          objectRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final object = await container.read(selectedObjectProvider.future);
      await container.read(projectEditorProvider).deleteObject(object!.id);

      await expectLater(
        container
            .read(projectEditorProvider)
            .deleteConstructionFromLibrary('wall'),
        completes,
      );
    },
  );

  test(
    'library construction deletion ignores hidden orphan project without object',
    () async {
      final repository = FakeProjectRepository(projects: [buildTestProject()]);
      await repository.deleteObject('object-demo');
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          constructionLibraryRepositoryProvider.overrideWithValue(repository),
          objectRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(projectEditorProvider)
            .deleteConstructionFromLibrary('wall'),
        completes,
      );
    },
  );

  test(
    'library construction deletion succeeds when construction is only selected in project',
    () async {
      final wall = buildWallConstruction();
      final project = buildTestProject(
        construction: wall,
        houseModel: buildHouseModel(constructions: [wall]).copyWith(
          elements: const [],
        ),
      ).copyWith(
        selectedConstructionIds: const ['wall'],
      );
      final repository = FakeProjectRepository(projects: [project]);
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          constructionLibraryRepositoryProvider.overrideWithValue(repository),
          objectRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(projectEditorProvider)
            .deleteConstructionFromLibrary('wall'),
        completes,
      );
    },
  );

  test(
    'library construction deletion rejects when construction is used by envelope element',
    () async {
      final repository = FakeProjectRepository(projects: [buildTestProject()]);
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          constructionLibraryRepositoryProvider.overrideWithValue(repository),
          objectRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(projectEditorProvider)
            .deleteConstructionFromLibrary('wall'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Нельзя удалить конструкцию из библиотеки, пока она используется в ограждающих конструкциях проекта "Demo project".',
          ),
        ),
      );
    },
  );

  test(
    'library construction deletion rejects when construction is used by ground floor calculation',
    () async {
      final floor = Construction(
        id: 'floor',
        title: 'Пол',
        elementKind: ConstructionElementKind.floor,
        floorConstructionType: FloorConstructionType.onGround,
        layers: buildWallConstruction().layers,
      );
      final project = buildTestProject(
        constructions: [floor],
        houseModel: buildHouseModel(constructions: [floor]).copyWith(
          elements: const [],
        ),
        groundFloorCalculations: const [
          GroundFloorCalculation(
            id: 'floor-calc',
            title: 'Пол',
            kind: GroundFloorCalculationKind.slabOnGround,
            constructionId: 'floor',
            areaSquareMeters: 25,
            perimeterMeters: 20,
            slabWidthMeters: 5,
            slabLengthMeters: 5,
            edgeInsulationWidthMeters: 0.6,
            edgeInsulationResistance: 1.5,
          ),
        ],
      );
      final repository = FakeProjectRepository(projects: [project]);
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          constructionLibraryRepositoryProvider.overrideWithValue(repository),
          objectRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(projectEditorProvider)
            .deleteConstructionFromLibrary('floor'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Нельзя удалить конструкцию из библиотеки, пока она используется в расчете пола по грунту "Пол" проекта "Demo project".',
          ),
        ),
      );
    },
  );
}
