import '../models/calculation.dart';
import '../models/building_heat_loss.dart';
import '../models/catalog.dart';
import '../models/ground_floor_calculation.dart';
import '../models/heating_economics.dart';
import '../models/project.dart';
import '../models/report.dart';

abstract interface class CatalogRepository {
  Future<CatalogSnapshot> loadSnapshot();
}

abstract interface class ProjectRepository {
  Future<List<Project>> listProjects();
  Future<Project?> getProject(String id);
  Future<void> saveProject(Project project);
  Future<void> deleteProject(String id);
  Future<void> seedDemoProjectIfEmpty();
}

abstract interface class ConstructionLibraryRepository {
  Future<List<Construction>> listConstructions();
  Future<Construction?> getConstruction(String id);
  Future<void> saveConstruction(Construction construction);
  Future<void> deleteConstruction(String id);
}

abstract interface class ObjectRepository {
  Future<List<DesignObject>> listObjects();
  Future<DesignObject?> getObject(String id);
  Future<void> saveObject(DesignObject object);
  Future<void> deleteObject(String id);
  Future<void> seedObjectsIfEmpty();
}

abstract interface class FavoriteMaterialsRepository {
  Future<Set<String>> listFavoriteMaterialIds();
  Future<void> saveFavoriteMaterialIds(Set<String> ids);
}

abstract interface class OpeningCatalogRepository {
  Future<List<OpeningTypeEntry>> listEntries();
  Future<void> saveEntry(OpeningTypeEntry entry);
  Future<void> deleteEntry(String id);
}

abstract interface class AppPreferencesRepository {
  Future<bool> getConstructionPickerSwipeTutorialSeen();
  Future<void> setConstructionPickerSwipeTutorialSeen(bool seen);
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

abstract interface class HeatingEconomicsService {
  Future<HeatingEconomicsResult> calculate({
    required CatalogSnapshot catalog,
    required Project project,
    required BuildingHeatLossResult buildingHeatLoss,
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
