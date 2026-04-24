import 'project.dart';

class ClimateSeason {
  const ClimateSeason({
    required this.id,
    required this.label,
    required this.durationDays,
    required this.outsideTemperature,
    required this.outsideRelativeHumidity,
  });

  factory ClimateSeason.fromJson(Map<String, dynamic> json) => ClimateSeason(
    id: json['id'] as String,
    label: json['label'] as String,
    durationDays: json['durationDays'] as int,
    outsideTemperature: (json['outsideTemperature'] as num).toDouble(),
    outsideRelativeHumidity: (json['outsideRelativeHumidity'] as num)
        .toDouble(),
  );

  final String id;
  final String label;
  final int durationDays;
  final double outsideTemperature;
  final double outsideRelativeHumidity;
}

class ClimatePoint {
  const ClimatePoint({
    required this.id,
    required this.country,
    required this.region,
    required this.city,
    required this.designTemperature,
    required this.absoluteMinimumTemperature,
    required this.coldestFiveDayTemperature,
    required this.averageHeatingSeasonTemperature,
    required this.heatingPeriodDays,
    required this.gsop,
    required this.moistureSeasons,
  });

  factory ClimatePoint.fromJson(Map<String, dynamic> json) => ClimatePoint(
    id: json['id'] as String,
    country: json['country'] as String,
    region: json['region'] as String,
    city: json['city'] as String,
    designTemperature: (json['designTemperature'] as num).toDouble(),
    absoluteMinimumTemperature:
        (json['absoluteMinimumTemperature'] as num?)?.toDouble() ??
        (json['winterMinimumTemperature'] as num?)?.toDouble() ??
        (json['designTemperature'] as num).toDouble(),
    coldestFiveDayTemperature:
        (json['coldestFiveDayTemperature'] as num?)?.toDouble() ??
        (json['designTemperature'] as num).toDouble(),
    averageHeatingSeasonTemperature:
        (json['averageHeatingSeasonTemperature'] as num?)?.toDouble() ??
        _inferAverageHeatingSeasonTemperature(
          heatingPeriodDays: json['heatingPeriodDays'] as int,
          gsop: (json['gsop'] as num).toDouble(),
        ),
    heatingPeriodDays: json['heatingPeriodDays'] as int,
    gsop: (json['gsop'] as num).toDouble(),
    moistureSeasons: (json['moistureSeasons'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ClimateSeason.fromJson)
        .toList(growable: false),
  );

  final String id;
  final String country;
  final String region;
  final String city;
  final double designTemperature;
  final double absoluteMinimumTemperature;
  final double coldestFiveDayTemperature;
  final double averageHeatingSeasonTemperature;
  final int heatingPeriodDays;
  final double gsop;
  final List<ClimateSeason> moistureSeasons;

  String get displayName => '$city, $region';
}

double _inferAverageHeatingSeasonTemperature({
  required int heatingPeriodDays,
  required double gsop,
}) {
  if (heatingPeriodDays <= 0) {
    return 0;
  }
  return 20 - gsop / heatingPeriodDays;
}

class MaterialEntry {
  const MaterialEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.thermalConductivity,
    required this.vaporPermeability,
    this.aliases = const [],
    this.tags = const [],
    this.applications = const [],
    this.manufacturer,
    this.subcategory,
    this.densityKgM3,
    this.notes,
  });

  factory MaterialEntry.fromJson(Map<String, dynamic> json) => MaterialEntry(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    thermalConductivity: (json['thermalConductivity'] as num).toDouble(),
    vaporPermeability: (json['vaporPermeability'] as num).toDouble(),
    aliases: ((json['aliases'] as List<dynamic>?) ?? const [])
        .map((item) => item as String)
        .toList(growable: false),
    tags: ((json['tags'] as List<dynamic>?) ?? const [])
        .map((item) => item as String)
        .toList(growable: false),
    applications: ((json['applications'] as List<dynamic>?) ?? const [])
        .map((item) => parseMaterialApplication(item as String))
        .toList(growable: false),
    manufacturer: json['manufacturer'] as String?,
    subcategory: json['subcategory'] as String?,
    densityKgM3: (json['densityKgM3'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
  );

  final String id;
  final String name;
  final String category;
  final double thermalConductivity;
  final double vaporPermeability;
  final List<String> aliases;
  final List<String> tags;
  final List<MaterialApplication> applications;
  final String? manufacturer;
  final String? subcategory;
  final double? densityKgM3;
  final String? notes;

  MaterialEntry copyWith({
    String? id,
    String? name,
    String? category,
    double? thermalConductivity,
    double? vaporPermeability,
    List<String>? aliases,
    List<String>? tags,
    List<MaterialApplication>? applications,
    String? manufacturer,
    String? subcategory,
    double? densityKgM3,
    String? notes,
  }) {
    return MaterialEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      thermalConductivity: thermalConductivity ?? this.thermalConductivity,
      vaporPermeability: vaporPermeability ?? this.vaporPermeability,
      aliases: aliases ?? this.aliases,
      tags: tags ?? this.tags,
      applications: applications ?? this.applications,
      manufacturer: manufacturer ?? this.manufacturer,
      subcategory: subcategory ?? this.subcategory,
      densityKgM3: densityKgM3 ?? this.densityKgM3,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'thermalConductivity': thermalConductivity,
    'vaporPermeability': vaporPermeability,
    'aliases': aliases,
    'tags': tags,
    'applications': applications
        .map((item) => item.storageKey)
        .toList(growable: false),
    'manufacturer': manufacturer,
    'subcategory': subcategory,
    'densityKgM3': densityKgM3,
    'notes': notes,
  };

  bool get isCustom => id.startsWith('custom-material-');
}

enum MaterialCatalogSource { seed, custom }

enum MaterialApplication {
  wall,
  floor,
  roof,
  ceiling,
  partition,
  facade,
  foundation,
}

MaterialApplication parseMaterialApplication(String value) {
  return MaterialApplication.values.firstWhere(
    (item) => item.storageKey == value,
    orElse: () => throw ArgumentError.value(
      value,
      'value',
      'Unknown material application',
    ),
  );
}

extension MaterialApplicationX on MaterialApplication {
  String get storageKey => switch (this) {
    MaterialApplication.wall => 'wall',
    MaterialApplication.floor => 'floor',
    MaterialApplication.roof => 'roof',
    MaterialApplication.ceiling => 'ceiling',
    MaterialApplication.partition => 'partition',
    MaterialApplication.facade => 'facade',
    MaterialApplication.foundation => 'foundation',
  };

  String get label => switch (this) {
    MaterialApplication.wall => 'Стены',
    MaterialApplication.floor => 'Полы',
    MaterialApplication.roof => 'Кровля',
    MaterialApplication.ceiling => 'Потолки',
    MaterialApplication.partition => 'Перегородки',
    MaterialApplication.facade => 'Фасады',
    MaterialApplication.foundation => 'Фундаменты',
  };
}

enum MaterialSortOption { name, category, lambdaAscending, lambdaDescending }

class MaterialCatalogEntry {
  const MaterialCatalogEntry({
    required this.material,
    required this.source,
    required this.isFavorite,
    this.seedMaterial,
  });

  final MaterialEntry material;
  final MaterialCatalogSource source;
  final bool isFavorite;
  final MaterialEntry? seedMaterial;

  bool get isCustom => source == MaterialCatalogSource.custom;
  bool get isSeedOverride => seedMaterial != null && isCustom;
}

class NormReference {
  const NormReference({
    required this.id,
    required this.code,
    required this.clause,
    required this.title,
  });

  factory NormReference.fromJson(Map<String, dynamic> json) => NormReference(
    id: json['id'] as String,
    code: json['code'] as String,
    clause: json['clause'] as String,
    title: json['title'] as String,
  );

  final String id;
  final String code;
  final String clause;
  final String title;
}

class MoistureRoomCondition {
  const MoistureRoomCondition({
    required this.roomPresetId,
    required this.insideTemperature,
    required this.insideRelativeHumidity,
    required this.minimumRecommendedVaporResistance,
  });

  factory MoistureRoomCondition.fromJson(Map<String, dynamic> json) =>
      MoistureRoomCondition(
        roomPresetId: json['roomPresetId'] as String,
        insideTemperature: (json['insideTemperature'] as num).toDouble(),
        insideRelativeHumidity: (json['insideRelativeHumidity'] as num)
            .toDouble(),
        minimumRecommendedVaporResistance:
            (json['minimumRecommendedVaporResistance'] as num).toDouble(),
      );

  final String roomPresetId;
  final double insideTemperature;
  final double insideRelativeHumidity;
  final double minimumRecommendedVaporResistance;
}

class MoistureRuleSet {
  const MoistureRuleSet({
    required this.roomConditions,
    required this.defaultMaximumOutwardDryingRatio,
    required this.coldClimateMaximumOutwardDryingRatio,
    required this.coldClimateDesignTemperatureThreshold,
    required this.seasonalDryingRecoveryFactor,
    required this.maximumSeasonalAccumulationKgPerSquareMeter,
  });

  factory MoistureRuleSet.fromJson(Map<String, dynamic> json) =>
      MoistureRuleSet(
        roomConditions: (json['roomConditions'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(MoistureRoomCondition.fromJson)
            .toList(growable: false),
        defaultMaximumOutwardDryingRatio:
            (json['defaultMaximumOutwardDryingRatio'] as num).toDouble(),
        coldClimateMaximumOutwardDryingRatio:
            (json['coldClimateMaximumOutwardDryingRatio'] as num).toDouble(),
        coldClimateDesignTemperatureThreshold:
            (json['coldClimateDesignTemperatureThreshold'] as num).toDouble(),
        seasonalDryingRecoveryFactor:
            (json['seasonalDryingRecoveryFactor'] as num).toDouble(),
        maximumSeasonalAccumulationKgPerSquareMeter:
            (json['maximumSeasonalAccumulationKgPerSquareMeter'] as num)
                .toDouble(),
      );

  final List<MoistureRoomCondition> roomConditions;
  final double defaultMaximumOutwardDryingRatio;
  final double coldClimateMaximumOutwardDryingRatio;
  final double coldClimateDesignTemperatureThreshold;
  final double seasonalDryingRecoveryFactor;
  final double maximumSeasonalAccumulationKgPerSquareMeter;
}

class RoomKindCondition {
  const RoomKindCondition({
    required this.roomKindId,
    required this.insideTemperature,
    this.insideRelativeHumidity,
  });

  factory RoomKindCondition.fromJson(Map<String, dynamic> json) =>
      RoomKindCondition(
        roomKindId: json['roomKindId'] as String,
        insideTemperature: (json['insideTemperature'] as num).toDouble(),
        insideRelativeHumidity: (json['insideRelativeHumidity'] as num?)
            ?.toDouble(),
      );

  final String roomKindId;
  final double insideTemperature;
  final double? insideRelativeHumidity;
}

class HeatingDeviceCatalogEntry {
  const HeatingDeviceCatalogEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.ratedPowerWatts,
    this.manufacturer,
    this.series,
    this.model,
    this.sectionCount,
    this.widthMm,
    this.heightMm,
    this.depthMm,
    this.waterVolumePerSection,
    this.panelType,
    this.connection,
    this.workingPressureBar,
    this.testPressureBar,
    this.designFlowTempC = 75,
    this.designReturnTempC = 65,
    this.roomTempC = 20,
    this.heatOutputExponent,
    this.sourceUrl,
    this.sourceLabel,
    this.sourceCheckedAt,
    this.isCustom = false,
  });

  factory HeatingDeviceCatalogEntry.fromJson(
    Map<String, dynamic> json,
  ) => HeatingDeviceCatalogEntry(
    id: json['id'] as String,
    kind: json['kind'] as String,
    title: json['title'] as String,
    ratedPowerWatts: (json['ratedPowerWatts'] as num).toDouble(),
    manufacturer: json['manufacturer'] as String?,
    series: json['series'] as String?,
    model: json['model'] as String?,
    sectionCount: (json['sectionCount'] as num?)?.toInt(),
    widthMm: (json['widthMm'] as num?)?.toDouble(),
    heightMm: (json['heightMm'] as num?)?.toDouble(),
    depthMm: (json['depthMm'] as num?)?.toDouble(),
    waterVolumePerSection: (json['waterVolumePerSection'] as num?)?.toDouble(),
    panelType: json['panelType'] as String?,
    connection: json['connection'] as String?,
    workingPressureBar: (json['workingPressureBar'] as num?)?.toDouble(),
    testPressureBar: (json['testPressureBar'] as num?)?.toDouble(),
    designFlowTempC: (json['designFlowTempC'] as num?)?.toDouble() ?? 75,
    designReturnTempC: (json['designReturnTempC'] as num?)?.toDouble() ?? 65,
    roomTempC: (json['roomTempC'] as num?)?.toDouble() ?? 20,
    heatOutputExponent: (json['heatOutputExponent'] as num?)?.toDouble(),
    sourceUrl: json['sourceUrl'] as String?,
    sourceLabel: json['sourceLabel'] as String?,
    sourceCheckedAt: json['sourceCheckedAt'] as String?,
    isCustom: json['isCustom'] as bool? ?? false,
  );

  final String id;
  final String kind;
  final String title;
  final double ratedPowerWatts;
  final String? manufacturer;
  final String? series;
  final String? model;
  final int? sectionCount;
  final double? widthMm;
  final double? heightMm;
  final double? depthMm;
  final double? waterVolumePerSection;
  final String? panelType;
  final String? connection;
  final double? workingPressureBar;
  final double? testPressureBar;
  final double designFlowTempC;
  final double designReturnTempC;
  final double roomTempC;
  final double? heatOutputExponent;
  final String? sourceUrl;
  final String? sourceLabel;
  final String? sourceCheckedAt;
  final bool isCustom;

  double get nominalDeltaT =>
      (designFlowTempC + designReturnTempC) / 2 - roomTempC;

  bool get isSectional => sectionCount != null && sectionCount! > 0;

  HeatingDeviceCatalogEntry copyWith({
    String? id,
    String? kind,
    String? title,
    double? ratedPowerWatts,
    String? manufacturer,
    String? series,
    String? model,
    int? sectionCount,
    double? widthMm,
    double? heightMm,
    double? depthMm,
    double? waterVolumePerSection,
    String? panelType,
    String? connection,
    double? workingPressureBar,
    double? testPressureBar,
    double? designFlowTempC,
    double? designReturnTempC,
    double? roomTempC,
    double? heatOutputExponent,
    String? sourceUrl,
    String? sourceLabel,
    String? sourceCheckedAt,
    bool? isCustom,
    bool clearManufacturer = false,
    bool clearSeries = false,
    bool clearModel = false,
    bool clearSectionCount = false,
    bool clearWidthMm = false,
    bool clearHeightMm = false,
    bool clearDepthMm = false,
    bool clearWaterVolumePerSection = false,
    bool clearPanelType = false,
    bool clearConnection = false,
    bool clearWorkingPressureBar = false,
    bool clearTestPressureBar = false,
    bool clearHeatOutputExponent = false,
    bool clearSourceUrl = false,
    bool clearSourceLabel = false,
    bool clearSourceCheckedAt = false,
  }) {
    return HeatingDeviceCatalogEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      ratedPowerWatts: ratedPowerWatts ?? this.ratedPowerWatts,
      manufacturer: clearManufacturer
          ? null
          : manufacturer ?? this.manufacturer,
      series: clearSeries ? null : series ?? this.series,
      model: clearModel ? null : model ?? this.model,
      sectionCount: clearSectionCount
          ? null
          : sectionCount ?? this.sectionCount,
      widthMm: clearWidthMm ? null : widthMm ?? this.widthMm,
      heightMm: clearHeightMm ? null : heightMm ?? this.heightMm,
      depthMm: clearDepthMm ? null : depthMm ?? this.depthMm,
      waterVolumePerSection: clearWaterVolumePerSection
          ? null
          : waterVolumePerSection ?? this.waterVolumePerSection,
      panelType: clearPanelType ? null : panelType ?? this.panelType,
      connection: clearConnection ? null : connection ?? this.connection,
      workingPressureBar: clearWorkingPressureBar
          ? null
          : workingPressureBar ?? this.workingPressureBar,
      testPressureBar: clearTestPressureBar
          ? null
          : testPressureBar ?? this.testPressureBar,
      designFlowTempC: designFlowTempC ?? this.designFlowTempC,
      designReturnTempC: designReturnTempC ?? this.designReturnTempC,
      roomTempC: roomTempC ?? this.roomTempC,
      heatOutputExponent: clearHeatOutputExponent
          ? null
          : heatOutputExponent ?? this.heatOutputExponent,
      sourceUrl: clearSourceUrl ? null : sourceUrl ?? this.sourceUrl,
      sourceLabel: clearSourceLabel ? null : sourceLabel ?? this.sourceLabel,
      sourceCheckedAt: clearSourceCheckedAt
          ? null
          : sourceCheckedAt ?? this.sourceCheckedAt,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'ratedPowerWatts': ratedPowerWatts,
    'manufacturer': manufacturer,
    'series': series,
    'model': model,
    'sectionCount': sectionCount,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'depthMm': depthMm,
    'waterVolumePerSection': waterVolumePerSection,
    'panelType': panelType,
    'connection': connection,
    'workingPressureBar': workingPressureBar,
    'testPressureBar': testPressureBar,
    'designFlowTempC': designFlowTempC,
    'designReturnTempC': designReturnTempC,
    'roomTempC': roomTempC,
    'heatOutputExponent': heatOutputExponent,
    'sourceUrl': sourceUrl,
    'sourceLabel': sourceLabel,
    'sourceCheckedAt': sourceCheckedAt,
    'isCustom': isCustom,
  };
}

enum HeatingDeviceCatalogSource { seed, custom }

class HeatingDeviceCatalogItem {
  const HeatingDeviceCatalogItem({required this.entry, required this.source});

  final HeatingDeviceCatalogEntry entry;
  final HeatingDeviceCatalogSource source;

  bool get isCustom => source == HeatingDeviceCatalogSource.custom;
}

enum HeatingValveKind { ballValve, balancingValve, thermostaticValve }

HeatingValveKind parseHeatingValveKind(String value) => switch (value) {
  'ballValve' => HeatingValveKind.ballValve,
  'balancingValve' => HeatingValveKind.balancingValve,
  'thermostaticValve' => HeatingValveKind.thermostaticValve,
  _ => throw ArgumentError.value(value, 'value', 'Unknown valve kind'),
};

extension HeatingValveKindX on HeatingValveKind {
  String get label => switch (this) {
    HeatingValveKind.ballValve => 'Шаровый кран',
    HeatingValveKind.balancingValve => 'Балансировочный вентиль',
    HeatingValveKind.thermostaticValve => 'Термостатический клапан',
  };

  String get storageKey => switch (this) {
    HeatingValveKind.ballValve => 'ballValve',
    HeatingValveKind.balancingValve => 'balancingValve',
    HeatingValveKind.thermostaticValve => 'thermostaticValve',
  };

  bool get isRegulating => this != HeatingValveKind.ballValve;
}

class HeatingValveCatalogEntry {
  const HeatingValveCatalogEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.connectionDiameterMm,
    required this.kvs,
    this.manufacturer,
    this.model,
    this.settingKvMap = const {},
    this.sourceUrl,
    this.sourceLabel,
    this.sourceCheckedAt,
    this.isCustom = false,
  });

  factory HeatingValveCatalogEntry.fromJson(Map<String, dynamic> json) =>
      HeatingValveCatalogEntry(
        id: json['id'] as String,
        kind: parseHeatingValveKind(json['kind'] as String),
        title: json['title'] as String,
        manufacturer: json['manufacturer'] as String?,
        model: json['model'] as String?,
        connectionDiameterMm: (json['connectionDiameterMm'] as num).toDouble(),
        kvs: (json['kvs'] as num).toDouble(),
        settingKvMap:
            ((json['settingKvMap'] as Map<String, dynamic>?) ?? const {}).map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            ),
        sourceUrl: json['sourceUrl'] as String?,
        sourceLabel: json['sourceLabel'] as String?,
        sourceCheckedAt: json['sourceCheckedAt'] as String?,
        isCustom: json['isCustom'] as bool? ?? false,
      );

  final String id;
  final HeatingValveKind kind;
  final String title;
  final String? manufacturer;
  final String? model;
  final double connectionDiameterMm;
  final double kvs;
  final Map<String, double> settingKvMap;
  final String? sourceUrl;
  final String? sourceLabel;
  final String? sourceCheckedAt;
  final bool isCustom;

  bool get hasSettings => settingKvMap.isNotEmpty;

  HeatingValveCatalogEntry copyWith({
    String? id,
    HeatingValveKind? kind,
    String? title,
    String? manufacturer,
    String? model,
    double? connectionDiameterMm,
    double? kvs,
    Map<String, double>? settingKvMap,
    String? sourceUrl,
    String? sourceLabel,
    String? sourceCheckedAt,
    bool? isCustom,
    bool clearManufacturer = false,
    bool clearModel = false,
    bool clearSourceUrl = false,
    bool clearSourceLabel = false,
    bool clearSourceCheckedAt = false,
  }) {
    return HeatingValveCatalogEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      manufacturer: clearManufacturer
          ? null
          : manufacturer ?? this.manufacturer,
      model: clearModel ? null : model ?? this.model,
      connectionDiameterMm: connectionDiameterMm ?? this.connectionDiameterMm,
      kvs: kvs ?? this.kvs,
      settingKvMap: settingKvMap ?? this.settingKvMap,
      sourceUrl: clearSourceUrl ? null : sourceUrl ?? this.sourceUrl,
      sourceLabel: clearSourceLabel ? null : sourceLabel ?? this.sourceLabel,
      sourceCheckedAt: clearSourceCheckedAt
          ? null
          : sourceCheckedAt ?? this.sourceCheckedAt,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.storageKey,
    'title': title,
    'manufacturer': manufacturer,
    'model': model,
    'connectionDiameterMm': connectionDiameterMm,
    'kvs': kvs,
    'settingKvMap': settingKvMap,
    'sourceUrl': sourceUrl,
    'sourceLabel': sourceLabel,
    'sourceCheckedAt': sourceCheckedAt,
    'isCustom': isCustom,
  };
}

