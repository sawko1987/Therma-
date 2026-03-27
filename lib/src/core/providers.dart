import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/calculation.dart';
import 'models/catalog.dart';
import 'models/project.dart';
import 'models/report.dart';
import 'services/asset_catalog_repository.dart';
import 'services/drift_project_repository.dart';
import 'services/interfaces.dart';
import 'services/local_report_file_store.dart';
import 'services/normative_thermal_calculation_engine.dart';
import 'services/pdf_report_service.dart';
import 'services/thermal_report_content_builder.dart';
import 'storage/app_database.dart';

class SelectedProjectIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? projectId) {
    state = projectId;
  }
}

class ReportExportController extends AsyncNotifier<SavedReport?> {
  @override
  Future<SavedReport?> build() async => null;

  Future<SavedReport> exportCurrentCalculation() async {
    state = const AsyncLoading();
    final savedReport = await AsyncValue.guard(() async {
      final catalog = await ref.read(catalogSnapshotProvider.future);
      final project = await ref.read(selectedProjectProvider.future);
      final construction = await ref.read(selectedConstructionProvider.future);
      final calculation = await ref.read(calculationResultProvider.future);
      if (project == null || construction == null || calculation == null) {
        throw StateError('Недостаточно данных для экспорта отчета.');
      }

      final content = ref
          .read(reportContentBuilderProvider)
          .buildContent(
            catalog: catalog,
            project: project,
            construction: construction,
            calculation: calculation,
          );
      final document = await ref
          .read(reportServiceProvider)
          .buildReport(content: content);

      return ref.read(reportFileStoreProvider).saveReport(document);
    });

    state = savedReport;
    if (savedReport.hasError) {
      throw savedReport.error!;
    }
    return savedReport.requireValue;
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

final reportContentBuilderProvider = Provider<ReportContentBuilder>(
  (ref) => const ThermalReportContentBuilder(),
);

final reportServiceProvider = Provider<ReportService>(
  (ref) => PdfReportService(rootBundle),
);

final reportFileStoreProvider = Provider<ReportFileStore>(
  (ref) => LocalReportFileStore(),
);

final reportExportControllerProvider =
    AsyncNotifierProvider<ReportExportController, SavedReport?>(
      ReportExportController.new,
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
