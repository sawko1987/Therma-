import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/calculation.dart';
import 'models/catalog.dart';
import 'models/project.dart';
import 'services/asset_catalog_repository.dart';
import 'services/default_building_calculation_assembler.dart';
import 'services/default_building_heat_loss_engine.dart';
import 'services/in_memory_project_repository.dart';
import 'services/interfaces.dart';
import 'services/preview_report_service.dart';
import 'services/preview_thermal_calculation_engine.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => AssetCatalogRepository(rootBundle),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => InMemoryProjectRepository.demo(),
);

final constructionPerformanceEngineProvider = Provider<ConstructionPerformanceEngine>(
  (ref) => const PreviewConstructionPerformanceEngine(),
);

final buildingCalculationAssemblerProvider = Provider<BuildingCalculationAssembler>(
  (ref) => DefaultBuildingCalculationAssembler(
    ref.read(constructionPerformanceEngineProvider),
  ),
);

final buildingHeatLossEngineProvider = Provider<BuildingHeatLossEngine>(
  (ref) => const DefaultBuildingHeatLossEngine(),
);

final reportServiceProvider = Provider<ReportService>(
  (ref) => const PreviewReportService(),
);

final catalogSnapshotProvider = FutureProvider<CatalogSnapshot>(
  (ref) => ref.read(catalogRepositoryProvider).loadSnapshot(),
);

final projectListProvider = FutureProvider<List<Project>>(
  (ref) => ref.read(projectRepositoryProvider).listProjects(),
);

final selectedProjectProvider = FutureProvider<Project?>((ref) async {
  final projects = await ref.watch(projectListProvider.future);
  if (projects.isEmpty) {
    return null;
  }
  return projects.first;
});

final selectedConstructionProvider = FutureProvider<Construction?>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null || project.constructions.isEmpty) {
    return null;
  }
  return project.constructions.first;
});

final selectedConstructionPerformanceProvider =
    FutureProvider<ConstructionPerformance?>((ref) async {
  final catalog = await ref.watch(catalogSnapshotProvider.future);
  final project = await ref.watch(selectedProjectProvider.future);
  final construction = await ref.watch(selectedConstructionProvider.future);
  if (project == null || construction == null) {
    return null;
  }
  return ref.read(constructionPerformanceEngineProvider).calculate(
        catalog: catalog,
        project: project,
        construction: construction,
      );
});

final selectedBuildingHeatLossProvider =
    FutureProvider<BuildingHeatLossResult?>((ref) async {
  final catalog = await ref.watch(catalogSnapshotProvider.future);
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return null;
  }
  final input = await ref.read(buildingCalculationAssemblerProvider).assemble(
        catalog: catalog,
        project: project,
      );
  return ref.read(buildingHeatLossEngineProvider).calculate(input: input);
});
