import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/core/models/ground_floor_calculation.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/models/report.dart';
import 'package:smartcalc_mobile/src/core/models/versioning.dart';
import 'package:smartcalc_mobile/src/core/services/interfaces.dart';

const testCatalogSnapshot = CatalogSnapshot(
  climatePoints: [
    ClimatePoint(
      id: 'moscow',
      country: 'Россия',
      region: 'Московская область',
      city: 'Москва',
      designTemperature: -26,
      absoluteMinimumTemperature: -43,
      coldestFiveDayTemperature: -26,
      averageHeatingSeasonTemperature: -2.2,
      heatingPeriodDays: 204,
      gsop: 4528.8,
      moistureSeasons: [
        ClimateSeason(
          id: 'winter',
          label: 'Зимний период',
          durationDays: 120,
          outsideTemperature: -14,
          outsideRelativeHumidity: 0.84,
        ),
        ClimateSeason(
          id: 'transition',
          label: 'Весна и осень',
          durationDays: 140,
          outsideTemperature: 6,
          outsideRelativeHumidity: 0.72,
        ),
        ClimateSeason(
          id: 'summer',
          label: 'Летний период',
          durationDays: 105,
          outsideTemperature: 18,
          outsideRelativeHumidity: 0.66,
        ),
      ],
    ),
    ClimatePoint(
      id: 'novosibirsk',
      country: 'Россия',
      region: 'Новосибирская область',
      city: 'Новосибирск',
      designTemperature: -37,
      absoluteMinimumTemperature: -50,
      coldestFiveDayTemperature: -37,
      averageHeatingSeasonTemperature: -7.9,
      heatingPeriodDays: 222,
      gsop: 6193.8,
      moistureSeasons: [
        ClimateSeason(
          id: 'winter',
          label: 'Зимний период',
          durationDays: 150,
          outsideTemperature: -22,
          outsideRelativeHumidity: 0.82,
        ),
        ClimateSeason(
          id: 'transition',
          label: 'Весна и осень',
          durationDays: 110,
          outsideTemperature: 4,
          outsideRelativeHumidity: 0.68,
        ),
        ClimateSeason(
          id: 'summer',
          label: 'Летний период',
          durationDays: 105,
          outsideTemperature: 17,
          outsideRelativeHumidity: 0.62,
        ),
      ],
    ),
  ],
  materials: [
    MaterialEntry(
      id: 'gypsum_plaster',
      name: 'Гипсовая штукатурка',
      category: 'Отделка',
      thermalConductivity: 0.35,
      vaporPermeability: 0.11,
    ),
    MaterialEntry(
      id: 'aac_d500',
      name: 'Газобетон D500',
      category: 'Блоки',
      thermalConductivity: 0.14,
      vaporPermeability: 0.23,
    ),
    MaterialEntry(
      id: 'mineral_wool',
      name: 'Минеральная вата',
      category: 'Утеплитель',
      thermalConductivity: 0.04,
      vaporPermeability: 0.30,
    ),
    MaterialEntry(
      id: 'pine_timber',
      name: 'Сосновый брус',
      category: 'Каркас',
      thermalConductivity: 0.15,
      vaporPermeability: 0.06,
    ),
    MaterialEntry(
      id: 'facing_brick',
      name: 'Кирпич облицовочный',
      category: 'Кладка',
      thermalConductivity: 0.81,
      vaporPermeability: 0.11,
    ),
  ],
  constructionTemplates: [
    Construction(
      id: 'template-wall',
      title: 'Шаблон стены',
      elementKind: ConstructionElementKind.wall,
      layers: [
        ConstructionLayer(
          id: 'plaster',
          materialId: 'gypsum_plaster',
          kind: LayerKind.solid,
          thicknessMm: 20,
        ),
        ConstructionLayer(
          id: 'aac',
          materialId: 'aac_d500',
          kind: LayerKind.masonry,
          thicknessMm: 300,
        ),
      ],
    ),
  ],
  norms: [
    NormReference(
      id: 'sp_50',
      code: 'СП 50.13330.2012',
      clause: 'Тепловая защита зданий',
      title: 'Базовый набор требований по теплозащите и влагорежиму',
    ),
    NormReference(
      id: 'sp_131',
      code: 'СП 131.13330.2020',
      clause: 'Строительная климатология',
      title: 'Климатические параметры для расчётов',
    ),
    NormReference(
      id: 'gost_54851',
      code: 'ГОСТ Р 54851-2011',
      clause: 'Ограждающие конструкции',
      title: 'Приведённое сопротивление теплопередаче',
    ),
  ],
  moistureRules: MoistureRuleSet(
    roomConditions: [
      MoistureRoomCondition(
        roomPresetId: 'livingRoom',
        insideTemperature: 20,
        insideRelativeHumidity: 0.55,
        minimumRecommendedVaporResistance: 1.8,
      ),
      MoistureRoomCondition(
        roomPresetId: 'attic',
        insideTemperature: 18,
        insideRelativeHumidity: 0.5,
        minimumRecommendedVaporResistance: 1.4,
      ),
      MoistureRoomCondition(
        roomPresetId: 'basement',
        insideTemperature: 16,
        insideRelativeHumidity: 0.6,
        minimumRecommendedVaporResistance: 1.2,
      ),
    ],
    defaultMaximumOutwardDryingRatio: 1.0,
    coldClimateMaximumOutwardDryingRatio: 0.8,
    coldClimateDesignTemperatureThreshold: -30.0,
    seasonalDryingRecoveryFactor: 0.65,
    maximumSeasonalAccumulationKgPerSquareMeter: 0.2,
  ),
  roomKindConditions: [
    RoomKindCondition(
      roomKindId: 'livingRoom',
      insideTemperature: 20,
      insideRelativeHumidity: 0.55,
    ),
    RoomKindCondition(
      roomKindId: 'bedroom',
      insideTemperature: 18,
      insideRelativeHumidity: 0.5,
    ),
    RoomKindCondition(
      roomKindId: 'kitchen',
      insideTemperature: 20,
      insideRelativeHumidity: 0.6,
    ),
    RoomKindCondition(
      roomKindId: 'bathroom',
      insideTemperature: 24,
      insideRelativeHumidity: 0.65,
    ),
    RoomKindCondition(
      roomKindId: 'hall',
      insideTemperature: 16,
      insideRelativeHumidity: 0.45,
    ),
    RoomKindCondition(
      roomKindId: 'boilerRoom',
      insideTemperature: 18,
      insideRelativeHumidity: 0.45,
    ),
    RoomKindCondition(
      roomKindId: 'other',
      insideTemperature: 18,
      insideRelativeHumidity: 0.5,
    ),
  ],
  heatingDevices: [
    HeatingDeviceCatalogEntry(
      id: 'rad-panel-22-500x1000',
      kind: 'radiator',
      title: 'Панельный радиатор 22, 500x1000',
      ratedPowerWatts: 1700,
    ),
    HeatingDeviceCatalogEntry(
      id: 'convector-floor-1500',
      kind: 'convector',
      title: 'Конвектор напольный 1500 Вт',
      ratedPowerWatts: 1500,
    ),
    HeatingDeviceCatalogEntry(
      id: 'ufh-loop-12m2',
      kind: 'underfloorLoop',
      title: 'Контур теплого пола до 12 м²',
      ratedPowerWatts: 1200,
    ),
  ],
  openingCatalog: [
    OpeningTypeEntry(
      id: 'window-basic',
      kind: OpeningKind.window,
      title: 'Окно ПВХ',
      subcategory: 'ПВХ окна',
      manufacturer: 'REHAU',
      defaultWidthMeters: 1.2,
      defaultHeightMeters: 1.4,
      heatTransferCoefficient: 1.0,
      sourceUrl:
          'https://window.rehau.com/uk-en/rehau-specifier-guide-download',
      sourceLabel: 'REHAU Specifier Guide',
      sourceCheckedAt: '2026-04-13',
    ),
    OpeningTypeEntry(
      id: 'door-basic',
      kind: OpeningKind.door,
      title: 'Стальная входная дверь',
      subcategory: 'Стальные входные двери',
      manufacturer: 'Hormann',
      defaultWidthMeters: 0.98,
      defaultHeightMeters: 2.05,
      heatTransferCoefficient: 1.4,
      sourceUrl:
          'https://www.hormann.co.uk/media-centre/preview/310523en/85828_Thermo65_46_23_12_EN_UK.pdf?20240416141953=',
      sourceLabel: 'Hormann Thermo65 / Thermo46',
      sourceCheckedAt: '2026-04-13',
    ),
  ],
  datasetVersion: 'test-moisture-v2',
);

