import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/calculation.dart';
import 'models/catalog.dart';
import 'models/project.dart';
import 'services/asset_catalog_repository.dart';
import 'services/drift_project_repository.dart';
import 'services/interfaces.dart';
import 'services/normative_thermal_calculation_engine.dart';
import 'services/preview_report_service.dart';
import 'storage/app_database.dart';

class SelectedProjectIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? projectId) {
    state = projectId;
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => AssetCatalogRepository(rootBundle),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => DriftProjectRepository(ref.watch(appDatabaseProvider)),
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

final selectedProjectIdProvider =
    NotifierProvider<SelectedProjectIdNotifier, String?>(
      SelectedProjectIdNotifier.new,
    );

final projectListProvider = FutureProvider<List<Project>>((ref) async {
  final repository = ref.read(projectRepositoryProvider);
  await repository.seedDemoProjectIfEmpty();
  final projects = await repository.listProjects();
  final selectedProjectId = ref.read(selectedProjectIdProvider);

  if (projects.isNotEmpty &&
      (selectedProjectId == null ||
          projects.every((item) => item.id != selectedProjectId))) {
    ref.read(selectedProjectIdProvider.notifier).select(projects.first.id);
  }

  return projects;
});

final selectedProjectProvider = FutureProvider<Project?>((ref) async {
  final projects = await ref.watch(projectListProvider.future);
  if (projects.isEmpty) {
    return null;
  }
  final selectedProjectId = ref.watch(selectedProjectIdProvider);

  for (final project in projects) {
    if (project.id == selectedProjectId) {
      return project;
    }
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

final calculationResultProvider = FutureProvider<CalculationResult?>((
  ref,
) async {
  final catalog = await ref.watch(catalogSnapshotProvider.future);
  final project = await ref.watch(selectedProjectProvider.future);
  final construction = await ref.watch(selectedConstructionProvider.future);
  if (project == null || construction == null) {
    return null;
  }
  return ref
      .read(thermalCalculationEngineProvider)
      .calculate(
        catalog: catalog,
        project: project,
        construction: construction,
      );
});
