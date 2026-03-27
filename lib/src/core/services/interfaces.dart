import '../models/calculation.dart';
import '../models/catalog.dart';
import '../models/project.dart';

abstract interface class CatalogRepository {
  Future<CatalogSnapshot> loadSnapshot();
}

abstract interface class ProjectRepository {
  Future<List<Project>> listProjects();
  Future<Project?> getProject(String id);
  Future<void> saveProject(Project project);
  Future<void> seedDemoProjectIfEmpty();
}

abstract interface class ThermalCalculationEngine {
  Future<CalculationResult> calculate({
    required CatalogSnapshot catalog,
    required Project project,
    required Construction construction,
  });
}

abstract interface class ReportService {
  Future<String> buildReport(Project project);
}