Construction buildWallConstruction({bool insulationEnabled = true}) {
  return Construction(
    id: 'wall',
    title: 'Наружная стена',
    elementKind: ConstructionElementKind.wall,
    layers: [
      const ConstructionLayer(
        id: 'plaster',
        materialId: 'gypsum_plaster',
        kind: LayerKind.solid,
        thicknessMm: 20,
      ),
      const ConstructionLayer(
        id: 'aac',
        materialId: 'aac_d500',
        kind: LayerKind.masonry,
        thicknessMm: 375,
      ),
      ConstructionLayer(
        id: 'wool',
        materialId: 'mineral_wool',
        kind: LayerKind.frame,
        thicknessMm: 100,
        enabled: insulationEnabled,
      ),
      const ConstructionLayer(
        id: 'brick',
        materialId: 'facing_brick',
        kind: LayerKind.masonry,
        thicknessMm: 120,
      ),
    ],
  );
}

RoomLayoutRect buildRoomLayout({
  double xMeters = 0,
  double yMeters = 0,
  double widthMeters = defaultRoomLayoutWidthMeters,
  double heightMeters = defaultRoomLayoutHeightMeters,
}) {
  return RoomLayoutRect(
    xMeters: xMeters,
    yMeters: yMeters,
    widthMeters: widthMeters,
    heightMeters: heightMeters,
  );
}

