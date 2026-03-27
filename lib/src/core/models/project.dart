const int currentProjectFormatVersion = 1;

enum ConstructionElementKind { wall, roof, floor, ceiling }

enum LayerKind { solid, frame, crossFrame, masonry, ventilatedGap }

enum RoomPreset { livingRoom, attic, basement }

extension ConstructionElementKindX on ConstructionElementKind {
  String get label => switch (this) {
    ConstructionElementKind.wall => 'Наружная стена',
    ConstructionElementKind.roof => 'Кровля',
    ConstructionElementKind.floor => 'Пол',
    ConstructionElementKind.ceiling => 'Перекрытие',
  };

  String get storageKey => switch (this) {
    ConstructionElementKind.wall => 'wall',
    ConstructionElementKind.roof => 'roof',
    ConstructionElementKind.floor => 'floor',
    ConstructionElementKind.ceiling => 'ceiling',
  };
}

extension LayerKindX on LayerKind {
  String get label => switch (this) {
    LayerKind.solid => 'Однородный',
    LayerKind.frame => 'Каркас',
    LayerKind.crossFrame => 'Перекрёстный каркас',
    LayerKind.masonry => 'Кладка',
    LayerKind.ventilatedGap => 'Вентзазор',
  };

  String get storageKey => switch (this) {
    LayerKind.solid => 'solid',
    LayerKind.frame => 'frame',
    LayerKind.crossFrame => 'crossFrame',
    LayerKind.masonry => 'masonry',
    LayerKind.ventilatedGap => 'ventilatedGap',
  };
}

extension RoomPresetX on RoomPreset {
  String get label => switch (this) {
    RoomPreset.livingRoom => 'Жилая комната',
    RoomPreset.attic => 'Мансарда',
    RoomPreset.basement => 'Подвал',
  };

  String get catalogId => switch (this) {
    RoomPreset.livingRoom => 'livingRoom',
    RoomPreset.attic => 'attic',
    RoomPreset.basement => 'basement',
  };

  String get storageKey => switch (this) {
    RoomPreset.livingRoom => 'livingRoom',
    RoomPreset.attic => 'attic',
    RoomPreset.basement => 'basement',
  };
}

ConstructionElementKind parseConstructionElementKind(String value) {
  return switch (value) {
    'wall' => ConstructionElementKind.wall,
    'roof' => ConstructionElementKind.roof,
    'floor' => ConstructionElementKind.floor,
    'ceiling' => ConstructionElementKind.ceiling,
    _ => throw StateError('Unknown ConstructionElementKind: $value'),
  };
}

LayerKind parseLayerKind(String value) {
  return switch (value) {
    'solid' => LayerKind.solid,
    'frame' => LayerKind.frame,
    'crossFrame' => LayerKind.crossFrame,
    'masonry' => LayerKind.masonry,
    'ventilatedGap' => LayerKind.ventilatedGap,
    _ => throw StateError('Unknown LayerKind: $value'),
  };
}

RoomPreset parseRoomPreset(String value) {
  return switch (value) {
    'livingRoom' => RoomPreset.livingRoom,
    'attic' => RoomPreset.attic,
    'basement' => RoomPreset.basement,
    _ => throw StateError('Unknown RoomPreset: $value'),
  };
}

class ConstructionLayer {
  const ConstructionLayer({
    required this.id,
    required this.materialId,
    required this.kind,
    required this.thicknessMm,
    this.enabled = true,
  });

  factory ConstructionLayer.fromJson(Map<String, dynamic> json) =>
      ConstructionLayer(
        id: json['id'] as String,
        materialId: json['materialId'] as String,
        kind: parseLayerKind(json['kind'] as String),
        thicknessMm: (json['thicknessMm'] as num).toDouble(),
        enabled: json['enabled'] as bool? ?? true,
      );

  final String id;
  final String materialId;
  final LayerKind kind;
  final double thicknessMm;
  final bool enabled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'materialId': materialId,
    'kind': kind.storageKey,
    'thicknessMm': thicknessMm,
    'enabled': enabled,
  };
}

class Construction {
  const Construction({
    required this.id,
    required this.title,
    required this.elementKind,
    required this.layers,
  });

  factory Construction.fromJson(Map<String, dynamic> json) => Construction(
    id: json['id'] as String,
    title: json['title'] as String,
    elementKind: parseConstructionElementKind(json['elementKind'] as String),
    layers: (json['layers'] as List<dynamic>)
        .map((item) => ConstructionLayer.fromJson(_asJsonMap(item)))
        .toList(growable: false),
  );

  final String id;
  final String title;
  final ConstructionElementKind elementKind;
  final List<ConstructionLayer> layers;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'elementKind': elementKind.storageKey,
    'layers': layers.map((item) => item.toJson()).toList(growable: false),
  };
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.climatePointId,
    required this.roomPreset,
    required this.constructions,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    final formatVersion = (json['projectFormatVersion'] as num?)?.toInt() ?? 1;
    if (formatVersion > currentProjectFormatVersion) {
      throw StateError('Unsupported projectFormatVersion: $formatVersion');
    }

    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      climatePointId: json['climatePointId'] as String,
      roomPreset: parseRoomPreset(json['roomPreset'] as String),
      constructions: (json['constructions'] as List<dynamic>)
          .map((item) => Construction.fromJson(_asJsonMap(item)))
          .toList(growable: false),
    );
  }

  final String id;
  final String name;
  final String climatePointId;
  final RoomPreset roomPreset;
  final List<Construction> constructions;

  Map<String, dynamic> toJson() => {
    'projectFormatVersion': currentProjectFormatVersion,
    'id': id,
    'name': name,
    'climatePointId': climatePointId,
    'roomPreset': roomPreset.storageKey,
    'constructions': constructions
        .map((item) => item.toJson())
        .toList(growable: false),
  };
}

Map<String, dynamic> _asJsonMap(Object? value) {
  return Map<String, dynamic>.from(value! as Map);
}
