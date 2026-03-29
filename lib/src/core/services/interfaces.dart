import '../models/calculation.dart';
import '../models/catalog.dart';
import '../models/project.dart';

abstract interface class CatalogRepository {
  Future<CatalogSnapshot> loadSnapshot();
}

abstract interface class ProjectRepository {
  Future<List<Project>> listProjects();
}

abstract interface class ConstructionPerformanceEngine {
  Future<ConstructionPerformance> calculate({
    required CatalogSnapshot catalog,
    required Project project,
    required Construction construction,
  });
}

abstract interface class BuildingCalculationAssembler {
  Future<BuildingCalculationInput> assemble({
    required CatalogSnapshot catalog,
    required Project project,
  });
}

abstract interface class BuildingHeatLossEngine {
  Future<BuildingHeatLossResult> calculate({
    required BuildingCalculationInput input,
  });
}

abstract interface class ReportService {
  Future<String> buildReport(Project project);
}
