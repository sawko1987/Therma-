enum ConstructionElementKind { wall, roof, floor, ceiling, window, door }

enum LayerKind { solid, frame, crossFrame, masonry, ventilatedGap }

enum RoomType { livingRoom, bedroom, kitchen, bathroom, hallway, attic, basement }

enum SurfaceType { wall, roof, floor, ceiling }

enum BoundaryCondition { outdoor, ground, unheatedSpace, heatedAdjacent }

enum OpeningKind { window, door }

extension ConstructionElementKindX on ConstructionElementKind {
  String get label => switch (this) {
        ConstructionElementKind.wall => 'Наружная стена',
        ConstructionElementKind.roof => 'Кровля',
        ConstructionElementKind.floor => 'Пол',
        ConstructionElementKind.ceiling => 'Перекрытие',
        ConstructionElementKind.window => 'Окно',
        ConstructionElementKind.door => 'Дверь',
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

extension RoomTypeX on RoomType {
  String get label => switch (this) {
        RoomType.livingRoom => 'Гостиная',
        RoomType.bedroom => 'Спальня',
        RoomType.kitchen => 'Кухня',
        RoomType.bathroom => 'Санузел',
        RoomType.hallway => 'Коридор',
        RoomType.attic => 'Мансарда',
        RoomType.basement => 'Подвал',
      };

  double get defaultTargetTemperatureC => switch (this) {
        RoomType.livingRoom => 22,
        RoomType.bedroom => 20,
        RoomType.kitchen => 20,
        RoomType.bathroom => 24,
        RoomType.hallway => 18,
        RoomType.attic => 18,
        RoomType.basement => 16,
      };

  double get defaultAirChangesPerHour => switch (this) {
        RoomType.livingRoom => 0.5,
        RoomType.bedroom => 0.5,
        RoomType.kitchen => 1.0,
        RoomType.bathroom => 1.2,
        RoomType.hallway => 0.3,
        RoomType.attic => 0.4,
        RoomType.basement => 0.3,
      };
}

extension SurfaceTypeX on SurfaceType {
  String get label => switch (this) {
        SurfaceType.wall => 'Стена',
        SurfaceType.roof => 'Кровля',
        SurfaceType.floor => 'Пол',
        SurfaceType.ceiling => 'Перекрытие',
      };
}

extension BoundaryConditionX on BoundaryCondition {
  String get label => switch (this) {
        BoundaryCondition.outdoor => 'Наружный воздух',
        BoundaryCondition.ground => 'Грунт',
        BoundaryCondition.unheatedSpace => 'Неотапливаемая зона',
        BoundaryCondition.heatedAdjacent => 'Отапливаемое помещение',
      };
}

extension OpeningKindX on OpeningKind {
  String get label => switch (this) {
        OpeningKind.window => 'Окно',
        OpeningKind.door => 'Дверь',
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

  ConstructionLayer copyWith({
    String? id,
    String? materialId,
    LayerKind? kind,
    double? thicknessMm,
    bool? enabled,
  }) {
    return ConstructionLayer(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      kind: kind ?? this.kind,
      thicknessMm: thicknessMm ?? this.thicknessMm,
      enabled: enabled ?? this.enabled,
    );
  }
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

  Construction copyWith({
    String? id,
    String? title,
    ConstructionElementKind? elementKind,
    List<ConstructionLayer>? layers,
  }) {
    return Construction(
      id: id ?? this.id,
      title: title ?? this.title,
      elementKind: elementKind ?? this.elementKind,
      layers: layers ?? this.layers,
    );
  }
}

class Opening {
  const Opening({
    required this.id,
    required this.title,
    required this.kind,
    required this.areaM2,
    required this.constructionId,
  });

  final String id;
  final String title;
  final OpeningKind kind;
  final double areaM2;
  final String constructionId;

  Opening copyWith({
    String? id,
    String? title,
    OpeningKind? kind,
    double? areaM2,
    String? constructionId,
  }) {
    return Opening(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      areaM2: areaM2 ?? this.areaM2,
      constructionId: constructionId ?? this.constructionId,
    );
  }
}

class RoomBoundary {
  const RoomBoundary({
    required this.id,
    required this.title,
    required this.surfaceType,
    required this.boundaryCondition,
    required this.grossAreaM2,
    required this.constructionId,
    this.adjacentTemperatureC,
    this.adjacentRoomId,
    this.openings = const [],
  });

  final String id;
  final String title;
  final SurfaceType surfaceType;
  final BoundaryCondition boundaryCondition;
  final double grossAreaM2;
  final String constructionId;
  final double? adjacentTemperatureC;
  final String? adjacentRoomId;
  final List<Opening> openings;

  double get openingsAreaM2 =>
      openings.fold<double>(0, (sum, opening) => sum + opening.areaM2);

  double get opaqueAreaM2 => grossAreaM2 - openingsAreaM2;

  RoomBoundary copyWith({
    String? id,
    String? title,
    SurfaceType? surfaceType,
    BoundaryCondition? boundaryCondition,
    double? grossAreaM2,
    String? constructionId,
    double? adjacentTemperatureC,
    bool clearAdjacentTemperatureC = false,
    String? adjacentRoomId,
    bool clearAdjacentRoomId = false,
    List<Opening>? openings,
  }) {
    return RoomBoundary(
      id: id ?? this.id,
      title: title ?? this.title,
      surfaceType: surfaceType ?? this.surfaceType,
      boundaryCondition: boundaryCondition ?? this.boundaryCondition,
      grossAreaM2: grossAreaM2 ?? this.grossAreaM2,
      constructionId: constructionId ?? this.constructionId,
      adjacentTemperatureC: clearAdjacentTemperatureC
          ? null
          : adjacentTemperatureC ?? this.adjacentTemperatureC,
      adjacentRoomId:
          clearAdjacentRoomId ? null : adjacentRoomId ?? this.adjacentRoomId,
      openings: openings ?? this.openings,
    );
  }
}

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.roomType,
    required this.floorAreaM2,
    required this.heightM,
    this.targetTemperatureOverrideC,
    this.airChangesOverride,
    this.boundaries = const [],
  });

