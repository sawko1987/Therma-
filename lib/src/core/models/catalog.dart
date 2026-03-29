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
    'manufacturer': manufacturer,
    'subcategory': subcategory,
    'densityKgM3': densityKgM3,
    'notes': notes,
  };

  bool get isCustom => id.startsWith('custom-material-');
}

enum MaterialCatalogSource { seed, custom }

enum MaterialSortOption { name, category, lambdaAscending, lambdaDescending }

class MaterialCatalogEntry {
  const MaterialCatalogEntry({
    required this.material,
    required this.source,
    required this.isFavorite,
  });

  final MaterialEntry material;
  final MaterialCatalogSource source;
  final bool isFavorite;

  bool get isCustom => source == MaterialCatalogSource.custom;
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
    this.airChangesPerHour,
  });

  factory RoomKindCondition.fromJson(Map<String, dynamic> json) =>
      RoomKindCondition(
        roomKindId: json['roomKindId'] as String,
        insideTemperature: (json['insideTemperature'] as num).toDouble(),
        insideRelativeHumidity: (json['insideRelativeHumidity'] as num?)
            ?.toDouble(),
        airChangesPerHour: (json['airChangesPerHour'] as num?)?.toDouble(),
      );

  final String roomKindId;
  final double insideTemperature;
  final double? insideRelativeHumidity;
  final double? airChangesPerHour;
}

class HeatingDeviceCatalogEntry {
  const HeatingDeviceCatalogEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.ratedPowerWatts,
  });

  factory HeatingDeviceCatalogEntry.fromJson(Map<String, dynamic> json) =>
      HeatingDeviceCatalogEntry(
        id: json['id'] as String,
        kind: json['kind'] as String,
        title: json['title'] as String,
        ratedPowerWatts: (json['ratedPowerWatts'] as num).toDouble(),
      );

  final String id;
  final String kind;
  final String title;
  final double ratedPowerWatts;
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
    required this.datasetVersion,
  });

  final List<ClimatePoint> climatePoints;
  final List<MaterialEntry> materials;
  final List<Construction> constructionTemplates;
  final List<NormReference> norms;
  final MoistureRuleSet moistureRules;
  final List<RoomKindCondition> roomKindConditions;
  final List<HeatingDeviceCatalogEntry> heatingDevices;
  final String datasetVersion;
}