enum HeatingValveCatalogSource { seed, custom }

class HeatingValveCatalogItem {
  const HeatingValveCatalogItem({required this.entry, required this.source});

  final HeatingValveCatalogEntry entry;
  final HeatingValveCatalogSource source;

  bool get isCustom => source == HeatingValveCatalogSource.custom;
}

class OpeningTypeEntry {
  const OpeningTypeEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.subcategory,
    required this.manufacturer,
    required this.heatTransferCoefficient,
    this.defaultWidthMeters,
    this.defaultHeightMeters,
    required this.sourceUrl,
    required this.sourceLabel,
    required this.sourceCheckedAt,
    this.imageAssetPath,
    this.localImagePath,
    this.isCustom = false,
  });

  factory OpeningTypeEntry.fromJson(Map<String, dynamic> json) =>
      OpeningTypeEntry(
        id: json['id'] as String,
        kind: parseOpeningKind(json['kind'] as String),
        title: json['title'] as String,
        subcategory: json['subcategory'] as String,
        manufacturer: json['manufacturer'] as String,
        defaultWidthMeters:
            (json['defaultWidthMeters'] as num?)?.toDouble() ??
            (json['widthMeters'] as num?)?.toDouble(),
        defaultHeightMeters:
            (json['defaultHeightMeters'] as num?)?.toDouble() ??
            (json['heightMeters'] as num?)?.toDouble(),
        heatTransferCoefficient: (json['heatTransferCoefficient'] as num)
            .toDouble(),
        imageAssetPath: json['imageAssetPath'] as String?,
        localImagePath: json['localImagePath'] as String?,
        sourceUrl: json['sourceUrl'] as String,
        sourceLabel: json['sourceLabel'] as String,
        sourceCheckedAt: json['sourceCheckedAt'] as String,
        isCustom: json['isCustom'] as bool? ?? false,
      );

  final String id;
  final OpeningKind kind;
  final String title;
  final String subcategory;
  final String manufacturer;
  final double? defaultWidthMeters;
  final double? defaultHeightMeters;
  final double heatTransferCoefficient;
  final String? imageAssetPath;
  final String? localImagePath;
  final String sourceUrl;
  final String sourceLabel;
  final String sourceCheckedAt;
  final bool isCustom;

  OpeningTypeEntry copyWith({
    String? id,
    OpeningKind? kind,
    String? title,
    String? subcategory,
    String? manufacturer,
    double? defaultWidthMeters,
    double? defaultHeightMeters,
    double? heatTransferCoefficient,
    String? imageAssetPath,
    String? localImagePath,
    String? sourceUrl,
    String? sourceLabel,
    String? sourceCheckedAt,
    bool? isCustom,
    bool clearImageAssetPath = false,
    bool clearLocalImagePath = false,
  }) {
    return OpeningTypeEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subcategory: subcategory ?? this.subcategory,
      manufacturer: manufacturer ?? this.manufacturer,
      defaultWidthMeters: defaultWidthMeters ?? this.defaultWidthMeters,
      defaultHeightMeters: defaultHeightMeters ?? this.defaultHeightMeters,
      heatTransferCoefficient:
          heatTransferCoefficient ?? this.heatTransferCoefficient,
      imageAssetPath: clearImageAssetPath
          ? null
          : imageAssetPath ?? this.imageAssetPath,
      localImagePath: clearLocalImagePath
          ? null
          : localImagePath ?? this.localImagePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      sourceCheckedAt: sourceCheckedAt ?? this.sourceCheckedAt,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.storageKey,
    'title': title,
    'subcategory': subcategory,
    'manufacturer': manufacturer,
    'defaultWidthMeters': defaultWidthMeters,
    'defaultHeightMeters': defaultHeightMeters,
    'heatTransferCoefficient': heatTransferCoefficient,
    'imageAssetPath': imageAssetPath,
    'localImagePath': localImagePath,
    'sourceUrl': sourceUrl,
    'sourceLabel': sourceLabel,
    'sourceCheckedAt': sourceCheckedAt,
    'isCustom': isCustom,
  };
}

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.climatePoints,
    required this.materials,
    required this.constructionTemplates,
    required this.norms,
    required this.moistureRules,
    required this.roomKindConditions,
    required this.heatingDevices,
    required this.heatingValves,
    required this.openingCatalog,
    required this.datasetVersion,
  });

  final List<ClimatePoint> climatePoints;
  final List<MaterialEntry> materials;
  final List<Construction> constructionTemplates;
  final List<NormReference> norms;
  final MoistureRuleSet moistureRules;
  final List<RoomKindCondition> roomKindConditions;
  final List<HeatingDeviceCatalogEntry> heatingDevices;
  final List<HeatingValveCatalogEntry> heatingValves;
  final List<OpeningTypeEntry> openingCatalog;
  final String datasetVersion;
}