EnvelopeWallPlacement buildWallPlacement({
  RoomSide side = RoomSide.top,
  double offsetMeters = 0,
  double lengthMeters = defaultRoomLayoutWidthMeters,
}) {
  return EnvelopeWallPlacement(
    side: side,
    offsetMeters: offsetMeters,
    lengthMeters: lengthMeters,
  );
}

Room buildRoom({
  String id = defaultRoomId,
  String title = 'Основное помещение',
  RoomKind kind = RoomKind.livingRoom,
  double heightMeters = defaultRoomHeightMeters,
  double comfortTemperatureC = defaultRoomComfortTemperatureC,
  double ventilationSupplyM3h = defaultRoomVentilationSupplyM3h,
  RoomLayoutRect? layout,
}) {
  return Room(
    id: id,
    title: title,
    kind: kind,
    heightMeters: heightMeters,
    comfortTemperatureC: comfortTemperatureC,
    ventilationSupplyM3h: ventilationSupplyM3h,
    layout: layout ?? buildRoomLayout(),
  );
}

HouseEnvelopeElement buildEnvelopeElement({
  String id = 'element-wall',
  String roomId = defaultRoomId,
  String title = 'Наружная стена',
  Construction? construction,
  ConstructionElementKind? elementKind,
  double areaSquareMeters = defaultHouseElementAreaSquareMeters,
  WallOrientation? wallOrientation,
  EnvelopeWallPlacement? wallPlacement,
  String? sourceConstructionId,
  String? sourceConstructionTitle,
}) {
  final effectiveConstruction =
      construction ??
      buildWallConstruction().copyWith(
        elementKind: elementKind ?? ConstructionElementKind.wall,
      );
  return HouseEnvelopeElement(
    id: id,
    roomId: roomId,
    title: title,
    elementKind: elementKind ?? effectiveConstruction.elementKind,
    areaSquareMeters: areaSquareMeters,
    construction: effectiveConstruction,
    sourceConstructionId: sourceConstructionId ?? effectiveConstruction.id,
    sourceConstructionTitle:
        sourceConstructionTitle ?? effectiveConstruction.title,
    wallOrientation:
        wallOrientation ??
        ((elementKind ?? effectiveConstruction.elementKind) ==
                ConstructionElementKind.wall
            ? WallOrientation.north
            : null),
    wallPlacement: wallPlacement,
  );
}

EnvelopeOpening buildOpening({
  String id = 'opening-main',
  String elementId = 'element-main',
  String title = 'Окно',
  OpeningKind kind = OpeningKind.window,
  double widthMeters = 1.2,
  double heightMeters = 1.4,
  double? heatTransferCoefficient,
  String? catalogTypeId,
}) {
  return EnvelopeOpening(
    id: id,
    elementId: elementId,
    title: title,
    kind: kind,
    widthMeters: widthMeters,
    heightMeters: heightMeters,
    heatTransferCoefficient:
        heatTransferCoefficient ?? kind.defaultHeatTransferCoefficient,
    catalogTypeId: catalogTypeId,
  );
}

HouseModel buildHouseModel({
  List<Construction>? constructions,
  List<EnvelopeOpening>? openings,
  List<HeatingDevice>? heatingDevices,
}) {
  final effectiveConstructions = constructions ?? [buildWallConstruction()];
  return HouseModel.bootstrapFromConstructions(effectiveConstructions).copyWith(
    openings: openings ?? const [],
    heatingDevices: heatingDevices ?? const [],
  );
}

