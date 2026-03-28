import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/building_heat_loss.dart';
import 'models/calculation.dart';
import 'models/catalog.dart';
import 'models/ground_floor_calculation.dart';
import 'models/project.dart';
import 'models/report.dart';
import 'services/asset_catalog_repository.dart';
import 'services/building_heat_loss_service.dart';
import 'services/drift_project_repository.dart';
import 'services/ground_floor_calculation_service.dart';
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

class SelectedObjectIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? objectId) {
    state = objectId;
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

class SelectedGroundFloorCalculationIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? calculationId) {
    state = calculationId;
  }
}

class ProjectEditor {
  ProjectEditor(this._ref);

  final Ref _ref;

  Future<void> saveProject(Project project) async {
    await _ref.read(projectRepositoryProvider).saveProject(project);
    _ref.invalidate(catalogSnapshotProvider);
    _ref.invalidate(materialCatalogEntriesProvider);
    _ref.invalidate(projectListProvider);
    _ref.invalidate(selectedProjectProvider);
    _ref.invalidate(selectedEnvelopeElementProvider);
    _ref.invalidate(selectedConstructionProvider);
    _ref.invalidate(buildingHeatLossResultProvider);
    _ref.invalidate(selectedGroundFloorCalculationProvider);
    _ref.invalidate(groundFloorCalculationResultProvider);
    _ref.invalidate(constructionLibraryProvider);
    _ref.invalidate(objectListProvider);
    _ref.invalidate(selectedObjectProvider);
  }

  Future<void> createObject({
    required String title,
    required String address,
    required String description,
    required String customerPhone,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final project = Project(
      id: 'project-$now',
      name: title,
      climatePointId: 'moscow',
      roomPreset: RoomPreset.livingRoom,
      constructions: const [],
      houseModel: HouseModel.bootstrapFromConstructions(const []),
    );
    final object = DesignObject(
      id: 'object-$now',
      title: title,
      address: address,
      description: description,
      customerPhone: customerPhone,
      projectId: project.id,
      updatedAtEpochMs: now,
    );
    await _ref.read(projectRepositoryProvider).saveProject(project);
    await _ref.read(objectRepositoryProvider).saveObject(object);
    _ref.read(selectedObjectIdProvider.notifier).select(object.id);
    _ref.read(selectedProjectIdProvider.notifier).select(project.id);
    _ref.invalidate(projectListProvider);
    _ref.invalidate(objectListProvider);
    _ref.invalidate(selectedObjectProvider);
    _ref.invalidate(selectedProjectProvider);
  }

  Future<void> updateObject(DesignObject object) async {
    await _ref.read(objectRepositoryProvider).saveObject(object);
    final project = await _ref
        .read(projectRepositoryProvider)
        .getProject(object.projectId);
    if (project != null && project.name != object.title) {
      await _ref
          .read(projectRepositoryProvider)
          .saveProject(project.copyWith(name: object.title));
    }
    _ref.invalidate(projectListProvider);
    _ref.invalidate(objectListProvider);
    _ref.invalidate(selectedObjectProvider);
    _ref.invalidate(selectedProjectProvider);
  }

  Future<void> deleteObject(String objectId) async {
    final object = await _ref
        .read(objectRepositoryProvider)
        .getObject(objectId);
    if (object == null) {
      return;
    }
    await _ref.read(objectRepositoryProvider).deleteObject(objectId);
    await _ref.read(projectRepositoryProvider).deleteProject(object.projectId);
    _ref.read(selectedObjectIdProvider.notifier).select(null);
    _ref.read(selectedProjectIdProvider.notifier).select(null);
    _ref.invalidate(projectListProvider);
    _ref.invalidate(objectListProvider);
    _ref.invalidate(selectedObjectProvider);
    _ref.invalidate(selectedProjectProvider);
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

  Future<void> updateEnvelopeWallPlacement(
    String elementId,
    EnvelopeWallPlacement wallPlacement,
  ) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateEnvelopeWallPlacement(project, elementId, wallPlacement);
    await saveProject(updated);
    _ref.read(selectedEnvelopeElementIdProvider.notifier).select(elementId);
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

  Future<void> addHeatingDevice(HeatingDevice device) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .addHeatingDevice(project, device);
    await saveProject(updated);
  }

  Future<void> updateHeatingDevice(HeatingDevice device) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateHeatingDevice(project, device);
    await saveProject(updated);
  }

