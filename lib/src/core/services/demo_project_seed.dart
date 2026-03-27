import '../models/project.dart';
import '../models/versioning.dart';

const Project demoProject = Project(
  id: 'demo-project',
  name: 'Дом 140 м² / стена',
  climatePointId: 'moscow',
  roomPreset: RoomPreset.livingRoom,
  datasetVersion: currentDatasetVersion,
  houseModel: HouseModel(
    id: 'house-model',
    title: 'Базовая схема дома',
    elements: [
      HouseElement(
        id: 'house-element-outer-wall',
        title: 'Наружная стена',
        elementKind: ConstructionElementKind.wall,
        areaSquareMeters: 140,
        constructionId: 'outer-wall',
      ),
    ],
  ),
  constructions: [
    Construction(
      id: 'outer-wall',
      title: 'Наружная стена',
      elementKind: ConstructionElementKind.wall,
      layers: [
        ConstructionLayer(
          id: 'plaster',
          materialId: 'gypsum_plaster',
          kind: LayerKind.solid,
          thicknessMm: 20,
        ),
        ConstructionLayer(
          id: 'aac',
          materialId: 'aac_d500',
          kind: LayerKind.masonry,
          thicknessMm: 375,
        ),
        ConstructionLayer(
          id: 'wool',
          materialId: 'mineral_wool',
          kind: LayerKind.frame,
          thicknessMm: 100,
        ),
        ConstructionLayer(
          id: 'brick',
          materialId: 'facing_brick',
          kind: LayerKind.masonry,
          thicknessMm: 120,
        ),
      ],
    ),
  ],
);

const List<Project> demoProjects = [demoProject];
