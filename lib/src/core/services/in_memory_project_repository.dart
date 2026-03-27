import '../models/project.dart';
import 'demo_project_seed.dart';
import 'interfaces.dart';

class InMemoryProjectRepository implements ProjectRepository {
  InMemoryProjectRepository({required List<Project> projects})
    : _projects = [...projects];

  factory InMemoryProjectRepository.demo() {
    return InMemoryProjectRepository(projects: demoProjects);
  }

  final List<Project> _projects;

  @override
  Future<List<Project>> listProjects() async => List.unmodifiable(_projects);

  @override
  Future<Project?> getProject(String id) async {
    for (final project in _projects) {
      if (project.id == id) {
        return project;
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