  Future<void> deleteHeatingDevice(String heatingDeviceId) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .deleteHeatingDevice(project, heatingDeviceId);
    await saveProject(updated);
  }

  Future<void> addConstruction(Construction construction) async {
    final project = await _requireProject();
    await _ref
        .read(constructionLibraryRepositoryProvider)
        .saveConstruction(construction);
    final updated = _ref
        .read(projectEditingServiceProvider)
        .selectConstruction(project, construction);
    await saveProject(updated);
    _ref.read(selectedConstructionIdProvider.notifier).select(construction.id);
  }

  Future<void> saveCustomMaterial(MaterialEntry material) async {
    final project = await _requireProject();
    final updatedMaterials = [
      for (final item in project.customMaterials)
        if (item.id == material.id) material else item,
      if (!project.customMaterials.any((item) => item.id == material.id))
        material,
    ];
    await saveProject(project.copyWith(customMaterials: updatedMaterials));
  }

  Future<void> deleteCustomMaterial(String materialId) async {
    final project = await _requireProject();
    final isUsed = project.constructions.any(
      (construction) =>
          construction.layers.any((layer) => layer.materialId == materialId),
    );
    if (isUsed) {
      throw StateError(
        'Нельзя удалить материал, пока он используется в конструкции.',
      );
    }
    final updatedMaterials = [
      for (final item in project.customMaterials)
        if (item.id != materialId) item,
    ];
    await saveProject(project.copyWith(customMaterials: updatedMaterials));
  }

  Future<void> toggleFavoriteMaterial(String materialId) async {
    final repository = _ref.read(favoriteMaterialsRepositoryProvider);
    final current = await repository.listFavoriteMaterialIds();
    final updated = Set<String>.from(current);
    if (!updated.add(materialId)) {
      updated.remove(materialId);
    }
    await repository.saveFavoriteMaterialIds(updated);
    _ref.invalidate(favoriteMaterialIdsProvider);
    _ref.invalidate(materialCatalogEntriesProvider);
  }

  Future<void> updateConstruction(Construction construction) async {
    await updateLibraryConstruction(construction);
    _ref.read(selectedConstructionIdProvider.notifier).select(construction.id);
  }

  Future<void> deleteConstruction(String constructionId) async {
    await unselectConstructionFromProject(constructionId);
    _ref.read(selectedConstructionIdProvider.notifier).select(null);
  }

  Future<void> selectConstructionForProject(Construction construction) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .selectConstruction(project, construction);
    await saveProject(updated);
    _ref.read(selectedConstructionIdProvider.notifier).select(construction.id);
  }

  Future<void> unselectConstructionFromProject(String constructionId) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .unselectConstruction(project, constructionId);
    await saveProject(updated);
    final remainingIds = updated.effectiveSelectedConstructionIds;
    _ref
        .read(selectedConstructionIdProvider.notifier)
        .select(remainingIds.isEmpty ? null : remainingIds.first);
  }

  Future<void> saveConstructionToLibrary(Construction construction) async {
    await _ref
        .read(constructionLibraryRepositoryProvider)
        .saveConstruction(construction);
    _ref.invalidate(constructionLibraryProvider);
  }

  Future<void> updateLibraryConstruction(Construction construction) async {
    await saveConstructionToLibrary(construction);
    final repository = _ref.read(projectRepositoryProvider);
    final libraryId = construction.id;
    final allProjects = await repository.listProjects();
    for (final project in allProjects) {
      if (!project.effectiveSelectedConstructionIds.contains(libraryId)) {
        continue;
      }
      final existing = project.constructions.any(
        (item) => item.id == libraryId,
      );
      final updatedProject = existing
          ? _ref
                .read(projectEditingServiceProvider)
                .updateConstruction(project, construction)
          : _ref
                .read(projectEditingServiceProvider)
                .selectConstruction(project, construction);
      await repository.saveProject(updatedProject);
    }
    _ref.invalidate(projectListProvider);
    _ref.invalidate(selectedProjectProvider);
    _ref.invalidate(selectedEnvelopeElementProvider);
    _ref.invalidate(selectedConstructionProvider);
    _ref.invalidate(buildingHeatLossResultProvider);
    _ref.invalidate(selectedGroundFloorCalculationProvider);
    _ref.invalidate(groundFloorCalculationResultProvider);
    _ref.invalidate(constructionLibraryProvider);
  }

  Future<void> deleteConstructionFromLibrary(String constructionId) async {
    final projects = await _ref.read(projectRepositoryProvider).listProjects();
    final inUse = projects.any(
      (project) =>
          project.effectiveSelectedConstructionIds.contains(constructionId),
    );
    if (inUse) {
      throw StateError(
        'Нельзя удалить конструкцию из библиотеки, пока она выбрана в проекте.',
      );
    }
    await _ref
        .read(constructionLibraryRepositoryProvider)
        .deleteConstruction(constructionId);
    _ref.invalidate(constructionLibraryProvider);
  }

  Future<Construction> duplicateConstructionInLibrary(
    Construction source,
  ) async {
    final duplicated = source.copyWith(
      id: _buildDuplicateConstructionId(source.id),
      title: '${source.title} (копия)',
    );
    await saveConstructionToLibrary(duplicated);
    return duplicated;
  }

  Future<void> addGroundFloorCalculation(
    GroundFloorCalculation calculation,
  ) async {
    final project = await _requireProject();
    final updated = project.copyWith(
      groundFloorCalculations: [
        ...project.groundFloorCalculations,
        calculation,
      ],
    );
    await saveProject(updated);
    _ref
        .read(selectedGroundFloorCalculationIdProvider.notifier)
        .select(calculation.id);
  }

  Future<void> updateGroundFloorCalculation(
    GroundFloorCalculation calculation,
  ) async {
    final project = await _requireProject();
    final updated = project.copyWith(
      groundFloorCalculations: [
        for (final item in project.groundFloorCalculations)
          if (item.id == calculation.id) calculation else item,
      ],
    );
    await saveProject(updated);
    _ref
        .read(selectedGroundFloorCalculationIdProvider.notifier)
        .select(calculation.id);
  }

  Future<void> deleteGroundFloorCalculation(String calculationId) async {
    final project = await _requireProject();
    final updated = project.copyWith(
      groundFloorCalculations: [
        for (final item in project.groundFloorCalculations)
          if (item.id != calculationId) item,
      ],
    );
    await saveProject(updated);
    _ref.read(selectedGroundFloorCalculationIdProvider.notifier).select(null);
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

final objectRepositoryProvider = Provider<ObjectRepository>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  if (repository is ObjectRepository) {
    return repository as ObjectRepository;
  }
  return DriftProjectRepository(ref.watch(appDatabaseProvider));
});

