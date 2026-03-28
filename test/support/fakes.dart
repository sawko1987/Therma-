import 'package:smartcalc_mobile/src/core/models/catalog.dart';
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
      designTemperature: -23,
      heatingPeriodDays: 202,
      gsop: 4383.4,
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
      heatingPeriodDays: 230,
      gsop: 6205.0,
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
  RoomLayoutRect? layout,
}) {
  return Room(
    id: id,
    title: title,
    kind: kind,
    heightMeters: heightMeters,
    layout: layout ?? buildRoomLayout(),
  );
}

HouseModel buildHouseModel({
  List<Construction>? constructions,
  List<EnvelopeOpening>? openings,
  List<HeatingDevice>? heatingDevices,
}) {
  final effectiveConstructions = constructions ?? [buildWallConstruction()];
  return HouseModel.bootstrapFromConstructions(
    effectiveConstructions,
  ).copyWith(
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
  String? notes,
}) {
  return HeatingDevice(
    id: id,
    roomId: roomId,
    title: title,
    kind: kind,
    ratedPowerWatts: ratedPowerWatts,
    catalogItemId: catalogItemId,
    notes: notes,
  );
}

Project buildTestProject({
  String climatePointId = 'moscow',
  RoomPreset roomPreset = RoomPreset.livingRoom,
  Construction? construction,
  HouseModel? houseModel,
  String datasetVersion = currentDatasetVersion,
  String? migratedFromDatasetVersion,
}) {
  final effectiveConstruction = construction ?? buildWallConstruction();
  return Project(
    id: 'demo',
    name: 'Demo project',
    climatePointId: climatePointId,
    roomPreset: roomPreset,
    houseModel:
        houseModel ?? buildHouseModel(constructions: [effectiveConstruction]),
    datasetVersion: datasetVersion,
    migratedFromDatasetVersion: migratedFromDatasetVersion,
    constructions: [effectiveConstruction],
  );
}

class FakeCatalogRepository implements CatalogRepository {
  @override
  Future<CatalogSnapshot> loadSnapshot() async => testCatalogSnapshot;
}

class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository({List<Project>? projects})
    : _projects = projects ?? [buildTestProject()];

  final List<Project> _projects;

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
    final index = _projects.indexWhere((item) => item.id == project.id);
    if (index == -1) {
      _projects.add(project);
      return;
    }
    _projects[index] = project;
  }

  @override
  Future<void> seedDemoProjectIfEmpty() async {
    if (_projects.isEmpty) {
      _projects.add(buildTestProject());
    }
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
