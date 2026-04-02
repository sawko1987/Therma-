enum VentilationKind { natural, forced, heatRecovery }

extension VentilationKindX on VentilationKind {
  String get label => switch (this) {
    VentilationKind.natural => 'Естественная',
    VentilationKind.forced => 'Принудительная',
    VentilationKind.heatRecovery => 'С рекуперацией',
  };

  String get storageKey => switch (this) {
    VentilationKind.natural => 'natural',
    VentilationKind.forced => 'forced',
    VentilationKind.heatRecovery => 'heatRecovery',
  };
}

VentilationKind parseVentilationKind(String value) {
  return switch (value) {
    'natural' => VentilationKind.natural,
    'forced' => VentilationKind.forced,
    'heatRecovery' => VentilationKind.heatRecovery,
    _ => throw StateError('Unknown VentilationKind: $value'),
  };
}

class VentilationSettings {
  const VentilationSettings({
    required this.id,
    required this.title,
    required this.kind,
    required this.airExchangeRate,
    this.heatRecoveryEfficiency,
    this.roomId,
    this.notes,
  });

  factory VentilationSettings.fromJson(Map<String, dynamic> json) {
    return VentilationSettings(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: parseVentilationKind(json['kind'] as String),
      airExchangeRate: (json['airExchangeRate'] as num).toDouble(),
      heatRecoveryEfficiency:
          (json['heatRecoveryEfficiency'] as num?)?.toDouble(),
      roomId: json['roomId'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String title;
  final VentilationKind kind;
  final double airExchangeRate;
  final double? heatRecoveryEfficiency;
  final String? roomId;
  final String? notes;

  bool get isWholeHouse => roomId == null;

  double get effectiveHeatRecoveryEfficiency =>
      kind == VentilationKind.heatRecovery ? (heatRecoveryEfficiency ?? 0.0) : 0;

  VentilationSettings copyWith({
    String? id,
    String? title,
    VentilationKind? kind,
    double? airExchangeRate,
    double? heatRecoveryEfficiency,
    String? roomId,
    String? notes,
    bool clearHeatRecoveryEfficiency = false,
    bool clearRoomId = false,
    bool clearNotes = false,
  }) {
    return VentilationSettings(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      airExchangeRate: airExchangeRate ?? this.airExchangeRate,
      heatRecoveryEfficiency: clearHeatRecoveryEfficiency
          ? null
          : heatRecoveryEfficiency ?? this.heatRecoveryEfficiency,
      roomId: clearRoomId ? null : roomId ?? this.roomId,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.storageKey,
    'airExchangeRate': airExchangeRate,
    'heatRecoveryEfficiency': heatRecoveryEfficiency,
    'roomId': roomId,
    'notes': notes,
  };
}
