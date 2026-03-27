import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/calculation.dart';
import 'models/catalog.dart';
import 'models/project.dart';
import 'services/asset_catalog_repository.dart';
import 'services/in_memory_project_repository.dart';
import 'services/interfaces.dart';
import 'services/normative_thermal_calculation_engine.dart';
import 'services/preview_report_service.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => AssetCatalogRepository(rootBundle),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => InMemoryProjectRepository.demo(),
);

final thermalCalculationEngineProvider = Provider<ThermalCalculationEngine>(
  (ref) => const NormativeThermalCalculationEngine(),
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

final calculationResultProvider = FutureProvider<CalculationResult?>((ref) async {
  final catalog = await ref.watch(catalogSnapshotProvider.future);
  final project = await ref.watch(selectedProjectProvider.future);
  final construction = await ref.watch(selectedConstructionProvider.future);
  if (project == null || construction == null) {
    return null;
  }
  return ref.read(thermalCalculationEngineProvider).calculate(
        catalog: catalog,
        project: project,
        construction: construction,
      );
});
