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
  final int heatingPeriodDays;
  final double gsop;
  final List<ClimateSeason> moistureSeasons;

  String get displayName => '$city, $region';
}

class MaterialEntry {
  const MaterialEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.thermalConductivity,
    required this.vaporPermeability,
  });

  factory MaterialEntry.fromJson(Map<String, dynamic> json) => MaterialEntry(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    thermalConductivity: (json['thermalConductivity'] as num).toDouble(),
    vaporPermeability: (json['vaporPermeability'] as num).toDouble(),
  );

  final String id;
  final String name;
  final String category;
  final double thermalConductivity;
  final double vaporPermeability;
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

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.climatePoints,
    required this.materials,
    required this.norms,
    required this.moistureRules,
    required this.datasetVersion,
  });

  final List<ClimatePoint> climatePoints;
  final List<MaterialEntry> materials;
  final List<NormReference> norms;
  final MoistureRuleSet moistureRules;
  final String datasetVersion;
}
