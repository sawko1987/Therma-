import '../models/project.dart';
import 'demo_project_seed.dart';
import 'interfaces.dart';
import 'project_migration_service.dart';

class InMemoryProjectRepository
    implements
        ProjectRepository,
        ConstructionLibraryRepository,
        ObjectRepository,
        FavoriteMaterialsRepository {
  InMemoryProjectRepository({required List<Project> projects})
    : _projects = [...projects],
      _library = {
        for (final project in projects)
          for (final construction in project.constructions)
            construction.id: construction,
      },
      _objects = {
        for (final project in projects)
          'object-${project.id}': DesignObject(
            id: 'object-${project.id}',
            title: project.name,
            address: '',
            description: '',
            customerPhone: '',
            climatePointId: project.climatePointId,
            projectId: project.id,
            updatedAtEpochMs: 0,
          ),
      };

  factory InMemoryProjectRepository.demo() {
    return InMemoryProjectRepository(projects: demoProjects);
  }

  final List<Project> _projects;
  final Map<String, Construction> _library;
  final Map<String, DesignObject> _objects;
  final Set<String> _favoriteMaterialIds = <String>{};
  final ProjectMigrationService _migrationService =
      const ProjectMigrationService();

  @override
  Future<List<Project>> listProjects() async {
    for (var index = 0; index < _projects.length; index++) {
      final migrated = _migrationService.migrate(_projects[index]);
      if (migrated.wasMigrated) {
        _projects[index] = migrated.project;
      }
    }
    return List.unmodifiable(_projects);
  }

  @override
  Future<Project?> getProject(String id) async {
    for (var index = 0; index < _projects.length; index++) {
      final project = _projects[index];
      if (project.id == id) {
        final migrated = _migrationService.migrate(project);
        if (migrated.wasMigrated) {
          _projects[index] = migrated.project;
        }
        return migrated.project;
      }
    }
    return null;
  }

  @override
  Future<void> saveProject(Project project) async {
    final index = _projects.indexWhere((item) => item.id == project.id);
    for (final construction in project.constructions) {
      _library[construction.id] = construction;
    }
    if (index == -1) {
      _projects.add(project);
      return;
    }
    _projects[index] = project;
  }

  @override
  Future<void> deleteProject(String id) async {
    _projects.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> seedDemoProjectIfEmpty() async {
    if (_projects.isNotEmpty) {
      return;
    }
    _projects.addAll(demoProjects);
    for (final project in demoProjects) {
      for (final construction in project.constructions) {
        _library[construction.id] = construction;
      }
    }
  }

  @override
  Future<List<Construction>> listConstructions() async {
    return List.unmodifiable(_library.values);
  }

  @override
  Future<Construction?> getConstruction(String id) async => _library[id];

  @override
  Future<void> saveConstruction(Construction construction) async {
    _library[construction.id] = construction;
  }

  @override
  Future<void> deleteConstruction(String id) async {
    _library.remove(id);
  }

  @override
  Future<List<DesignObject>> listObjects() async {
    return List.unmodifiable(_objects.values);
  }

  @override
  Future<DesignObject?> getObject(String id) async => _objects[id];

  @override
  Future<void> saveObject(DesignObject object) async {
    _objects[object.id] = object;
  }

  @override
  Future<void> deleteObject(String id) async {
    _objects.remove(id);
  }

  @override
  Future<void> seedObjectsIfEmpty() async {
    if (_objects.isNotEmpty) {
      return;
    }
    for (final project in _projects) {
      _objects['object-${project.id}'] = DesignObject(
        id: 'object-${project.id}',
        title: project.name,
        address: '',
        description: '',
        customerPhone: '',
        climatePointId: project.climatePointId,
        projectId: project.id,
        updatedAtEpochMs: 0,
      );
    }
  }

  @override
  Future<Set<String>> listFavoriteMaterialIds() async {
    return Set<String>.from(_favoriteMaterialIds);
  }

  @override
  Future<void> saveFavoriteMaterialIds(Set<String> ids) async {
    _favoriteMaterialIds
      ..clear()
      ..addAll(ids);
  }
}