  final String id;
  final String name;
  final RoomType roomType;
  final double floorAreaM2;
  final double heightM;
  final double? targetTemperatureOverrideC;
  final double? airChangesOverride;
  final List<RoomBoundary> boundaries;

  double get targetTemperatureC =>
      targetTemperatureOverrideC ?? roomType.defaultTargetTemperatureC;

  double get airChangesPerHour =>
      airChangesOverride ?? roomType.defaultAirChangesPerHour;

  double get volumeM3 => floorAreaM2 * heightM;

  Room copyWith({
    String? id,
    String? name,
    RoomType? roomType,
    double? floorAreaM2,
    double? heightM,
    double? targetTemperatureOverrideC,
    bool clearTargetTemperatureOverrideC = false,
    double? airChangesOverride,
    bool clearAirChangesOverride = false,
    List<RoomBoundary>? boundaries,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      roomType: roomType ?? this.roomType,
      floorAreaM2: floorAreaM2 ?? this.floorAreaM2,
      heightM: heightM ?? this.heightM,
      targetTemperatureOverrideC: clearTargetTemperatureOverrideC
          ? null
          : targetTemperatureOverrideC ?? this.targetTemperatureOverrideC,
      airChangesOverride: clearAirChangesOverride
          ? null
          : airChangesOverride ?? this.airChangesOverride,
      boundaries: boundaries ?? this.boundaries,
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.climatePointId,
    required this.constructions,
    required this.rooms,
  });

  final String id;
  final String name;
  final String climatePointId;
  final List<Construction> constructions;
  final List<Room> rooms;

  Project copyWith({
    String? id,
    String? name,
    String? climatePointId,
    List<Construction>? constructions,
    List<Room>? rooms,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      climatePointId: climatePointId ?? this.climatePointId,
      constructions: constructions ?? this.constructions,
      rooms: rooms ?? this.rooms,
    );
  }
}
