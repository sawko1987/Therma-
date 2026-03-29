import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/core/models/ground_floor_calculation.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';

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
}
