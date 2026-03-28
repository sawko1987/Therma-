import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/calculation.dart';
import 'models/catalog.dart';
import 'models/project.dart';
import 'models/report.dart';
import 'services/asset_catalog_repository.dart';
import 'services/drift_project_repository.dart';
import 'services/house_summary_service.dart';
import 'services/interfaces.dart';
import 'services/local_report_file_store.dart';
import 'services/normative_thermal_calculation_engine.dart';
import 'services/pdf_report_service.dart';
import 'services/project_editing_service.dart';
import 'services/thermal_report_content_builder.dart';
import 'storage/app_database.dart';

class SelectedProjectIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? projectId) {
    state = projectId;
  }
}

class SelectedConstructionIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? constructionId) {
    state = constructionId;
  }
}

class SelectedEnvelopeElementIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? elementId) {
    state = elementId;
  }
}

class ProjectEditor {
  ProjectEditor(this._ref);

  final Ref _ref;

  Future<void> saveProject(Project project) async {
    await _ref.read(projectRepositoryProvider).saveProject(project);
    _ref.invalidate(projectListProvider);
    _ref.invalidate(selectedProjectProvider);
    _ref.invalidate(selectedEnvelopeElementProvider);
    _ref.invalidate(selectedConstructionProvider);
    _ref.invalidate(houseThermalSummaryProvider);
  }

  Future<void> addRoom(Room room) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .addRoom(project, room);
    await saveProject(updated);
  }

  Future<void> updateRoom(Room room) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateRoom(project, room);
    await saveProject(updated);
  }

  Future<void> deleteRoom(String roomId) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .deleteRoom(project, roomId);
    await saveProject(updated);
  }

  Future<void> updateRoomLayout(String roomId, RoomLayoutRect layout) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateRoomLayout(project, roomId, layout);
    await saveProject(updated);
  }

  Future<void> addEnvelopeElement(HouseEnvelopeElement element) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .addEnvelopeElement(project, element);
    await saveProject(updated);
    _ref.read(selectedEnvelopeElementIdProvider.notifier).select(element.id);
    _ref
        .read(selectedConstructionIdProvider.notifier)
        .select(element.constructionId);
  }

  Future<void> updateEnvelopeElement(HouseEnvelopeElement element) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateEnvelopeElement(project, element);
    await saveProject(updated);
    _ref.read(selectedEnvelopeElementIdProvider.notifier).select(element.id);
    _ref
        .read(selectedConstructionIdProvider.notifier)
        .select(element.constructionId);
  }

  Future<void> deleteEnvelopeElement(String elementId) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .deleteEnvelopeElement(project, elementId);
    await saveProject(updated);
    _ref.read(selectedEnvelopeElementIdProvider.notifier).select(null);
  }

  Future<void> addOpening(EnvelopeOpening opening) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .addOpening(project, opening);
    await saveProject(updated);
    _ref
        .read(selectedEnvelopeElementIdProvider.notifier)
        .select(opening.elementId);
  }

  Future<void> updateOpening(EnvelopeOpening opening) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateOpening(project, opening);
    await saveProject(updated);
    _ref
        .read(selectedEnvelopeElementIdProvider.notifier)
        .select(opening.elementId);
  }

  Future<void> deleteOpening(String openingId) async {
    final project = await _requireProject();
    final opening = project.houseModel.openings.firstWhere(
      (item) => item.id == openingId,
    );
    final updated = _ref
        .read(projectEditingServiceProvider)
        .deleteOpening(project, openingId);
    await saveProject(updated);
    _ref
        .read(selectedEnvelopeElementIdProvider.notifier)
        .select(opening.elementId);
  }

  Future<void> addConstruction(Construction construction) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .addConstruction(project, construction);
    await saveProject(updated);
    _ref.read(selectedConstructionIdProvider.notifier).select(construction.id);
  }

  Future<void> updateConstruction(Construction construction) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateConstruction(project, construction);
    await saveProject(updated);
    _ref.read(selectedConstructionIdProvider.notifier).select(construction.id);
  }

  Future<void> deleteConstruction(String constructionId) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .deleteConstruction(project, constructionId);
    await saveProject(updated);
    _ref.read(selectedConstructionIdProvider.notifier).select(null);
  }

  void selectEnvelopeElement(HouseEnvelopeElement element) {
    _ref.read(selectedEnvelopeElementIdProvider.notifier).select(element.id);
    _ref
        .read(selectedConstructionIdProvider.notifier)
        .select(element.constructionId);
  }

  Future<Project> _requireProject() async {
    final project = await _ref.read(selectedProjectProvider.future);
    if (project == null) {
      throw StateError('Активный проект не найден.');
    }
    return project;
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

final projectEditingServiceProvider = Provider<ProjectEditingService>(
  (ref) => const ProjectEditingService(),
);

final houseSummaryServiceProvider = Provider<HouseSummaryService>(
  (ref) => HouseSummaryService(ref.watch(thermalCalculationEngineProvider)),
);

final projectEditorProvider = Provider<ProjectEditor>(
  (ref) => ProjectEditor(ref),
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

final selectedConstructionIdProvider =
    NotifierProvider<SelectedConstructionIdNotifier, String?>(
      SelectedConstructionIdNotifier.new,
    );

final selectedEnvelopeElementIdProvider =
    NotifierProvider<SelectedEnvelopeElementIdNotifier, String?>(
      SelectedEnvelopeElementIdNotifier.new,
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

final selectedEnvelopeElementProvider = FutureProvider<HouseEnvelopeElement?>((
  ref,
) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null || project.houseModel.elements.isEmpty) {
    return null;
  }

  final selectedElementId = ref.watch(selectedEnvelopeElementIdProvider);
  final elements = project.houseModel.elements;
  for (final element in elements) {
    if (element.id == selectedElementId) {
      return element;
    }
  }

  final fallback = elements.first;
  if (selectedElementId == null || selectedElementId != fallback.id) {
    ref.read(selectedEnvelopeElementIdProvider.notifier).select(fallback.id);
  }
  return fallback;
});

final selectedConstructionProvider = FutureProvider<Construction?>((ref) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null || project.constructions.isEmpty) {
    return null;
  }

  final selectedConstructionId = ref.watch(selectedConstructionIdProvider);
  final selectedElement = await ref.watch(
    selectedEnvelopeElementProvider.future,
  );
  final preferredIds = [
    selectedConstructionId,
    selectedElement?.constructionId,
  ];

  for (final preferredId in preferredIds) {
    for (final construction in project.constructions) {
      if (construction.id == preferredId) {
        if (selectedConstructionId != construction.id) {
          ref
              .read(selectedConstructionIdProvider.notifier)
              .select(construction.id);
        }
        return construction;
      }
    }
  }

  final fallback = project.constructions.first;
  ref.read(selectedConstructionIdProvider.notifier).select(fallback.id);
  return fallback;
});

final houseThermalSummaryProvider = FutureProvider<HouseThermalSummary?>((
  ref,
) async {
  final catalog = await ref.watch(catalogSnapshotProvider.future);
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return null;
  }
  return ref
      .read(houseSummaryServiceProvider)
      .buildSummary(catalog: catalog, project: project);
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
