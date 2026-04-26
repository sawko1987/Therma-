import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'logging/app_logging.dart';
import 'models/building_heat_loss.dart';
import 'models/calculation.dart';
import 'models/catalog.dart';
import 'models/ground_floor_calculation.dart';
import 'models/heating_economics.dart';
import 'models/project.dart';
import 'models/report.dart';
import 'services/asset_catalog_repository.dart';
import 'services/building_heat_loss_service.dart';
import 'services/drift_project_repository.dart';
import 'services/ground_floor_calculation_service.dart';
import 'services/heating_device_selection_service.dart';
import 'services/heating_economics_service.dart';
import 'services/interfaces.dart';
import 'services/local_report_file_store.dart';
import 'services/normative_thermal_calculation_engine.dart';
import 'services/pdf_report_service.dart';
import 'services/project_editing_service.dart';
import 'services/thermal_report_content_builder.dart';
import 'services/underfloor_heating_calculation_service.dart';
import 'storage/app_database.dart' as db;

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
  AppLogger get _logger => _ref.read(appLoggerProvider);

  Future<void> saveProject(Project project) async {
    await _logger.runLoggedAction(
      action: 'Save project',
      category: AppLogCategory.repository,
      context: {
        'projectId': project.id,
        'projectName': project.name,
        'climatePointId': project.climatePointId,
      },
      operation: () async {
        await _ref.read(projectRepositoryProvider).saveProject(project);
        _ref.invalidate(catalogSnapshotProvider);
        _ref.invalidate(openingCatalogEntriesProvider);
        _ref.invalidate(heatingDeviceCatalogEntriesProvider);
        _ref.invalidate(heatingValveCatalogEntriesProvider);
        _ref.invalidate(materialCatalogEntriesProvider);
        _ref.invalidate(projectListProvider);
        _ref.invalidate(selectedProjectProvider);
        _ref.invalidate(selectedEnvelopeElementProvider);
        _ref.invalidate(selectedConstructionProvider);
        _ref.invalidate(buildingHeatLossResultProvider);
        _ref.invalidate(heatingEconomicsResultProvider);
        _ref.invalidate(selectedGroundFloorCalculationProvider);
        _ref.invalidate(groundFloorCalculationResultProvider);
        _ref.invalidate(constructionLibraryProvider);
        _ref.invalidate(objectListProvider);
        _ref.invalidate(selectedObjectProvider);
      },
      successMessage: 'Project saved',
      logStart: false,
    );
  }

  Future<void> createObject({
    required String title,
    required String address,
    required String description,
    required String customerPhone,
    required String climatePointId,
    required HeatingSystemParameters heatingSystemParameters,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final project = Project(
      id: 'project-$now',
      name: title,
      climatePointId: climatePointId,
      roomPreset: RoomPreset.livingRoom,
      constructions: const [],
      houseModel: HouseModel.bootstrapFromConstructions(const []),
      heatingSystemParameters: heatingSystemParameters,
    );
    final object = DesignObject(
      id: 'object-$now',
      title: title,
      address: address,
      description: description,
      customerPhone: customerPhone,
      climatePointId: climatePointId,
      projectId: project.id,
      updatedAtEpochMs: now,
    );
    await _logger.runLoggedAction(
      action: 'Create object',
      category: AppLogCategory.repository,
      context: {
        'projectId': project.id,
        'objectId': object.id,
        'customerPhone': customerPhone,
        'address': address,
      },
      operation: () async {
        await _ref.read(projectRepositoryProvider).saveProject(project);
        await _ref.read(objectRepositoryProvider).saveObject(object);
        _ref.read(selectedObjectIdProvider.notifier).select(object.id);
        _ref.read(selectedProjectIdProvider.notifier).select(project.id);
        _ref.invalidate(projectListProvider);
        _ref.invalidate(objectListProvider);
        _ref.invalidate(selectedObjectProvider);
        _ref.invalidate(selectedProjectProvider);
      },
      successMessage: 'Object created',
    );
  }

  Future<void> updateObject(
    DesignObject object, {
    HeatingSystemParameters? heatingSystemParameters,
  }) async {
    await _logger.runLoggedAction(
      action: 'Update object',
      category: AppLogCategory.repository,
      context: {
        'objectId': object.id,
        'projectId': object.projectId,
        'customerPhone': object.customerPhone,
        'address': object.address,
      },
      operation: () async {
        await _ref.read(objectRepositoryProvider).saveObject(object);
        final project = await _ref
            .read(projectRepositoryProvider)
            .getProject(object.projectId);
        if (project != null &&
            (project.name != object.title ||
                project.climatePointId != object.climatePointId ||
                heatingSystemParameters != null)) {
          final existing = project.heatingSystemParameters;
          final updatedHeatingSystemParameters = heatingSystemParameters == null
              ? existing
              : existing?.copyWith(
                      designFlowTempC: heatingSystemParameters.designFlowTempC,
                      designReturnTempC:
                          heatingSystemParameters.designReturnTempC,
                    ) ??
                    heatingSystemParameters;
          await _ref
              .read(projectRepositoryProvider)
              .saveProject(
                project.copyWith(
                  name: object.title,
                  climatePointId: object.climatePointId,
                  heatingSystemParameters: updatedHeatingSystemParameters,
                ),
              );
        }
        _ref.invalidate(projectListProvider);
        _ref.invalidate(objectListProvider);
        _ref.invalidate(selectedObjectProvider);
        _ref.invalidate(selectedProjectProvider);
        _ref.invalidate(catalogSnapshotProvider);
      },
      successMessage: 'Object updated',
      logStart: false,
    );
  }

  Future<void> deleteObject(String objectId) async {
    final object = await _ref
        .read(objectRepositoryProvider)
        .getObject(objectId);
    if (object == null) {
      _logger.warning(
        'Delete object skipped: object not found',
        category: AppLogCategory.repository,
        context: {'objectId': objectId},
      );
      return;
    }
    await _logger.runLoggedAction(
      action: 'Delete object',
      category: AppLogCategory.repository,
      context: {'objectId': objectId, 'projectId': object.projectId},
      operation: () async {
        await _ref.read(objectRepositoryProvider).deleteObject(objectId);
        await _ref
            .read(projectRepositoryProvider)
            .deleteProject(object.projectId);
        _ref.read(selectedObjectIdProvider.notifier).select(null);
        _ref.read(selectedProjectIdProvider.notifier).select(null);
        _ref.invalidate(projectListProvider);
        _ref.invalidate(objectListProvider);
        _ref.invalidate(selectedObjectProvider);
        _ref.invalidate(selectedProjectProvider);
      },
      successMessage: 'Object deleted',
    );
  }

  Future<void> addRoom(Room room) async {
    final project = await _requireProject();
    _logger.debug(
      'Add room',
      category: AppLogCategory.repository,
      context: {
        'projectId': project.id,
        'roomId': room.id,
        'roomTitle': room.title,
      },
    );
    final updated = _ref
        .read(projectEditingServiceProvider)
        .addRoom(project, room);
    await saveProject(updated);
  }

  Future<void> updateRoom(Room room) async {
    final project = await _requireProject();
    _logger.debug(
      'Update room',
      category: AppLogCategory.repository,
      context: {
        'projectId': project.id,
        'roomId': room.id,
        'roomTitle': room.title,
      },
    );
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateRoom(project, room);
    await saveProject(updated);
  }

  Future<void> deleteRoom(String roomId) async {
    final project = await _requireProject();
    _logger.debug(
      'Delete room',
      category: AppLogCategory.repository,
      context: {'projectId': project.id, 'roomId': roomId},
    );
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
    _logger.debug(
      'Add envelope element',
      category: AppLogCategory.repository,
      context: {
        'projectId': project.id,
        'elementId': element.id,
        'constructionId': element.construction.id,
      },
    );
    final updated = _ref
        .read(projectEditingServiceProvider)
        .addEnvelopeElement(project, element);
    await saveProject(updated);
    _ref.read(selectedEnvelopeElementIdProvider.notifier).select(element.id);
    _ref
        .read(selectedConstructionIdProvider.notifier)
        .select(element.sourceConstructionId ?? element.construction.id);
  }

  Future<void> updateEnvelopeElement(HouseEnvelopeElement element) async {
    final project = await _requireProject();
    _logger.debug(
      'Update envelope element',
      category: AppLogCategory.repository,
      context: {
        'projectId': project.id,
        'elementId': element.id,
        'constructionId': element.construction.id,
      },
    );
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateEnvelopeElement(project, element);
    await saveProject(updated);
    _ref.read(selectedEnvelopeElementIdProvider.notifier).select(element.id);
    _ref
        .read(selectedConstructionIdProvider.notifier)
        .select(element.sourceConstructionId ?? element.construction.id);
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

  Future<void> updateEnvelopeWallArea(
    String elementId,
    double areaSquareMeters,
  ) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateEnvelopeWallArea(project, elementId, areaSquareMeters);
    await saveProject(updated);
    _ref.read(selectedEnvelopeElementIdProvider.notifier).select(elementId);
  }

  Future<void> deleteEnvelopeElement(String elementId) async {
    final project = await _requireProject();
    _logger.debug(
      'Delete envelope element',
      category: AppLogCategory.repository,
      context: {'projectId': project.id, 'elementId': elementId},
    );
    final updated = _ref
        .read(projectEditingServiceProvider)
        .deleteEnvelopeElement(project, elementId);
    await saveProject(updated);
    _ref.read(selectedEnvelopeElementIdProvider.notifier).select(null);
  }

  Future<void> addOpening(EnvelopeOpening opening) async {
    final project = await _requireProject();
    _logger.debug(
      'Add opening',
      category: AppLogCategory.repository,
      context: {
        'projectId': project.id,
        'openingId': opening.id,
        'elementId': opening.elementId,
      },
    );
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
    _logger.debug(
      'Update opening',
      category: AppLogCategory.repository,
      context: {
        'projectId': project.id,
        'openingId': opening.id,
        'elementId': opening.elementId,
      },
    );
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
    _logger.debug(
      'Delete opening',
      category: AppLogCategory.repository,
      context: {
        'projectId': project.id,
        'openingId': openingId,
        'elementId': opening.elementId,
      },
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

  Future<void> addUnderfloorHeatingCalculation(
    UnderfloorHeatingCalculation calculation,
  ) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .addUnderfloorHeatingCalculation(project, calculation);
    await saveProject(updated);
  }

  Future<void> updateUnderfloorHeatingCalculation(
    UnderfloorHeatingCalculation calculation,
  ) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .updateUnderfloorHeatingCalculation(project, calculation);
    await saveProject(updated);
  }

  Future<void> deleteUnderfloorHeatingCalculation(String calculationId) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .deleteUnderfloorHeatingCalculation(project, calculationId);
    await saveProject(updated);
  }

  Future<void> updateHeatingSystemParameters(
    HeatingSystemParameters? parameters,
  ) async {
    final project = await _requireProject();
    await saveProject(
      project.copyWith(
        heatingSystemParameters: parameters,
        clearHeatingSystemParameters: parameters == null,
      ),
    );
  }

  Future<void> updateHeatingEconomicsSettings(
    HeatingEconomicsSettings settings,
  ) async {
    final project = await _requireProject();
    _logger.info(
      'Update heating economics settings',
      category: AppLogCategory.repository,
      context: {'projectId': project.id},
    );
    await saveProject(project.copyWith(heatingEconomicsSettings: settings));
  }

  Future<void> setBuildingStepRoomsOnboardingEnabled(bool enabled) async {
    final project = await _requireProject();
    await saveProject(
      project.copyWith(showBuildingStepRoomsOnboarding: enabled),
    );
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

  Future<void> addProjectOnlyConstruction(Construction construction) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .addConstruction(project, construction);
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

  Future<void> restoreSeedMaterial(String materialId) async {
    final project = await _requireProject();
    final updatedMaterials = [
      for (final item in project.customMaterials)
        if (item.id != materialId) item,
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

  Future<void> saveOpeningCatalogEntry(OpeningTypeEntry entry) async {
    await _ref.read(openingCatalogRepositoryProvider).saveEntry(entry);
    _ref.invalidate(catalogSnapshotProvider);
    _ref.invalidate(openingCatalogEntriesProvider);
  }

  Future<void> deleteOpeningCatalogEntry(String entryId) async {
    await _ref.read(openingCatalogRepositoryProvider).deleteEntry(entryId);
    _ref.invalidate(catalogSnapshotProvider);
    _ref.invalidate(openingCatalogEntriesProvider);
  }

  Future<void> saveHeatingDeviceCatalogEntry(
    HeatingDeviceCatalogEntry entry,
  ) async {
    await _ref
        .read(heatingDeviceCatalogRepositoryProvider)
        .saveHeatingDeviceCatalogEntry(entry.copyWith(isCustom: true));
    _ref.invalidate(catalogSnapshotProvider);
    _ref.invalidate(heatingDeviceCatalogEntriesProvider);
    _ref.invalidate(heatingDeviceCatalogItemsProvider);
  }

  Future<void> deleteHeatingDeviceCatalogEntry(String entryId) async {
    await _ref
        .read(heatingDeviceCatalogRepositoryProvider)
        .deleteHeatingDeviceCatalogEntry(entryId);
    _ref.invalidate(catalogSnapshotProvider);
    _ref.invalidate(heatingDeviceCatalogEntriesProvider);
    _ref.invalidate(heatingDeviceCatalogItemsProvider);
  }

  Future<void> saveHeatingValveCatalogEntry(
    HeatingValveCatalogEntry entry,
  ) async {
    await _ref
        .read(heatingValveCatalogRepositoryProvider)
        .saveHeatingValveCatalogEntry(entry.copyWith(isCustom: true));
    _ref.invalidate(catalogSnapshotProvider);
    _ref.invalidate(heatingValveCatalogEntriesProvider);
    _ref.invalidate(heatingValveCatalogItemsProvider);
  }

  Future<void> deleteHeatingValveCatalogEntry(String entryId) async {
    await _ref
        .read(heatingValveCatalogRepositoryProvider)
        .deleteHeatingValveCatalogEntry(entryId);
    _ref.invalidate(catalogSnapshotProvider);
    _ref.invalidate(heatingValveCatalogEntriesProvider);
    _ref.invalidate(heatingValveCatalogItemsProvider);
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

  Future<void> excludeConstructionFromCalculation(String constructionId) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .excludeConstructionFromCalculation(project, constructionId);
    await saveProject(updated);
    _ref.read(selectedConstructionIdProvider.notifier).select(constructionId);
  }

  Future<void> includeConstructionInCalculation(String constructionId) async {
    final project = await _requireProject();
    final updated = _ref
        .read(projectEditingServiceProvider)
        .includeConstructionInCalculation(project, constructionId);
    await saveProject(updated);
    _ref.read(selectedConstructionIdProvider.notifier).select(constructionId);
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
    final objects = await _ref.read(objectRepositoryProvider).listObjects();
    final visibleProjectIds = objects.map((object) => object.projectId).toSet();
    final projects = await _ref.read(projectRepositoryProvider).listProjects();
    for (final project in projects) {
      if (!visibleProjectIds.contains(project.id)) {
        continue;
      }
      final usedByEnvelope = project.houseModel.elements.any(
        (element) => element.constructionId == constructionId,
      );
      if (usedByEnvelope) {
        throw StateError(
          'Нельзя удалить конструкцию из библиотеки, пока она используется в ограждающих конструкциях проекта "${project.name}".',
        );
      }
      GroundFloorCalculation? groundFloorCalculation;
      for (final calculation in project.groundFloorCalculations) {
        if (calculation.constructionId == constructionId) {
          groundFloorCalculation = calculation;
          break;
        }
      }
      if (groundFloorCalculation != null) {
        throw StateError(
          'Нельзя удалить конструкцию из библиотеки, пока она используется в расчете пола по грунту "${groundFloorCalculation.title}" проекта "${project.name}".',
        );
      }
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
    _logger.info(
      'Add ground floor calculation',
      category: AppLogCategory.calculation,
      context: {
        'projectId': project.id,
        'calculationId': calculation.id,
        'constructionId': calculation.constructionId,
      },
    );
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
    _logger.info(
      'Update ground floor calculation',
      category: AppLogCategory.calculation,
      context: {
        'projectId': project.id,
        'calculationId': calculation.id,
        'constructionId': calculation.constructionId,
      },
    );
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
    _logger.info(
      'Delete ground floor calculation',
      category: AppLogCategory.calculation,
      context: {'projectId': project.id, 'calculationId': calculationId},
    );
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
        .select(element.sourceConstructionId ?? element.construction.id);
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
      final logger = ref.read(appLoggerProvider);
      final catalog = await ref.read(catalogSnapshotProvider.future);
      final project = await ref.read(selectedProjectProvider.future);
      final construction = await ref.read(selectedConstructionProvider.future);
      final calculation = await ref.read(calculationResultProvider.future);
      if (project == null || construction == null || calculation == null) {
        throw StateError('Недостаточно данных для экспорта отчета.');
      }

      logger.info(
        'Start PDF export',
        category: AppLogCategory.report,
        context: {
          'projectId': project.id,
          'constructionId': construction.id,
          'constructionTitle': construction.title,
        },
      );
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

      final savedReport = await ref
          .read(reportFileStoreProvider)
          .saveReport(document);
      logger.info(
        'PDF export completed',
        category: AppLogCategory.report,
        context: {
          'projectId': project.id,
          'constructionId': construction.id,
          'fileName': savedReport.fileName,
          'filePath': savedReport.filePath,
        },
      );
      return savedReport;
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

final logHistoryStoreProvider = Provider<LogHistoryStore>(
  (ref) => LogHistoryStore(),
);

final talkerProvider = Provider<Talker>(
  (ref) => buildTalker(logHistoryStore: ref.watch(logHistoryStoreProvider)),
);

final appLoggerProvider = Provider<AppLogger>(
  (ref) => AppLogger(ref.watch(talkerProvider)),
);

final appErrorReporterProvider = Provider<AppErrorReporter>(
  (ref) => AppErrorReporter(ref.watch(appLoggerProvider)),
);

final appDatabaseProvider = Provider<db.AppDatabase>((ref) {
  final database = db.AppDatabase(logger: ref.watch(appLoggerProvider));
  ref.onDispose(database.close);
  return database;
});

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => DriftProjectRepository(
    ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final objectRepositoryProvider = Provider<ObjectRepository>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  if (repository is ObjectRepository) {
    return repository as ObjectRepository;
  }
  return DriftProjectRepository(
    ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final constructionLibraryRepositoryProvider =
    Provider<ConstructionLibraryRepository>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      if (repository is ConstructionLibraryRepository) {
        return repository as ConstructionLibraryRepository;
      }
      return DriftProjectRepository(
        ref.watch(appDatabaseProvider),
        logger: ref.watch(appLoggerProvider),
      );
    });

final favoriteMaterialsRepositoryProvider =
    Provider<FavoriteMaterialsRepository>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      if (repository is FavoriteMaterialsRepository) {
        return repository as FavoriteMaterialsRepository;
      }
      return DriftProjectRepository(
        ref.watch(appDatabaseProvider),
        logger: ref.watch(appLoggerProvider),
      );
    });

final openingCatalogRepositoryProvider = Provider<OpeningCatalogRepository>((
  ref,
) {
  final repository = ref.watch(projectRepositoryProvider);
  if (repository is OpeningCatalogRepository) {
    return repository as OpeningCatalogRepository;
  }
  return DriftProjectRepository(
    ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final heatingDeviceCatalogRepositoryProvider =
    Provider<HeatingDeviceCatalogRepository>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      if (repository is HeatingDeviceCatalogRepository) {
        return repository as HeatingDeviceCatalogRepository;
      }
      return DriftProjectRepository(
        ref.watch(appDatabaseProvider),
        logger: ref.watch(appLoggerProvider),
      );
    });

final heatingValveCatalogRepositoryProvider =
    Provider<HeatingValveCatalogRepository>((ref) {
      final repository = ref.watch(projectRepositoryProvider);
      if (repository is HeatingValveCatalogRepository) {
        return repository as HeatingValveCatalogRepository;
      }
      return DriftProjectRepository(
        ref.watch(appDatabaseProvider),
        logger: ref.watch(appLoggerProvider),
      );
    });

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>((
  ref,
) {
  final repository = ref.watch(projectRepositoryProvider);
  if (repository is AppPreferencesRepository) {
    return repository as AppPreferencesRepository;
  }
  return DriftProjectRepository(
    ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final thermalCalculationEngineProvider = Provider<ThermalCalculationEngine>(
  (ref) => const NormativeThermalCalculationEngine(),
);

final projectEditingServiceProvider = Provider<ProjectEditingService>(
  (ref) => const ProjectEditingService(),
);

final heatingDeviceSelectionServiceProvider =
    Provider<HeatingDeviceSelectionService>(
      (ref) => const HeatingDeviceSelectionService(),
    );

final underfloorHeatingCalculationServiceProvider =
    Provider<UnderfloorHeatingCalculationService>(
      (ref) => const UnderfloorHeatingCalculationService(),
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

final heatingEconomicsServiceProvider = Provider<HeatingEconomicsService>(
  (ref) => const NormativeHeatingEconomicsService(),
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
  (ref) => LocalReportFileStore(logger: ref.watch(appLoggerProvider)),
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
    heatingDevices: _mergeHeatingDevices(
      baseCatalog.heatingDevices,
      await ref.watch(heatingDeviceCatalogEntriesProvider.future),
    ),
    heatingValves: _mergeHeatingValves(
      baseCatalog.heatingValves,
      await ref.watch(heatingValveCatalogEntriesProvider.future),
    ),
    openingCatalog: _mergeOpenings(
      baseCatalog.openingCatalog,
      await ref.watch(openingCatalogEntriesProvider.future),
    ),
    datasetVersion: baseCatalog.datasetVersion,
  );
});

final openingCatalogEntriesProvider = FutureProvider<List<OpeningTypeEntry>>((
  ref,
) async {
  return ref.read(openingCatalogRepositoryProvider).listEntries();
});

final heatingDeviceCatalogEntriesProvider =
    FutureProvider<List<HeatingDeviceCatalogEntry>>((ref) async {
      return ref
          .read(heatingDeviceCatalogRepositoryProvider)
          .listHeatingDeviceCatalogEntries();
    });

final heatingDeviceCatalogItemsProvider =
    FutureProvider<List<HeatingDeviceCatalogItem>>((ref) async {
      final catalog = await ref.watch(catalogSnapshotProvider.future);
      final customEntries = await ref.watch(
        heatingDeviceCatalogEntriesProvider.future,
      );
      final customIds = {for (final item in customEntries) item.id};
      return catalog.heatingDevices
          .map(
            (entry) => HeatingDeviceCatalogItem(
              entry: entry,
              source: customIds.contains(entry.id)
                  ? HeatingDeviceCatalogSource.custom
                  : HeatingDeviceCatalogSource.seed,
            ),
          )
          .toList(growable: false);
    });

final heatingValveCatalogEntriesProvider =
    FutureProvider<List<HeatingValveCatalogEntry>>((ref) async {
      return ref
          .read(heatingValveCatalogRepositoryProvider)
          .listHeatingValveCatalogEntries();
    });

final heatingValveCatalogItemsProvider =
    FutureProvider<List<HeatingValveCatalogItem>>((ref) async {
      final catalog = await ref.watch(catalogSnapshotProvider.future);
      final customEntries = await ref.watch(
        heatingValveCatalogEntriesProvider.future,
      );
      final customIds = {for (final item in customEntries) item.id};
      return catalog.heatingValves
          .map(
            (entry) => HeatingValveCatalogItem(
              entry: entry,
              source: customIds.contains(entry.id)
                  ? HeatingValveCatalogSource.custom
                  : HeatingValveCatalogSource.seed,
            ),
          )
          .toList(growable: false);
    });

final favoriteMaterialIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref
      .read(favoriteMaterialsRepositoryProvider)
      .listFavoriteMaterialIds();
});

final constructionPickerSwipeTutorialSeenProvider = FutureProvider<bool>((
  ref,
) async {
  return ref
      .read(appPreferencesRepositoryProvider)
      .getConstructionPickerSwipeTutorialSeen();
});

final materialCatalogEntriesProvider =
    FutureProvider<List<MaterialCatalogEntry>>((ref) async {
      final catalog = await ref.watch(catalogSnapshotProvider.future);
      final baseCatalog = await ref
          .read(catalogRepositoryProvider)
          .loadSnapshot();
      final project = await ref.watch(selectedProjectProvider.future);
      final favorites = await ref.watch(favoriteMaterialIdsProvider.future);
      final customIds = {
        for (final item in project?.customMaterials ?? const <MaterialEntry>[])
          item.id,
      };
      final seededById = {
        for (final item in baseCatalog.materials) item.id: item,
      };
      return catalog.materials
          .map(
            (material) => MaterialCatalogEntry(
              material: material,
              source: customIds.contains(material.id)
                  ? MaterialCatalogSource.custom
                  : MaterialCatalogSource.seed,
              isFavorite: favorites.contains(material.id),
              seedMaterial: customIds.contains(material.id)
                  ? seededById[material.id]
                  : null,
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

List<OpeningTypeEntry> _mergeOpenings(
  List<OpeningTypeEntry> seeded,
  List<OpeningTypeEntry> custom,
) {
  final merged = <String, OpeningTypeEntry>{
    for (final item in seeded) item.id: item,
  };
  for (final item in custom) {
    merged[item.id] = item;
  }
  final result = merged.values.toList(growable: false);
  result.sort((a, b) => a.title.compareTo(b.title));
  return result;
}

List<HeatingDeviceCatalogEntry> _mergeHeatingDevices(
  List<HeatingDeviceCatalogEntry> seeded,
  List<HeatingDeviceCatalogEntry> custom,
) {
  final merged = <String, HeatingDeviceCatalogEntry>{
    for (final item in seeded) item.id: item,
  };
  for (final item in custom) {
    merged[item.id] = item.copyWith(isCustom: true);
  }
  final result = merged.values.toList(growable: false);
  result.sort((a, b) => a.title.compareTo(b.title));
  return result;
}

List<HeatingValveCatalogEntry> _mergeHeatingValves(
  List<HeatingValveCatalogEntry> seeded,
  List<HeatingValveCatalogEntry> custom,
) {
  final merged = <String, HeatingValveCatalogEntry>{
    for (final item in seeded) item.id: item,
  };
  for (final item in custom) {
    merged[item.id] = item.copyWith(isCustom: true);
  }
  final result = merged.values.toList(growable: false);
  result.sort((a, b) => a.title.compareTo(b.title));
  return result;
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
  if (project == null) {
    return null;
  }

  final selectedConstructionId = ref.watch(selectedConstructionIdProvider);
  final selectedElement = await ref.watch(
    selectedEnvelopeElementProvider.future,
  );
  if (selectedElement != null) {
    final sourceId =
        selectedElement.sourceConstructionId ?? selectedElement.construction.id;
    if (selectedConstructionId != sourceId) {
      ref.read(selectedConstructionIdProvider.notifier).select(sourceId);
    }
    return selectedElement.construction;
  }

  if (project.constructions.isEmpty) {
    return null;
  }

  final preferredIds = [selectedConstructionId];

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
      final logger = ref.read(appLoggerProvider);
      return logger.runLoggedAction(
        action: 'Construction calculation',
        category: AppLogCategory.calculation,
        context: {
          'projectId': project.id,
          'constructionId': construction.id,
          'constructionTitle': construction.title,
        },
        operation: () => ref
            .read(thermalCalculationEngineProvider)
            .calculate(
              catalog: catalog,
              project: project,
              construction: construction,
            ),
        successMessage: 'Construction calculation completed',
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
  final logger = ref.read(appLoggerProvider);
  return logger.runLoggedAction(
    action: 'Building heat loss calculation',
    category: AppLogCategory.calculation,
    context: {'projectId': project.id},
    operation: () => ref
        .read(buildingHeatLossServiceProvider)
        .calculate(catalog: catalog, project: project),
    successMessage: 'Building heat loss calculation completed',
  );
});

final heatingEconomicsResultProvider = FutureProvider<HeatingEconomicsResult?>((
  ref,
) async {
  final catalog = await ref.watch(catalogSnapshotProvider.future);
  final project = await ref.watch(selectedProjectProvider.future);
  final buildingHeatLoss = await ref.watch(
    buildingHeatLossResultProvider.future,
  );
  if (project == null || buildingHeatLoss == null) {
    return null;
  }
  final logger = ref.read(appLoggerProvider);
  return logger.runLoggedAction(
    action: 'Heating economics calculation',
    category: AppLogCategory.calculation,
    context: {'projectId': project.id},
    operation: () => ref
        .read(heatingEconomicsServiceProvider)
        .calculate(
          catalog: catalog,
          project: project,
          buildingHeatLoss: buildingHeatLoss,
        ),
    successMessage: 'Heating economics calculation completed',
  );
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
      final logger = ref.read(appLoggerProvider);
      return logger.runLoggedAction(
        action: 'Ground floor calculation',
        category: AppLogCategory.calculation,
        context: {
          'projectId': project.id,
          'calculationId': calculation.id,
          'constructionId': calculation.constructionId,
        },
        operation: () => ref
            .read(groundFloorCalculationServiceProvider)
            .calculate(
              catalog: catalog,
              project: project,
              calculation: calculation,
            ),
        successMessage: 'Ground floor calculation completed',
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
  final logger = ref.read(appLoggerProvider);
  return logger.runLoggedAction(
    action: 'Selected construction calculation',
    category: AppLogCategory.calculation,
    context: {
      'projectId': project.id,
      'constructionId': construction.id,
      'constructionTitle': construction.title,
    },
    operation: () => ref
        .read(thermalCalculationEngineProvider)
        .calculate(
          catalog: catalog,
          project: project,
          construction: construction,
        ),
    successMessage: 'Selected construction calculation completed',
  );
});
