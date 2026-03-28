import '../models/calculation.dart';
import '../models/building_heat_loss.dart';
import '../models/catalog.dart';
import '../models/ground_floor_calculation.dart';
import '../models/project.dart';
import '../models/report.dart';

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

abstract interface class BuildingHeatLossService {
  Future<BuildingHeatLossResult> calculate({
    required CatalogSnapshot catalog,
    required Project project,
  });
}

abstract interface class GroundFloorCalculationService {
  Future<GroundFloorCalculationResult> calculate({
    required CatalogSnapshot catalog,
    required Project project,
    required GroundFloorCalculation calculation,
  });
}

abstract interface class ReportContentBuilder {
  ReportContent buildContent({
    required CatalogSnapshot catalog,
    required Project project,
    required Construction construction,
    required CalculationResult calculation,
  });
}

abstract interface class ReportService {
  Future<ReportDocument> buildReport({required ReportContent content});
}

abstract interface class ReportFileStore {
  Future<SavedReport> saveReport(ReportDocument document);
}
