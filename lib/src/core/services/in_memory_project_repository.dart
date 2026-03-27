import '../models/project.dart';
import 'demo_project_seed.dart';
import 'interfaces.dart';
import 'project_migration_service.dart';

class InMemoryProjectRepository implements ProjectRepository {
  InMemoryProjectRepository({required List<Project> projects})
    : _projects = [...projects];

  factory InMemoryProjectRepository.demo() {
    return InMemoryProjectRepository(projects: demoProjects);
  }

  final List<Project> _projects;
  final ProjectMigrationService _migrationService = const ProjectMigrationService();

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
    if (index == -1) {
      _projects.add(project);
      return;
    }
    _projects[index] = project;
  }

  @override
  Future<void> seedDemoProjectIfEmpty() async {
    if (_projects.isNotEmpty) {
      return;
    }
    _projects.addAll(demoProjects);
  }
}
