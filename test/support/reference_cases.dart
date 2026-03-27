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

const referenceCases = [
  ReferenceCase(
    name: 'moscow_safe_wall',
    project: Project(
      id: 'ref-safe-wall',
      name: 'Эталонная стена / Москва',
      climatePointId: 'moscow',
      roomPreset: RoomPreset.livingRoom,
      constructions: [
        Construction(
          id: 'safe-wall',
          title: 'Стена с паропроницаемым наружным слоем',
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
              id: 'wool_outer',
              materialId: 'mineral_wool',
              kind: LayerKind.frame,
              thicknessMm: 50,
            ),
          ],
        ),
      ],
    ),
    expectedTotalResistance: 4.155714286,
    expectedRequiredResistance: 3.18419,
    expectedThermalPass: true,
    expectedTotalVaporResistance: 1.978919012,
    expectedOutwardDryingRatio: 0.916666667,
    expectedMoistureLevel: ScreeningLevel.low,
  ),
  ReferenceCase(
    name: 'moscow_brick_faced_wall',
    project: Project(
      id: 'ref-brick-wall',
      name: 'Эталонная стена с облицовкой / Москва',
      climatePointId: 'moscow',
      roomPreset: RoomPreset.livingRoom,
      constructions: [
        Construction(
          id: 'brick-faced-wall',
          title: 'Стена с облицовочным кирпичом',
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
    ),
    expectedTotalResistance: 5.553862434,
    expectedRequiredResistance: 3.18419,
    expectedThermalPass: true,
    expectedTotalVaporResistance: 3.236494769,
    expectedOutwardDryingRatio: 6.0,
    expectedMoistureLevel: ScreeningLevel.high,
  ),
  ReferenceCase(
    name: 'novosibirsk_attic_roof',
    project: Project(
      id: 'ref-attic-roof',
      name: 'Эталонная кровля / Новосибирск',
      climatePointId: 'novosibirsk',
      roomPreset: RoomPreset.attic,
      constructions: [
        Construction(
          id: 'attic-roof',
          title: 'Утеплённая кровля',
          elementKind: ConstructionElementKind.roof,
          layers: [
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
      ],
    ),
    expectedTotalResistance: 7.656666667,
    expectedRequiredResistance: 5.3025,
    expectedThermalPass: true,
    expectedTotalVaporResistance: 1.633333333,
    expectedOutwardDryingRatio: 0.2,
    expectedMoistureLevel: ScreeningLevel.low,
  ),
];