final constructionLibraryRepositoryProvider =
    Provider<ConstructionLibraryRepository>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      if (repository is ConstructionLibraryRepository) {
        return repository as ConstructionLibraryRepository;
      }
      return DriftProjectRepository(ref.watch(appDatabaseProvider));
    });

final favoriteMaterialsRepositoryProvider =
    Provider<FavoriteMaterialsRepository>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      if (repository is FavoriteMaterialsRepository) {
        return repository as FavoriteMaterialsRepository;
      }
      return DriftProjectRepository(ref.watch(appDatabaseProvider));
    });

final thermalCalculationEngineProvider = Provider<ThermalCalculationEngine>(
  (ref) => const NormativeThermalCalculationEngine(),
);

final projectEditingServiceProvider = Provider<ProjectEditingService>(
  (ref) => const ProjectEditingService(),
);

final buildingHeatLossServiceProvider = Provider<BuildingHeatLossService>(
  (ref) => NormativeBuildingHeatLossService(
    ref.watch(thermalCalculationEngineProvider),
  ),
);

final groundFloorCalculationServiceProvider =
    Provider<GroundFloorCalculationService>(
      (ref) => NormativeGroundFloorCalculationService(
        ref.watch(thermalCalculationEngineProvider),
      ),
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

final catalogSnapshotProvider = FutureProvider<CatalogSnapshot>((ref) async {
  final baseCatalog = await ref.read(catalogRepositoryProvider).loadSnapshot();
  final project = await ref.watch(selectedProjectProvider.future);
  final materials = _mergeMaterials(
    baseCatalog.materials,
    project?.customMaterials ?? const [],
  );
  return CatalogSnapshot(
    climatePoints: baseCatalog.climatePoints,
    materials: materials,
    constructionTemplates: baseCatalog.constructionTemplates,
    norms: baseCatalog.norms,
    moistureRules: baseCatalog.moistureRules,
    roomKindConditions: baseCatalog.roomKindConditions,
    heatingDevices: baseCatalog.heatingDevices,
    datasetVersion: baseCatalog.datasetVersion,
  );
});

final favoriteMaterialIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref
      .read(favoriteMaterialsRepositoryProvider)
      .listFavoriteMaterialIds();
});

