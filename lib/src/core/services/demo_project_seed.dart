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
    title: 'Конструктор дома',
    rooms: [
      Room(
        id: defaultRoomId,
        title: 'Гостиная',
        kind: RoomKind.livingRoom,
        heightMeters: 2.8,
        layout: RoomLayoutRect(
          xMeters: 0,
          yMeters: 0,
          widthMeters: 5,
          heightMeters: 7.6,
        ),
      ),
    ],
    elements: [
      HouseEnvelopeElement(
        id: 'house-element-outer-wall',
        roomId: defaultRoomId,
        title: 'Наружная стена',
        elementKind: ConstructionElementKind.wall,
        areaSquareMeters: 14,
        constructionId: 'outer-wall',
        wallPlacement: EnvelopeWallPlacement(
          side: RoomSide.top,
          offsetMeters: 0,
          lengthMeters: 5,
        ),
      ),
    ],
    openings: [
      EnvelopeOpening(
        id: 'opening-living-window',
        elementId: 'house-element-outer-wall',
        title: 'Окно гостиной',
        kind: OpeningKind.window,
        areaSquareMeters: 8,
        heatTransferCoefficient: 1.0,
      ),
      EnvelopeOpening(
        id: 'opening-main-door',
        elementId: 'house-element-outer-wall',
        title: 'Входная дверь',
        kind: OpeningKind.door,
        areaSquareMeters: 2.2,
        heatTransferCoefficient: 1.4,
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