HeatingDevice buildHeatingDevice({
  String id = 'device-main',
  String roomId = defaultRoomId,
  String title = 'Радиатор',
  HeatingDeviceKind kind = HeatingDeviceKind.radiator,
  double ratedPowerWatts = 1500,
  String? catalogItemId = 'rad-panel-22-500x1000',
  double? nominalPowerWatts,
  double? designFlowTempC,
  double? designReturnTempC,
  double? designRoomTempC,
  int? sectionCount,
  String? notes,
}) {
  return HeatingDevice(
    id: id,
    roomId: roomId,
    title: title,
    kind: kind,
    ratedPowerWatts: ratedPowerWatts,
    catalogItemId: catalogItemId,
    nominalPowerWatts: nominalPowerWatts,
    designFlowTempC: designFlowTempC,
    designReturnTempC: designReturnTempC,
    designRoomTempC: designRoomTempC,
    sectionCount: sectionCount,
    notes: notes,
  );
}

Project buildTestProject({
  String climatePointId = 'moscow',
  RoomPreset roomPreset = RoomPreset.livingRoom,
  Construction? construction,
  List<Construction>? constructions,
  HouseModel? houseModel,
  List<GroundFloorCalculation>? groundFloorCalculations,
  bool showBuildingStepRoomsOnboarding = true,
  String datasetVersion = currentDatasetVersion,
  String? migratedFromDatasetVersion,
}) {
  final effectiveConstructions =
      constructions ?? [construction ?? buildWallConstruction()];
  return Project(
    id: 'demo',
    name: 'Demo project',
    climatePointId: climatePointId,
    roomPreset: roomPreset,
    houseModel:
        houseModel ?? buildHouseModel(constructions: effectiveConstructions),
    groundFloorCalculations: groundFloorCalculations ?? const [],
    showBuildingStepRoomsOnboarding: showBuildingStepRoomsOnboarding,
    datasetVersion: datasetVersion,
    migratedFromDatasetVersion: migratedFromDatasetVersion,
    constructions: effectiveConstructions,
  );
}

class FakeCatalogRepository implements CatalogRepository {
  @override
  Future<CatalogSnapshot> loadSnapshot() async => testCatalogSnapshot;
}