final materialCatalogEntriesProvider =
    FutureProvider<List<MaterialCatalogEntry>>((ref) async {
      final catalog = await ref.watch(catalogSnapshotProvider.future);
      final project = await ref.watch(selectedProjectProvider.future);
      final favorites = await ref.watch(favoriteMaterialIdsProvider.future);
      final customIds = {
        for (final item in project?.customMaterials ?? const <MaterialEntry>[])
          item.id,
      };
      return catalog.materials
          .map(
            (material) => MaterialCatalogEntry(
              material: material,
              source: customIds.contains(material.id)
                  ? MaterialCatalogSource.custom
                  : MaterialCatalogSource.seed,
              isFavorite: favorites.contains(material.id),
            ),
          )
          .toList(growable: false);
    });

final selectedProjectIdProvider =
    NotifierProvider<SelectedProjectIdNotifier, String?>(
      SelectedProjectIdNotifier.new,
    );

final selectedObjectIdProvider =
    NotifierProvider<SelectedObjectIdNotifier, String?>(
      SelectedObjectIdNotifier.new,
    );

final selectedConstructionIdProvider =
    NotifierProvider<SelectedConstructionIdNotifier, String?>(
      SelectedConstructionIdNotifier.new,
    );

final selectedEnvelopeElementIdProvider =
    NotifierProvider<SelectedEnvelopeElementIdNotifier, String?>(
      SelectedEnvelopeElementIdNotifier.new,
    );

final selectedGroundFloorCalculationIdProvider =
    NotifierProvider<SelectedGroundFloorCalculationIdNotifier, String?>(
      SelectedGroundFloorCalculationIdNotifier.new,
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

final objectListProvider = FutureProvider<List<DesignObject>>((ref) async {
  final repository = ref.read(objectRepositoryProvider);
  await repository.seedObjectsIfEmpty();
  final objects = await repository.listObjects();
  final selectedObjectId = ref.read(selectedObjectIdProvider);
  if (objects.isNotEmpty &&
      (selectedObjectId == null ||
          objects.every((item) => item.id != selectedObjectId))) {
    final first = objects.first;
    ref.read(selectedObjectIdProvider.notifier).select(first.id);
    ref.read(selectedProjectIdProvider.notifier).select(first.projectId);
  }
  return objects;
});

final selectedObjectProvider = FutureProvider<DesignObject?>((ref) async {
  final objects = await ref.watch(objectListProvider.future);
  if (objects.isEmpty) {
    return null;
  }
  final selectedObjectId = ref.watch(selectedObjectIdProvider);
  for (final object in objects) {
    if (object.id == selectedObjectId) {
      return object;
    }
  }
  return objects.first;
});

final constructionLibraryProvider = FutureProvider<List<Construction>>((
  ref,
) async {
  final catalog = await ref.watch(catalogSnapshotProvider.future);
  final library = await ref
      .read(constructionLibraryRepositoryProvider)
      .listConstructions();
  return _mergeConstructions(catalog.constructionTemplates, library);
});

List<MaterialEntry> _mergeMaterials(
  List<MaterialEntry> seeded,
  List<MaterialEntry> custom,
) {
  final merged = <String, MaterialEntry>{
    for (final item in seeded) item.id: item,
  };
  for (final item in custom) {
    merged[item.id] = item;
  }
  return merged.values.toList(growable: false);
}

List<Construction> _mergeConstructions(
  List<Construction> seeded,
  List<Construction> saved,
) {
  final merged = <String, Construction>{
    for (final item in seeded) item.id: item,
  };
  for (final item in saved) {
    merged[item.id] = item;
  }
  return merged.values.toList(growable: false);
}

final selectedProjectProvider = FutureProvider<Project?>((ref) async {
  final selectedObject = await ref.watch(selectedObjectProvider.future);
  if (selectedObject != null) {
    ref
        .read(selectedProjectIdProvider.notifier)
        .select(selectedObject.projectId);
    return ref
        .read(projectRepositoryProvider)
        .getProject(selectedObject.projectId);
  }
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

abstract interface class CustomerPhonePicker {
  Future<bool> get supportsContacts;
  Future<bool> get supportsCallLog;
  Future<List<CustomerPhoneRecord>> loadContacts();
  Future<List<CustomerPhoneRecord>> loadCallLog();
}

class CustomerPhoneRecord {
  const CustomerPhoneRecord({
    required this.label,
    required this.phone,
    this.subtitle,
  });

  final String label;
  final String phone;
  final String? subtitle;
}

class MethodChannelCustomerPhonePicker implements CustomerPhonePicker {
  static const _channel = MethodChannel('smartcalc_mobile/customer_phone');

  @override
  Future<bool> get supportsContacts async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return await _channel.invokeMethod<bool>('supportsContacts') ?? false;
  }

  @override
  Future<bool> get supportsCallLog async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return await _channel.invokeMethod<bool>('supportsCallLog') ?? false;
  }

  @override
  Future<List<CustomerPhoneRecord>> loadContacts() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const [];
    }
    final items =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>(
          'loadContacts',
        ) ??
        const [];
    return items
        .map(
          (item) => CustomerPhoneRecord(
            label: item['label'] as String,
            phone: item['phone'] as String,
            subtitle: item['subtitle'] as String?,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CustomerPhoneRecord>> loadCallLog() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const [];
    }
    final items =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>('loadCallLog') ??
        const [];
    return items
        .map(
          (item) => CustomerPhoneRecord(
            label: item['label'] as String,
            phone: item['phone'] as String,
            subtitle: item['subtitle'] as String?,
          ),
        )
        .toList(growable: false);
  }
}

