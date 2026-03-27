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
}

extension LayerKindX on LayerKind {
  String get label => switch (this) {
        LayerKind.solid => 'Однородный',
        LayerKind.frame => 'Каркас',
        LayerKind.crossFrame => 'Перекрестный каркас',
        LayerKind.masonry => 'Кладка',
        LayerKind.ventilatedGap => 'Вентзазор',
      };
}

extension RoomPresetX on RoomPreset {
  String get label => switch (this) {
        RoomPreset.livingRoom => 'Жилая комната',
        RoomPreset.attic => 'Мансарда',
        RoomPreset.basement => 'Подвал',
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

  final String id;
  final String materialId;
  final LayerKind kind;
  final double thicknessMm;
  final bool enabled;
}

class Construction {
  const Construction({
    required this.id,
    required this.title,
    required this.elementKind,
    required this.layers,
  });

  final String id;
  final String title;
  final ConstructionElementKind elementKind;
  final List<ConstructionLayer> layers;
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.climatePointId,
    required this.roomPreset,
    required this.constructions,
  });

  final String id;
  final String name;
  final String climatePointId;
  final RoomPreset roomPreset;
  final List<Construction> constructions;
}
