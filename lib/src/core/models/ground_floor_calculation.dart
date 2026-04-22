class GroundFloorCalculation {
  const GroundFloorCalculation({
    required this.id,
    required this.title,
    required this.kind,
    required this.constructionId,
    required this.areaSquareMeters,
    required this.perimeterMeters,
    required this.slabWidthMeters,
    required this.slabLengthMeters,
    required this.edgeInsulationWidthMeters,
    required this.edgeInsulationResistance,
    this.notes,
  });

  factory GroundFloorCalculation.fromJson(Map<String, dynamic> json) {
    return GroundFloorCalculation(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: parseGroundFloorCalculationKind(json['kind'] as String),
      constructionId: json['constructionId'] as String,
      areaSquareMeters: (json['areaSquareMeters'] as num).toDouble(),
      perimeterMeters: (json['perimeterMeters'] as num).toDouble(),
      slabWidthMeters: (json['slabWidthMeters'] as num).toDouble(),
      slabLengthMeters: (json['slabLengthMeters'] as num).toDouble(),
      edgeInsulationWidthMeters:
          (json['edgeInsulationWidthMeters'] as num?)?.toDouble() ?? 0.6,
      edgeInsulationResistance:
          (json['edgeInsulationResistance'] as num?)?.toDouble() ?? 1.5,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String title;
  final GroundFloorCalculationKind kind;
  final String constructionId;
  final double areaSquareMeters;
  final double perimeterMeters;
  final double slabWidthMeters;
  final double slabLengthMeters;
  final double edgeInsulationWidthMeters;
  final double edgeInsulationResistance;
  final String? notes;

  double get shapeFactor => perimeterMeters / areaSquareMeters;

  GroundFloorCalculation copyWith({
    String? id,
    String? title,
    GroundFloorCalculationKind? kind,
    String? constructionId,
    double? areaSquareMeters,
    double? perimeterMeters,
    double? slabWidthMeters,
    double? slabLengthMeters,
    double? edgeInsulationWidthMeters,
    double? edgeInsulationResistance,
    String? notes,
    bool clearNotes = false,
  }) {
    return GroundFloorCalculation(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      constructionId: constructionId ?? this.constructionId,
      areaSquareMeters: areaSquareMeters ?? this.areaSquareMeters,
      perimeterMeters: perimeterMeters ?? this.perimeterMeters,
      slabWidthMeters: slabWidthMeters ?? this.slabWidthMeters,
      slabLengthMeters: slabLengthMeters ?? this.slabLengthMeters,
      edgeInsulationWidthMeters:
          edgeInsulationWidthMeters ?? this.edgeInsulationWidthMeters,
      edgeInsulationResistance:
          edgeInsulationResistance ?? this.edgeInsulationResistance,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.storageKey,
    'constructionId': constructionId,
    'areaSquareMeters': areaSquareMeters,
    'perimeterMeters': perimeterMeters,
    'slabWidthMeters': slabWidthMeters,
    'slabLengthMeters': slabLengthMeters,
    'edgeInsulationWidthMeters': edgeInsulationWidthMeters,
    'edgeInsulationResistance': edgeInsulationResistance,
    'notes': notes,
  };
}

enum GroundFloorCalculationKind {
  slabOnGround,
  stripFoundationFloor,
  basementSlab,
}

extension GroundFloorCalculationKindX on GroundFloorCalculationKind {
  String get label => switch (this) {
    GroundFloorCalculationKind.slabOnGround => 'Плита по грунту',
    GroundFloorCalculationKind.stripFoundationFloor => 'Пол по грунту на ленте',
    GroundFloorCalculationKind.basementSlab => 'Плита над подвалом',
  };

  String get storageKey => switch (this) {
    GroundFloorCalculationKind.slabOnGround => 'slabOnGround',
    GroundFloorCalculationKind.stripFoundationFloor => 'stripFoundationFloor',
    GroundFloorCalculationKind.basementSlab => 'basementSlab',
  };

  bool get isSupportedInV1 => this == GroundFloorCalculationKind.slabOnGround;
}

GroundFloorCalculationKind parseGroundFloorCalculationKind(String value) {
  return switch (value) {
    'slabOnGround' => GroundFloorCalculationKind.slabOnGround,
    'stripFoundationFloor' => GroundFloorCalculationKind.stripFoundationFloor,
    'basementSlab' => GroundFloorCalculationKind.basementSlab,
    _ => throw StateError('Unknown GroundFloorCalculationKind: $value'),
  };
}

class GroundFloorCalculationResult {
  const GroundFloorCalculationResult({
    required this.calculation,
    required this.isSupported,
    required this.statusMessage,
    required this.insideAirTemperature,
    required this.outsideAirTemperature,
    required this.deltaTemperature,
    required this.requiredResistance,
    required this.constructionResistance,
    required this.equivalentGroundResistance,
    required this.totalResistance,
    required this.heatTransferCoefficient,
    required this.heatLossWatts,
    required this.specificHeatLossWattsPerSquareMeter,
    required this.shapeFactor,
    required this.appliedNormReferenceIds,
  });

  final GroundFloorCalculation calculation;
  final bool isSupported;
  final String statusMessage;
  final double insideAirTemperature;
  final double outsideAirTemperature;
  final double deltaTemperature;
  final double requiredResistance;
  final double constructionResistance;
  final double equivalentGroundResistance;
  final double totalResistance;
  final double heatTransferCoefficient;
  final double heatLossWatts;
  final double specificHeatLossWattsPerSquareMeter;
  final double shapeFactor;
  final List<String> appliedNormReferenceIds;

  bool get passesResistanceCheck => totalResistance >= requiredResistance;
}