final customerPhonePickerProvider = Provider<CustomerPhonePicker>(
  (ref) => MethodChannelCustomerPhonePicker(),
);

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

final constructionByIdProvider = FutureProvider.family<Construction?, String>((
  ref,
  constructionId,
) async {
  final project = await ref.watch(selectedProjectProvider.future);
  if (project != null) {
    for (final construction in project.constructions) {
      if (construction.id == constructionId) {
        return construction;
      }
    }
  }
  return ref
      .read(constructionLibraryRepositoryProvider)
      .getConstruction(constructionId);
});

final calculationResultForConstructionProvider =
    FutureProvider.family<CalculationResult?, String>((
      ref,
      constructionId,
    ) async {
      final catalog = await ref.watch(catalogSnapshotProvider.future);
      final project = await ref.watch(selectedProjectProvider.future);
      final construction = await ref.watch(
        constructionByIdProvider(constructionId).future,
      );
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

String _buildDuplicateConstructionId(String sourceId) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '$sourceId-copy-$timestamp';
}

final selectedGroundFloorCalculationProvider =
    FutureProvider<GroundFloorCalculation?>((ref) async {
      final project = await ref.watch(selectedProjectProvider.future);
      if (project == null || project.groundFloorCalculations.isEmpty) {
        return null;
      }

      final selectedCalculationId = ref.watch(
        selectedGroundFloorCalculationIdProvider,
      );
      for (final calculation in project.groundFloorCalculations) {
        if (calculation.id == selectedCalculationId) {
          return calculation;
        }
      }

      final fallback = project.groundFloorCalculations.first;
      ref
          .read(selectedGroundFloorCalculationIdProvider.notifier)
          .select(fallback.id);
      return fallback;
    });

final buildingHeatLossResultProvider = FutureProvider<BuildingHeatLossResult?>((
  ref,
) async {
  final catalog = await ref.watch(catalogSnapshotProvider.future);
  final project = await ref.watch(selectedProjectProvider.future);
  if (project == null) {
    return null;
  }
  return ref
      .read(buildingHeatLossServiceProvider)
      .calculate(catalog: catalog, project: project);
});

final groundFloorCalculationResultProvider =
    FutureProvider<GroundFloorCalculationResult?>((ref) async {
      final catalog = await ref.watch(catalogSnapshotProvider.future);
      final project = await ref.watch(selectedProjectProvider.future);
      final calculation = await ref.watch(
        selectedGroundFloorCalculationProvider.future,
      );
      if (project == null || calculation == null) {
        return null;
      }
      return ref
          .read(groundFloorCalculationServiceProvider)
          .calculate(
            catalog: catalog,
            project: project,
            calculation: calculation,
          );
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
