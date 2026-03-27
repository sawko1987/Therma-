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
          name: 'Дом 140 м² / стена',
          climatePointId: 'moscow',
          roomPreset: RoomPreset.livingRoom,
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
        ),
      ],
    );
  }

  final List<Project> _projects;

  @override
  Future<List<Project>> listProjects() async => _projects;
}
