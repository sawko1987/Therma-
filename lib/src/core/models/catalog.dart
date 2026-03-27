class ClimatePoint {
  const ClimatePoint({
    required this.id,
    required this.country,
    required this.region,
    required this.city,
    required this.designTemperature,
    required this.heatingPeriodDays,
    required this.gsop,
  });

  factory ClimatePoint.fromJson(Map<String, dynamic> json) => ClimatePoint(
        id: json['id'] as String,
        country: json['country'] as String,
        region: json['region'] as String,
        city: json['city'] as String,
        designTemperature: (json['designTemperature'] as num).toDouble(),
        heatingPeriodDays: json['heatingPeriodDays'] as int,
        gsop: (json['gsop'] as num).toDouble(),
      );

  final String id;
  final String country;
  final String region;
  final String city;
  final double designTemperature;
  final int heatingPeriodDays;
  final double gsop;

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

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.climatePoints,
    required this.materials,
    required this.norms,
    required this.datasetVersion,
  });

  final List<ClimatePoint> climatePoints;
  final List<MaterialEntry> materials;
  final List<NormReference> norms;
  final String datasetVersion;
}
