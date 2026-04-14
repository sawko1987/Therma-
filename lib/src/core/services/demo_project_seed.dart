import '../models/ground_floor_calculation.dart';
import '../models/project.dart';
import '../models/versioning.dart';

const Project demoProject = Project(
  id: 'demo-project',
  name: 'Дом 140 м² / стена',
  climatePointId: 'moscow',
  roomPreset: RoomPreset.livingRoom,
  datasetVersion: currentDatasetVersion,
  constructions: [
    Construction(
      id: 'floor-on-ground',
      title: 'Пол по грунту',
      elementKind: ConstructionElementKind.floor,
      floorConstructionType: FloorConstructionType.onGround,
      layers: [
        ConstructionLayer(
          id: 'screed',
          materialId: 'gypsum_plaster',
          kind: LayerKind.solid,
          thicknessMm: 50,
        ),
        ConstructionLayer(
          id: 'floor-wool',
          materialId: 'mineral_wool',
          kind: LayerKind.frame,
          thicknessMm: 150,
        ),
        ConstructionLayer(
          id: 'floor-aac',
          materialId: 'aac_d500',
          kind: LayerKind.solid,
          thicknessMm: 120,
        ),
      ],
    ),
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
  houseModel: HouseModel(
    id: 'house-model',
    title: 'Конструктор дома',
    rooms: [
      Room(
        id: defaultRoomId,
        title: 'Гостиная',
        kind: RoomKind.livingRoom,
        heightMeters: 2.8,
        comfortTemperatureC: 22,
        ventilationSupplyM3h: 50,
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
        construction: Construction(
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
        sourceConstructionId: 'outer-wall',
        sourceConstructionTitle: 'Наружная стена',
        wallOrientation: WallOrientation.north,
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
  groundFloorCalculations: [
    GroundFloorCalculation(
      id: 'ground-floor-main',
      title: 'Пол по грунту / гостиная',
      kind: GroundFloorCalculationKind.slabOnGround,
      constructionId: 'floor-on-ground',
      areaSquareMeters: 38,
      perimeterMeters: 25.2,
      slabWidthMeters: 5,
      slabLengthMeters: 7.6,
      edgeInsulationWidthMeters: 0.8,
      edgeInsulationResistance: 2.1,
      notes: 'Демо-кейс для ground floor v1.',
    ),
  ],
);

const List<Project> demoProjects = [demoProject];