class FakeProjectRepository
    implements
        ProjectRepository,
        ConstructionLibraryRepository,
        ObjectRepository,
        FavoriteMaterialsRepository,
        OpeningCatalogRepository,
        HeatingDeviceCatalogRepository,
        AppPreferencesRepository {
  FakeProjectRepository({List<Project>? projects})
    : _projects = projects ?? [buildTestProject()],
      _library = {
        for (final project in (projects ?? [buildTestProject()]))
          for (final construction in project.constructions)
            construction.id: construction,
      },
      _objects = {
        for (final project in (projects ?? [buildTestProject()]))
          'object-${project.id}': DesignObject(
            id: 'object-${project.id}',
            title: project.name,
            address: '',
            description: '',
            customerPhone: '',
            climatePointId: project.climatePointId,
            projectId: project.id,
            updatedAtEpochMs: 0,
          ),
      },
      _hasSeededDemoProject = (projects ?? [buildTestProject()]).isNotEmpty,
      _hasSeededObjects = (projects ?? [buildTestProject()]).isNotEmpty {
    for (final entry in testCatalogSnapshot.openingCatalog) {
      _openingCatalog[entry.id] = entry;
    }
    for (final entry in testCatalogSnapshot.heatingDevices) {
      _heatingDeviceCatalog[entry.id] = entry;
    }
  }

  final List<Project> _projects;
  final Map<String, Construction> _library;
  final Map<String, DesignObject> _objects;
  final Set<String> _favoriteMaterialIds = <String>{};
  final Map<String, OpeningTypeEntry> _openingCatalog =
      <String, OpeningTypeEntry>{};
  final Map<String, HeatingDeviceCatalogEntry> _heatingDeviceCatalog =
      <String, HeatingDeviceCatalogEntry>{};
  bool _constructionPickerSwipeTutorialSeen = false;
  bool _hasSeededDemoProject;
  bool _hasSeededObjects;

  @override
  Future<List<Project>> listProjects() async => List.unmodifiable(_projects);

  @override
  Future<Project?> getProject(String id) async {
    for (final project in _projects) {
      if (project.id == id) {
        return project;
      }
    }
    return null;
  }

  @override
  Future<void> saveProject(Project project) async {
    for (final construction in project.constructions) {
      _library[construction.id] = construction;
    }
    final index = _projects.indexWhere((item) => item.id == project.id);
    if (index == -1) {
      _projects.add(project);
      return;
    }
    _projects[index] = project;
  }

  @override
  Future<void> deleteProject(String id) async {
    _projects.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> seedDemoProjectIfEmpty() async {
    if (_hasSeededDemoProject) {
      return;
    }
    if (_projects.isEmpty) {
      final project = buildTestProject();
      _projects.add(project);
      for (final construction in project.constructions) {
        _library[construction.id] = construction;
      }
    }
    _hasSeededDemoProject = true;
  }

  @override
  Future<List<Construction>> listConstructions() async {
    return List.unmodifiable(_library.values);
  }

  @override
  Future<Construction?> getConstruction(String id) async => _library[id];

  @override
  Future<void> saveConstruction(Construction construction) async {
    _library[construction.id] = construction;
  }

  @override
  Future<void> deleteConstruction(String id) async {
    _library.remove(id);
  }

  @override
  Future<List<DesignObject>> listObjects() async {
    return List.unmodifiable(_objects.values);
  }

  @override
  Future<DesignObject?> getObject(String id) async => _objects[id];

  @override
  Future<void> saveObject(DesignObject object) async {
    _objects[object.id] = object;
  }

  @override
  Future<void> deleteObject(String id) async {
    _objects.remove(id);
  }

  @override
  Future<void> seedObjectsIfEmpty() async {
    if (_hasSeededObjects) {
      return;
    }
    if (_objects.isNotEmpty) {
      _hasSeededObjects = true;
      return;
    }
    for (final project in _projects) {
      _objects['object-${project.id}'] = DesignObject(
        id: 'object-${project.id}',
        title: project.name,
        address: '',
        description: '',
        customerPhone: '',
        climatePointId: project.climatePointId,
        projectId: project.id,
        updatedAtEpochMs: 0,
      );
    }
    _hasSeededObjects = true;
  }

  @override
  Future<Set<String>> listFavoriteMaterialIds() async {
    return Set<String>.from(_favoriteMaterialIds);
  }

  @override
  Future<void> saveFavoriteMaterialIds(Set<String> ids) async {
    _favoriteMaterialIds
      ..clear()
      ..addAll(ids);
  }

  @override
  Future<List<OpeningTypeEntry>> listEntries() async =>
      List.unmodifiable(_openingCatalog.values);

  @override
  Future<void> saveEntry(OpeningTypeEntry entry) async {
    _openingCatalog[entry.id] = entry;
  }

  @override
  Future<void> deleteEntry(String id) async {
    _openingCatalog.remove(id);
  }

  @override
  Future<List<HeatingDeviceCatalogEntry>>
  listHeatingDeviceCatalogEntries() async =>
      List.unmodifiable(_heatingDeviceCatalog.values);

  @override
  Future<void> saveHeatingDeviceCatalogEntry(
    HeatingDeviceCatalogEntry entry,
  ) async {
    _heatingDeviceCatalog[entry.id] = entry;
  }

  @override
  Future<void> deleteHeatingDeviceCatalogEntry(String id) async {
    _heatingDeviceCatalog.remove(id);
  }

  @override
  Future<bool> getConstructionPickerSwipeTutorialSeen() async {
    return _constructionPickerSwipeTutorialSeen;
  }

  @override
  Future<void> setConstructionPickerSwipeTutorialSeen(bool seen) async {
    _constructionPickerSwipeTutorialSeen = seen;
  }
}

class FakeReportService implements ReportService {
  FakeReportService({
    this.document = const ReportDocument(
      fileName: 'thermocalc_demo.pdf',
      bytes: [1, 2, 3, 4],
    ),
    this.error,
  });

  final ReportDocument document;
  final Object? error;

  @override
  Future<ReportDocument> buildReport({required ReportContent content}) async {
    if (error != null) {
      throw error!;
    }
    return document;
  }
}

class FakeReportFileStore implements ReportFileStore {
  FakeReportFileStore({
    this.savedReport = const SavedReport(
      fileName: 'thermocalc_demo.pdf',
      filePath: '/tmp/thermocalc_demo.pdf',
    ),
    this.error,
  });

  final SavedReport savedReport;
  final Object? error;

  @override
  Future<SavedReport> saveReport(ReportDocument document) async {
    if (error != null) {
      throw error!;
    }
    return savedReport;
  }
}
