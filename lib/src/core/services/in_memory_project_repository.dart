import '../models/project.dart';
import 'interfaces.dart';

class InMemoryProjectRepository implements ProjectRepository {
  InMemoryProjectRepository({required List<Project> projects})
      : _projects = projects;

  factory InMemoryProjectRepository.demo() {
    return InMemoryProjectRepository(
      projects: const [
        Project(
          id: 'demo-project',
          name: 'Дом 140 м²',
          climatePointId: 'moscow',
          constructions: [
            Construction(
              id: 'outer-wall',
              title: 'Наружная стена 495 мм',
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
              ],
            ),
            Construction(
              id: 'roof-insulated',
              title: 'Утепленная кровля 250 мм',
              elementKind: ConstructionElementKind.roof,
              layers: [
                ConstructionLayer(
                  id: 'roof-wool',
                  materialId: 'mineral_wool',
                  kind: LayerKind.frame,
                  thicknessMm: 250,
                ),
              ],
            ),
            Construction(
              id: 'floor-ground',
              title: 'Пол по грунту 200 мм',
              elementKind: ConstructionElementKind.floor,
              layers: [
                ConstructionLayer(
                  id: 'floor-concrete',
                  materialId: 'aac_d500',
                  kind: LayerKind.solid,
                  thicknessMm: 200,
                ),
              ],
            ),
            Construction(
              id: 'window-double',
              title: 'Окно двухкамерное',
              elementKind: ConstructionElementKind.window,
              layers: [
                ConstructionLayer(
                  id: 'window-core',
                  materialId: 'mineral_wool',
                  kind: LayerKind.solid,
                  thicknessMm: 40,
                ),
              ],
            ),
            Construction(
              id: 'door-insulated',
              title: 'Утепленная дверь',
              elementKind: ConstructionElementKind.door,
              layers: [
                ConstructionLayer(
                  id: 'door-core',
                  materialId: 'facing_brick',
                  kind: LayerKind.solid,
                  thicknessMm: 70,
                ),
              ],
            ),
            Construction(
              id: 'inner-wall',
              title: 'Внутренняя перегородка',
              elementKind: ConstructionElementKind.wall,
              layers: [
                ConstructionLayer(
                  id: 'inner-aac',
                  materialId: 'aac_d500',
                  kind: LayerKind.masonry,
                  thicknessMm: 150,
                ),
              ],
            ),
          ],
          rooms: [
            Room(
              id: 'living',
              name: 'Гостиная',
              roomType: RoomType.livingRoom,
              floorAreaM2: 28,
              heightM: 2.8,
              boundaries: [
                RoomBoundary(
                  id: 'living-north',
                  title: 'Северная стена',
                  surfaceType: SurfaceType.wall,
                  boundaryCondition: BoundaryCondition.outdoor,
                  grossAreaM2: 18.5,
                  constructionId: 'outer-wall',
                  openings: [
                    Opening(
                      id: 'living-window-north',
                      title: 'Окно гостиной',
                      kind: OpeningKind.window,
                      areaM2: 3.6,
                      constructionId: 'window-double',
                    ),
                  ],
                ),
                RoomBoundary(
                  id: 'living-west',
                  title: 'Западная стена',
                  surfaceType: SurfaceType.wall,
                  boundaryCondition: BoundaryCondition.outdoor,
                  grossAreaM2: 12.0,
                  constructionId: 'outer-wall',
                ),
                RoomBoundary(
                  id: 'living-roof',
                  title: 'Покрытие',
                  surfaceType: SurfaceType.roof,
                  boundaryCondition: BoundaryCondition.outdoor,
                  grossAreaM2: 28.0,
                  constructionId: 'roof-insulated',
                ),
                RoomBoundary(
                  id: 'living-floor',
                  title: 'Пол по грунту',
                  surfaceType: SurfaceType.floor,
                  boundaryCondition: BoundaryCondition.ground,
                  grossAreaM2: 28.0,
                  constructionId: 'floor-ground',
                  adjacentTemperatureC: 6,
                ),
                RoomBoundary(
                  id: 'living-hall',
                  title: 'Перегородка в коридор',
                  surfaceType: SurfaceType.wall,
                  boundaryCondition: BoundaryCondition.heatedAdjacent,
                  grossAreaM2: 10.5,
                  constructionId: 'inner-wall',
                  adjacentRoomId: 'hall',
                ),
              ],
            ),
            Room(
              id: 'hall',
              name: 'Коридор',
              roomType: RoomType.hallway,
              floorAreaM2: 12,
              heightM: 2.8,
              boundaries: [
                RoomBoundary(
                  id: 'hall-east',
                  title: 'Входная зона',
                  surfaceType: SurfaceType.wall,
                  boundaryCondition: BoundaryCondition.outdoor,
                  grossAreaM2: 10.0,
                  constructionId: 'outer-wall',
                  openings: [
                    Opening(
                      id: 'hall-door',
                      title: 'Входная дверь',
                      kind: OpeningKind.door,
                      areaM2: 2.1,
                      constructionId: 'door-insulated',
                    ),
                  ],
                ),
                RoomBoundary(
                  id: 'hall-roof',
                  title: 'Покрытие',
                  surfaceType: SurfaceType.roof,
                  boundaryCondition: BoundaryCondition.outdoor,
                  grossAreaM2: 12.0,
                  constructionId: 'roof-insulated',
                ),
                RoomBoundary(
                  id: 'hall-floor',
                  title: 'Пол по грунту',
                  surfaceType: SurfaceType.floor,
                  boundaryCondition: BoundaryCondition.ground,
                  grossAreaM2: 12.0,
                  constructionId: 'floor-ground',
                  adjacentTemperatureC: 6,
                ),
                RoomBoundary(
                  id: 'hall-living',
                  title: 'Перегородка в гостиную',
                  surfaceType: SurfaceType.wall,
                  boundaryCondition: BoundaryCondition.heatedAdjacent,
                  grossAreaM2: 10.5,
                  constructionId: 'inner-wall',
                  adjacentRoomId: 'living',
                ),
                RoomBoundary(
                  id: 'hall-basement',
                  title: 'Стена к холодному тамбуру',
                  surfaceType: SurfaceType.wall,
                  boundaryCondition: BoundaryCondition.unheatedSpace,
                  grossAreaM2: 6.5,
                  constructionId: 'outer-wall',
                  adjacentTemperatureC: 8,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  final List<Project> _projects;

  @override
  Future<List<Project>> listProjects() async => _projects;
}
