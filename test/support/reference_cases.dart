import 'package:smartcalc_mobile/src/core/models/calculation.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';

class ReferenceCase {
  const ReferenceCase({
    required this.name,
    required this.project,
    required this.expectedTotalResistance,
    required this.expectedRequiredResistance,
    required this.expectedThermalPass,
    required this.expectedTotalVaporResistance,
    required this.expectedOutwardDryingRatio,
    required this.expectedMoistureLevel,
  });

  final String name;
  final Project project;
  final double expectedTotalResistance;
  final double expectedRequiredResistance;
  final bool expectedThermalPass;
  final double expectedTotalVaporResistance;
  final double expectedOutwardDryingRatio;
  final ScreeningLevel expectedMoistureLevel;
}

final referenceCases = [
  ReferenceCase(
    name: 'moscow_safe_wall',
    project: _buildProject(
      id: 'ref-safe-wall',
      name: 'Эталонная стена / Москва',
      climatePointId: 'moscow',
      roomPreset: RoomPreset.livingRoom,
      construction: Construction(
        id: 'safe-wall',
        title: 'Стена с паропроницаемым наружным слоем',
        elementKind: ConstructionElementKind.wall,
        layers: const [
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
            id: 'wool_outer',
            materialId: 'mineral_wool',
            kind: LayerKind.frame,
            thicknessMm: 50,
          ),
        ],
      ),
    ),
    expectedTotalResistance: 4.155714286,
    expectedRequiredResistance: 3.23508,
    expectedThermalPass: true,
    expectedTotalVaporResistance: 1.978919012,
    expectedOutwardDryingRatio: 0.916666667,
    expectedMoistureLevel: ScreeningLevel.low,
  ),
  ReferenceCase(
    name: 'moscow_brick_faced_wall',
    project: _buildProject(
      id: 'ref-brick-wall',
      name: 'Эталонная стена с облицовкой / Москва',
      climatePointId: 'moscow',
      roomPreset: RoomPreset.livingRoom,
      construction: Construction(
        id: 'brick-faced-wall',
        title: 'Стена с облицовочным кирпичом',
        elementKind: ConstructionElementKind.wall,
        layers: const [
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
    ),
    expectedTotalResistance: 5.553862434,
    expectedRequiredResistance: 3.23508,
    expectedThermalPass: true,
    expectedTotalVaporResistance: 3.236494769,
    expectedOutwardDryingRatio: 6.0,
    expectedMoistureLevel: ScreeningLevel.high,
  ),
  ReferenceCase(
    name: 'novosibirsk_attic_roof',
    project: _buildProject(
      id: 'ref-attic-roof',
      name: 'Эталонная кровля / Новосибирск',
      climatePointId: 'novosibirsk',
      roomPreset: RoomPreset.attic,
      construction: Construction(
        id: 'attic-roof',
        title: 'Утеплённая кровля',
        elementKind: ConstructionElementKind.roof,
        layers: const [
          ConstructionLayer(
            id: 'timber_inner',
            materialId: 'pine_timber',
            kind: LayerKind.frame,
            thicknessMm: 40,
          ),
          ConstructionLayer(
            id: 'wool_main',
            materialId: 'mineral_wool',
            kind: LayerKind.frame,
            thicknessMm: 250,
          ),
          ConstructionLayer(
            id: 'wool_outer',
            materialId: 'mineral_wool',
            kind: LayerKind.crossFrame,
            thicknessMm: 40,
          ),
        ],
      ),
    ),
    expectedTotalResistance: 7.656666667,
    expectedRequiredResistance: 5.2969,
    expectedThermalPass: true,
    expectedTotalVaporResistance: 1.633333333,
    expectedOutwardDryingRatio: 0.2,
    expectedMoistureLevel: ScreeningLevel.low,
  ),
];

Project _buildProject({
  required String id,
  required String name,
  required String climatePointId,
  required RoomPreset roomPreset,
  required Construction construction,
}) {
  return Project(
    id: id,
    name: name,
    climatePointId: climatePointId,
    roomPreset: roomPreset,
    constructions: [construction],
    houseModel: HouseModel.bootstrapFromConstructions([construction]),
  );
}
