import 'dart:math' as math;

import 'catalog.dart';
import 'ground_floor_calculation.dart';

const int currentProjectFormatVersion = 19;
const double defaultHouseElementAreaSquareMeters = 100.0;
const double defaultRoomLayoutWidthMeters = 4.0;
const double defaultRoomLayoutHeightMeters = 4.0;
const double defaultRoomAreaSquareMeters =
    defaultRoomLayoutWidthMeters * defaultRoomLayoutHeightMeters;
const double defaultRoomHeightMeters = 2.7;
const double defaultRoomComfortTemperatureC = 20.0;
const double defaultRoomVentilationSupplyM3h = 0.0;
const double minimumRoomLayoutDimensionMeters = 1.5;
const double roomLayoutSnapStepMeters = 0.5;
const double roomLayoutGapMeters = 1.0;
const String defaultRoomId = 'room-main';
const double defaultElectricityPricePerKwh = 6.5;
const double defaultGasPricePerCubicMeter = 7.5;
const double defaultGasBoilerEfficiency = 0.92;
const double defaultHeatPumpCop = 3.0;

enum ConstructionElementKind { wall, roof, floor, ceiling }

enum FloorConstructionType {
  onGround,
  overCrawlSpace,
  overBasement,
  overDriveway,
}

enum CrawlSpaceVentilationMode { ventilated, unventilated }

enum OpeningKind { window, door }

enum RoomSide { top, right, bottom, left }

enum WallOrientation { north, east, south, west }

enum LayerKind { solid, frame, crossFrame, masonry, ventilatedGap }

enum RoomPreset { livingRoom, attic, basement }

enum RoomKind {
  livingRoom,
  bedroom,
  kitchen,
  bathroom,
  hall,
  boilerRoom,
  other,
}

enum HeatingDeviceKind { radiator, convector, underfloorLoop, towelRail, other }

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

extension FloorConstructionTypeX on FloorConstructionType {
  String get label => switch (this) {
    FloorConstructionType.onGround => 'Пол по грунту',
    FloorConstructionType.overCrawlSpace => 'Пол над техподпольем',
    FloorConstructionType.overBasement => 'Пол над подвалом',
    FloorConstructionType.overDriveway => 'Пол над проездом',
  };

  String get storageKey => switch (this) {
    FloorConstructionType.onGround => 'onGround',
    FloorConstructionType.overCrawlSpace => 'overCrawlSpace',
    FloorConstructionType.overBasement => 'overBasement',
    FloorConstructionType.overDriveway => 'overDriveway',
  };
}

extension CrawlSpaceVentilationModeX on CrawlSpaceVentilationMode {
  String get label => switch (this) {
    CrawlSpaceVentilationMode.ventilated => 'Вентилируемое',
    CrawlSpaceVentilationMode.unventilated => 'Невентилируемое',
  };

  String get storageKey => switch (this) {
    CrawlSpaceVentilationMode.ventilated => 'ventilated',
    CrawlSpaceVentilationMode.unventilated => 'unventilated',
  };
}

extension OpeningKindX on OpeningKind {
  String get label => switch (this) {
    OpeningKind.window => 'Окно',
    OpeningKind.door => 'Дверь',
  };

  String get storageKey => switch (this) {
    OpeningKind.window => 'window',
    OpeningKind.door => 'door',
  };

  double get defaultHeatTransferCoefficient => switch (this) {
    OpeningKind.window => 1.0,
    OpeningKind.door => 1.5,
  };
}

extension RoomSideX on RoomSide {
  String get label => switch (this) {
    RoomSide.top => 'Сверху',
    RoomSide.right => 'Справа',
    RoomSide.bottom => 'Снизу',
    RoomSide.left => 'Слева',
  };

  String get storageKey => switch (this) {
    RoomSide.top => 'top',
    RoomSide.right => 'right',
    RoomSide.bottom => 'bottom',
    RoomSide.left => 'left',
  };

  bool get isHorizontal => this == RoomSide.top || this == RoomSide.bottom;
}

extension WallOrientationX on WallOrientation {
  String get label => switch (this) {
    WallOrientation.north => 'Север',
    WallOrientation.east => 'Восток',
    WallOrientation.south => 'Юг',
    WallOrientation.west => 'Запад',
  };

  String get storageKey => switch (this) {
    WallOrientation.north => 'north',
    WallOrientation.east => 'east',
    WallOrientation.south => 'south',
    WallOrientation.west => 'west',
  };

  double get heatLossFactor => switch (this) {
    WallOrientation.north => 1.10,
    WallOrientation.east => 1.0,
    WallOrientation.south => 0.90,
    WallOrientation.west => 1.0,
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

extension RoomKindX on RoomKind {
  String get label => switch (this) {
    RoomKind.livingRoom => 'Гостиная',
    RoomKind.bedroom => 'Спальня',
    RoomKind.kitchen => 'Кухня',
    RoomKind.bathroom => 'Санузел',
    RoomKind.hall => 'Холл',
    RoomKind.boilerRoom => 'Котельная',
    RoomKind.other => 'Другое',
  };

  String get storageKey => switch (this) {
    RoomKind.livingRoom => 'livingRoom',
    RoomKind.bedroom => 'bedroom',
    RoomKind.kitchen => 'kitchen',
    RoomKind.bathroom => 'bathroom',
    RoomKind.hall => 'hall',
    RoomKind.boilerRoom => 'boilerRoom',
    RoomKind.other => 'other',
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

FloorConstructionType parseFloorConstructionType(String value) {
  return switch (value) {
    'onGround' => FloorConstructionType.onGround,
    'overCrawlSpace' => FloorConstructionType.overCrawlSpace,
    'overBasement' => FloorConstructionType.overBasement,
    'overDriveway' => FloorConstructionType.overDriveway,
    _ => throw StateError('Unknown FloorConstructionType: $value'),
  };
}

CrawlSpaceVentilationMode parseCrawlSpaceVentilationMode(String value) {
  return switch (value) {
    'ventilated' => CrawlSpaceVentilationMode.ventilated,
    'unventilated' => CrawlSpaceVentilationMode.unventilated,
    _ => throw StateError('Unknown CrawlSpaceVentilationMode: $value'),
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

extension HeatingDeviceKindX on HeatingDeviceKind {
  String get label => switch (this) {
    HeatingDeviceKind.radiator => 'Радиатор',
    HeatingDeviceKind.convector => 'Конвектор',
    HeatingDeviceKind.underfloorLoop => 'Теплый пол',
    HeatingDeviceKind.towelRail => 'Полотенцесушитель',
    HeatingDeviceKind.other => 'Другое',
  };

  String get storageKey => switch (this) {
    HeatingDeviceKind.radiator => 'radiator',
    HeatingDeviceKind.convector => 'convector',
    HeatingDeviceKind.underfloorLoop => 'underfloorLoop',
    HeatingDeviceKind.towelRail => 'towelRail',
    HeatingDeviceKind.other => 'other',
  };
}

RoomSide parseRoomSide(String value) {
  return switch (value) {
    'top' => RoomSide.top,
    'right' => RoomSide.right,
    'bottom' => RoomSide.bottom,
    'left' => RoomSide.left,
    _ => throw StateError('Unknown RoomSide: $value'),
  };
}

RoomKind parseRoomKind(String value) {
  return switch (value) {
    'livingRoom' => RoomKind.livingRoom,
    'bedroom' => RoomKind.bedroom,
    'kitchen' => RoomKind.kitchen,
    'bathroom' => RoomKind.bathroom,
    'hall' => RoomKind.hall,
    'boilerRoom' => RoomKind.boilerRoom,
    'other' => RoomKind.other,
    _ => throw StateError('Unknown RoomKind: $value'),
  };
}

OpeningKind parseOpeningKind(String value) {
  return switch (value) {
    'window' => OpeningKind.window,
    'door' => OpeningKind.door,
    _ => throw StateError('Unknown OpeningKind: $value'),
  };
}

HeatingDeviceKind parseHeatingDeviceKind(String value) {
  return switch (value) {
    'radiator' => HeatingDeviceKind.radiator,
    'convector' => HeatingDeviceKind.convector,
    'underfloorLoop' => HeatingDeviceKind.underfloorLoop,
    'towelRail' => HeatingDeviceKind.towelRail,
    'other' => HeatingDeviceKind.other,
    _ => throw StateError('Unknown HeatingDeviceKind: $value'),
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
    this.floorConstructionType,
    this.crawlSpaceVentilationMode,
  });

  factory Construction.fromJson(Map<String, dynamic> json) {
    final elementKind = parseConstructionElementKind(
      json['elementKind'] as String,
    );
    final floorConstructionTypeValue = json['floorConstructionType'] as String?;
    final crawlSpaceVentilationModeValue =
        json['crawlSpaceVentilationMode'] as String?;
    return Construction(
      id: json['id'] as String,
      title: json['title'] as String,
      elementKind: elementKind,
      layers: (json['layers'] as List<dynamic>)
          .map((item) => ConstructionLayer.fromJson(_asJsonMap(item)))
          .toList(growable: false),
      floorConstructionType: switch (elementKind) {
        ConstructionElementKind.floor when floorConstructionTypeValue != null =>
          parseFloorConstructionType(floorConstructionTypeValue),
        _ => null,
      },
      crawlSpaceVentilationMode: switch (floorConstructionTypeValue) {
        'overCrawlSpace' when crawlSpaceVentilationModeValue != null =>
          parseCrawlSpaceVentilationMode(crawlSpaceVentilationModeValue),
        _ => null,
      },
    );
  }

  final String id;
  final String title;
  final ConstructionElementKind elementKind;
  final List<ConstructionLayer> layers;
  final FloorConstructionType? floorConstructionType;
  final CrawlSpaceVentilationMode? crawlSpaceVentilationMode;

  Construction copyWith({
    String? id,
    String? title,
    ConstructionElementKind? elementKind,
    List<ConstructionLayer>? layers,
    FloorConstructionType? floorConstructionType,
    CrawlSpaceVentilationMode? crawlSpaceVentilationMode,
    bool clearFloorConstructionType = false,
    bool clearCrawlSpaceVentilationMode = false,
  }) {
    return Construction(
      id: id ?? this.id,
      title: title ?? this.title,
      elementKind: elementKind ?? this.elementKind,
      layers: layers ?? this.layers,
      floorConstructionType: clearFloorConstructionType
          ? null
          : floorConstructionType ?? this.floorConstructionType,
      crawlSpaceVentilationMode: clearCrawlSpaceVentilationMode
          ? null
          : crawlSpaceVentilationMode ?? this.crawlSpaceVentilationMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'elementKind': elementKind.storageKey,
    'layers': layers.map((item) => item.toJson()).toList(growable: false),
    if (elementKind == ConstructionElementKind.floor &&
        floorConstructionType != null)
      'floorConstructionType': floorConstructionType!.storageKey,
    if (floorConstructionType == FloorConstructionType.overCrawlSpace &&
        crawlSpaceVentilationMode != null)
      'crawlSpaceVentilationMode': crawlSpaceVentilationMode!.storageKey,
  };
}

class RoomLayoutRect {
  const RoomLayoutRect({
    required this.xMeters,
    required this.yMeters,
    required this.widthMeters,
    required this.heightMeters,
  });

  factory RoomLayoutRect.fromJson(Map<String, dynamic> json) => RoomLayoutRect(
    xMeters: (json['xMeters'] as num).toDouble(),
    yMeters: (json['yMeters'] as num).toDouble(),
    widthMeters: (json['widthMeters'] as num).toDouble(),
    heightMeters: (json['heightMeters'] as num).toDouble(),
  );

  factory RoomLayoutRect.defaultRect({
    double xMeters = 0,
    double yMeters = 0,
  }) => RoomLayoutRect(
    xMeters: xMeters,
    yMeters: yMeters,
    widthMeters: defaultRoomLayoutWidthMeters,
    heightMeters: defaultRoomLayoutHeightMeters,
  );

  factory RoomLayoutRect.squareFromArea(
    double areaSquareMeters, {
    required double xMeters,
    required double yMeters,
  }) {
    final normalizedArea = areaSquareMeters > 0
        ? areaSquareMeters
        : defaultRoomAreaSquareMeters;
    final side = math.sqrt(normalizedArea);
    return RoomLayoutRect(
      xMeters: xMeters,
      yMeters: yMeters,
      widthMeters: side,
      heightMeters: side,
    );
  }

  final double xMeters;
  final double yMeters;
  final double widthMeters;
  final double heightMeters;

  double get rightMeters => xMeters + widthMeters;
  double get bottomMeters => yMeters + heightMeters;
  double get areaSquareMeters => widthMeters * heightMeters;

  double sideLength(RoomSide side) {
    return side.isHorizontal ? widthMeters : heightMeters;
  }

  RoomLayoutRect copyWith({
    double? xMeters,
    double? yMeters,
    double? widthMeters,
    double? heightMeters,
  }) {
    return RoomLayoutRect(
      xMeters: xMeters ?? this.xMeters,
      yMeters: yMeters ?? this.yMeters,
      widthMeters: widthMeters ?? this.widthMeters,
      heightMeters: heightMeters ?? this.heightMeters,
    );
  }

  Map<String, dynamic> toJson() => {
    'xMeters': xMeters,
    'yMeters': yMeters,
    'widthMeters': widthMeters,
    'heightMeters': heightMeters,
  };
}

class EnvelopeWallPlacement {
  const EnvelopeWallPlacement({
    required this.side,
    required this.offsetMeters,
    required this.lengthMeters,
  });

  factory EnvelopeWallPlacement.fromJson(Map<String, dynamic> json) =>
      EnvelopeWallPlacement(
        side: parseRoomSide(json['side'] as String),
        offsetMeters: (json['offsetMeters'] as num).toDouble(),
        lengthMeters: (json['lengthMeters'] as num).toDouble(),
      );

  final RoomSide side;
  final double offsetMeters;
  final double lengthMeters;

  double get endMeters => offsetMeters + lengthMeters;

  EnvelopeWallPlacement copyWith({
    RoomSide? side,
    double? offsetMeters,
    double? lengthMeters,
  }) {
    return EnvelopeWallPlacement(
      side: side ?? this.side,
      offsetMeters: offsetMeters ?? this.offsetMeters,
      lengthMeters: lengthMeters ?? this.lengthMeters,
    );
  }

  Map<String, dynamic> toJson() => {
    'side': side.storageKey,
    'offsetMeters': offsetMeters,
    'lengthMeters': lengthMeters,
  };
}

class Room {
  const Room({
    required this.id,
    required this.title,
    required this.kind,
    required this.heightMeters,
    required this.layout,
    this.comfortTemperatureC = defaultRoomComfortTemperatureC,
    this.ventilationSupplyM3h = defaultRoomVentilationSupplyM3h,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final areaSquareMeters =
        (json['areaSquareMeters'] as num?)?.toDouble() ??
        defaultRoomAreaSquareMeters;
    final layoutJson = json['layout'];
    return Room(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: parseRoomKind(
        (json['kind'] as String?) ?? RoomKind.other.storageKey,
      ),
      heightMeters:
          (json['heightMeters'] as num?)?.toDouble() ?? defaultRoomHeightMeters,
      layout: layoutJson == null
          ? RoomLayoutRect.squareFromArea(
              areaSquareMeters,
              xMeters: 0,
              yMeters: 0,
            )
          : RoomLayoutRect.fromJson(_asJsonMap(layoutJson)),
      comfortTemperatureC:
          (json['comfortTemperatureC'] as num?)?.toDouble() ??
          defaultRoomComfortTemperatureC,
      ventilationSupplyM3h:
          (json['ventilationSupplyM3h'] as num?)?.toDouble() ??
          defaultRoomVentilationSupplyM3h,
    );
  }

  factory Room.defaultRoom() => const Room(
    id: defaultRoomId,
    title: 'Основное помещение',
    kind: RoomKind.livingRoom,
    heightMeters: defaultRoomHeightMeters,
    layout: RoomLayoutRect(
      xMeters: 0,
      yMeters: 0,
      widthMeters: defaultRoomLayoutWidthMeters,
      heightMeters: defaultRoomLayoutHeightMeters,
    ),
    comfortTemperatureC: defaultRoomComfortTemperatureC,
    ventilationSupplyM3h: defaultRoomVentilationSupplyM3h,
  );

  final String id;
  final String title;
  final RoomKind kind;
  final double heightMeters;
  final RoomLayoutRect layout;
  final double comfortTemperatureC;
  final double ventilationSupplyM3h;

  double get areaSquareMeters => layout.areaSquareMeters;

  Room copyWith({
    String? id,
    String? title,
    RoomKind? kind,
    double? heightMeters,
    RoomLayoutRect? layout,
    double? comfortTemperatureC,
    double? ventilationSupplyM3h,
  }) {
    return Room(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      heightMeters: heightMeters ?? this.heightMeters,
      layout: layout ?? this.layout,
      comfortTemperatureC: comfortTemperatureC ?? this.comfortTemperatureC,
      ventilationSupplyM3h: ventilationSupplyM3h ?? this.ventilationSupplyM3h,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.storageKey,
    'areaSquareMeters': areaSquareMeters,
    'heightMeters': heightMeters,
    'layout': layout.toJson(),
    'comfortTemperatureC': comfortTemperatureC,
    'ventilationSupplyM3h': ventilationSupplyM3h,
  };
}

WallOrientation parseWallOrientation(String value) {
  return switch (value) {
    'north' => WallOrientation.north,
    'east' => WallOrientation.east,
    'south' => WallOrientation.south,
    'west' => WallOrientation.west,
    _ => throw StateError('Unknown WallOrientation: $value'),
  };
}

class HouseEnvelopeElement {
  const HouseEnvelopeElement({
    required this.id,
    required this.roomId,
    required this.title,
    required this.elementKind,
    required this.areaSquareMeters,
    required this.construction,
    this.sourceConstructionId,
    this.sourceConstructionTitle,
    this.wallOrientation,
    this.wallPlacement,
  });

  factory HouseEnvelopeElement.fromJson(
    Map<String, dynamic> json, {
    List<Construction> availableConstructions = const [],
  }) =>
      HouseEnvelopeElement(
        id: json['id'] as String,
        roomId: (json['roomId'] as String?) ?? defaultRoomId,
        title: json['title'] as String,
        elementKind: parseConstructionElementKind(
          json['elementKind'] as String,
        ),
        areaSquareMeters: (json['areaSquareMeters'] as num).toDouble(),
        construction: _resolveElementConstruction(
          json,
          availableConstructions: availableConstructions,
        ),
        sourceConstructionId: json['sourceConstructionId'] as String? ??
            json['constructionId'] as String?,
        sourceConstructionTitle: json['sourceConstructionTitle'] as String?,
        wallOrientation: (json['wallOrientation'] as String?) == null
            ? null
            : parseWallOrientation(json['wallOrientation'] as String),
        wallPlacement: json['wallPlacement'] == null
            ? null
            : EnvelopeWallPlacement.fromJson(_asJsonMap(json['wallPlacement'])),
      );

  factory HouseEnvelopeElement.fromConstruction(
    Construction construction, {
    String roomId = defaultRoomId,
    Room? room,
  }) {
    final effectiveRoom = room ?? Room.defaultRoom();
    final wallPlacement =
        construction.elementKind == ConstructionElementKind.wall
        ? EnvelopeWallPlacement(
            side: RoomSide.top,
            offsetMeters: 0,
            lengthMeters: effectiveRoom.layout.widthMeters,
          )
        : null;
    return HouseEnvelopeElement(
      id: 'house-element-${construction.id}',
      roomId: roomId,
      title: construction.title,
      elementKind: construction.elementKind,
      areaSquareMeters: construction.elementKind == ConstructionElementKind.wall
          ? effectiveRoom.layout.widthMeters * effectiveRoom.heightMeters
          : defaultHouseElementAreaSquareMeters,
      construction: construction.copyWith(),
      sourceConstructionId: construction.id,
      sourceConstructionTitle: construction.title,
      wallOrientation: construction.elementKind == ConstructionElementKind.wall
          ? WallOrientation.north
          : null,
      wallPlacement: wallPlacement,
    );
  }

  final String id;
  final String roomId;
  final String title;
  final ConstructionElementKind elementKind;
  final double areaSquareMeters;
  final Construction construction;
  final String? sourceConstructionId;
  final String? sourceConstructionTitle;
  final WallOrientation? wallOrientation;
  final EnvelopeWallPlacement? wallPlacement;

  String get constructionId => sourceConstructionId ?? construction.id;

  HouseEnvelopeElement copyWith({
    String? id,
    String? roomId,
    String? title,
    ConstructionElementKind? elementKind,
    double? areaSquareMeters,
    Construction? construction,
    String? sourceConstructionId,
    String? sourceConstructionTitle,
    WallOrientation? wallOrientation,
    EnvelopeWallPlacement? wallPlacement,
    bool clearWallOrientation = false,
    bool clearWallPlacement = false,
  }) {
    return HouseEnvelopeElement(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      title: title ?? this.title,
      elementKind: elementKind ?? this.elementKind,
      areaSquareMeters: areaSquareMeters ?? this.areaSquareMeters,
      construction: construction ?? this.construction,
      sourceConstructionId: sourceConstructionId ?? this.sourceConstructionId,
      sourceConstructionTitle:
          sourceConstructionTitle ?? this.sourceConstructionTitle,
      wallOrientation: clearWallOrientation
          ? null
          : wallOrientation ?? this.wallOrientation,
      wallPlacement: clearWallPlacement
          ? null
          : wallPlacement ?? this.wallPlacement,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roomId': roomId,
    'title': title,
    'elementKind': elementKind.storageKey,
    'areaSquareMeters': areaSquareMeters,
    'construction': construction.toJson(),
    'sourceConstructionId': sourceConstructionId,
    'sourceConstructionTitle': sourceConstructionTitle,
    'wallOrientation': wallOrientation?.storageKey,
    'wallPlacement': wallPlacement?.toJson(),
  };
}

class EnvelopeOpening {
  const EnvelopeOpening({
    required this.id,
    required this.elementId,
    required this.title,
    required this.kind,
    required this.areaSquareMeters,
    required this.heatTransferCoefficient,
  });

  factory EnvelopeOpening.fromJson(Map<String, dynamic> json) =>
      EnvelopeOpening(
        id: json['id'] as String,
        elementId: json['elementId'] as String,
        title: json['title'] as String,
        kind: parseOpeningKind(json['kind'] as String),
        areaSquareMeters: (json['areaSquareMeters'] as num).toDouble(),
        heatTransferCoefficient:
            (json['heatTransferCoefficient'] as num?)?.toDouble() ??
            parseOpeningKind(
              json['kind'] as String,
            ).defaultHeatTransferCoefficient,
      );

  final String id;
  final String elementId;
  final String title;
  final OpeningKind kind;
  final double areaSquareMeters;
  final double heatTransferCoefficient;

  EnvelopeOpening copyWith({
    String? id,
    String? elementId,
    String? title,
    OpeningKind? kind,
    double? areaSquareMeters,
    double? heatTransferCoefficient,
  }) {
    return EnvelopeOpening(
      id: id ?? this.id,
      elementId: elementId ?? this.elementId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      areaSquareMeters: areaSquareMeters ?? this.areaSquareMeters,
      heatTransferCoefficient:
          heatTransferCoefficient ?? this.heatTransferCoefficient,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'elementId': elementId,
    'title': title,
    'kind': kind.storageKey,
    'areaSquareMeters': areaSquareMeters,
    'heatTransferCoefficient': heatTransferCoefficient,
  };
}

class HeatingDevice {
  const HeatingDevice({
    required this.id,
    required this.roomId,
    required this.title,
    required this.kind,
    required this.ratedPowerWatts,
    this.catalogItemId,
    this.notes,
  });

  factory HeatingDevice.fromJson(Map<String, dynamic> json) => HeatingDevice(
    id: json['id'] as String,
    roomId: (json['roomId'] as String?) ?? defaultRoomId,
    title: json['title'] as String,
    kind: parseHeatingDeviceKind(
      (json['kind'] as String?) ?? HeatingDeviceKind.other.storageKey,
    ),
    ratedPowerWatts: (json['ratedPowerWatts'] as num).toDouble(),
    catalogItemId: json['catalogItemId'] as String?,
    notes: json['notes'] as String?,
  );

  final String id;
  final String roomId;
  final String title;
  final HeatingDeviceKind kind;
  final double ratedPowerWatts;
  final String? catalogItemId;
  final String? notes;

  HeatingDevice copyWith({
    String? id,
    String? roomId,
    String? title,
    HeatingDeviceKind? kind,
    double? ratedPowerWatts,
    String? catalogItemId,
    String? notes,
    bool clearCatalogItemId = false,
    bool clearNotes = false,
  }) {
    return HeatingDevice(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      ratedPowerWatts: ratedPowerWatts ?? this.ratedPowerWatts,
      catalogItemId: clearCatalogItemId
          ? null
          : catalogItemId ?? this.catalogItemId,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roomId': roomId,
    'title': title,
    'kind': kind.storageKey,
    'ratedPowerWatts': ratedPowerWatts,
    'catalogItemId': catalogItemId,
    'notes': notes,
  };
}

class HouseModel {
  const HouseModel({
    required this.id,
    required this.title,
    required this.rooms,
    required this.elements,
    required this.openings,
    this.heatingDevices = const [],
  });

  factory HouseModel.fromJson(
    Map<String, dynamic> json, {
    List<Construction> availableConstructions = const [],
  }) {
    final roomsJson = (json['rooms'] as List<dynamic>?) ?? const [];
    final rooms = roomsJson
        .map((item) => Room.fromJson(_asJsonMap(item)))
        .toList(growable: false);
    final elements = (json['elements'] as List<dynamic>)
        .map(
          (item) => HouseEnvelopeElement.fromJson(
            _asJsonMap(item),
            availableConstructions: availableConstructions,
          ),
        )
        .toList(growable: false);
    final openings = ((json['openings'] as List<dynamic>?) ?? const [])
        .map((item) => EnvelopeOpening.fromJson(_asJsonMap(item)))
        .toList(growable: false);
    final heatingDevices =
        ((json['heatingDevices'] as List<dynamic>?) ?? const [])
            .map((item) => HeatingDevice.fromJson(_asJsonMap(item)))
            .toList(growable: false);
    return HouseModel(
      id: json['id'] as String,
      title: json['title'] as String,
      rooms: rooms.isEmpty ? [Room.defaultRoom()] : rooms,
      elements: elements.isEmpty && rooms.isEmpty
          ? const []
          : elements
                .map(
                  (item) => item.copyWith(
                    roomId: rooms.isEmpty ? defaultRoomId : item.roomId,
                  ),
                )
                .toList(growable: false),
      openings: openings,
      heatingDevices: rooms.isEmpty && heatingDevices.isEmpty
          ? const []
          : heatingDevices
                .map(
                  (item) => item.copyWith(
                    roomId: rooms.isEmpty ? defaultRoomId : item.roomId,
                  ),
                )
                .toList(growable: false),
    );
  }

  factory HouseModel.bootstrapFromConstructions(
    List<Construction> constructions,
  ) {
    final defaultRoom = Room.defaultRoom();
    return HouseModel(
      id: 'house-model',
      title: 'Конструктор дома',
      rooms: [defaultRoom],
      elements: constructions
          .map(
            (construction) => HouseEnvelopeElement.fromConstruction(
              construction,
              room: defaultRoom,
            ),
          )
          .toList(growable: false),
      openings: const [],
      heatingDevices: const [],
    );
  }

  final String id;
  final String title;
  final List<Room> rooms;
  final List<HouseEnvelopeElement> elements;
  final List<EnvelopeOpening> openings;
  final List<HeatingDevice> heatingDevices;

  double get totalRoomAreaSquareMeters =>
      rooms.fold(0, (sum, room) => sum + room.areaSquareMeters);

  double get totalEnvelopeAreaSquareMeters =>
      elements.fold(0, (sum, element) => sum + element.areaSquareMeters);

  double get totalOpeningAreaSquareMeters =>
      openings.fold(0, (sum, opening) => sum + opening.areaSquareMeters);

  HouseModel copyWith({
    String? id,
    String? title,
    List<Room>? rooms,
    List<HouseEnvelopeElement>? elements,
    List<EnvelopeOpening>? openings,
    List<HeatingDevice>? heatingDevices,
  }) {
    return HouseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      rooms: rooms ?? this.rooms,
      elements: elements ?? this.elements,
      openings: openings ?? this.openings,
      heatingDevices: heatingDevices ?? this.heatingDevices,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'rooms': rooms.map((item) => item.toJson()).toList(growable: false),
    'elements': elements.map((item) => item.toJson()).toList(growable: false),
    'openings': openings.map((item) => item.toJson()).toList(growable: false),
    'heatingDevices': heatingDevices
        .map((item) => item.toJson())
        .toList(growable: false),
  };
}

class DesignObject {
  const DesignObject({
    required this.id,
    required this.title,
    required this.address,
    required this.description,
    required this.customerPhone,
    required this.climatePointId,
    required this.projectId,
    required this.updatedAtEpochMs,
  });

  factory DesignObject.fromJson(Map<String, dynamic> json) => DesignObject(
    id: json['id'] as String,
    title: json['title'] as String,
    address: json['address'] as String? ?? '',
    description: json['description'] as String? ?? '',
    customerPhone: json['customerPhone'] as String? ?? '',
    climatePointId: json['climatePointId'] as String? ?? 'moscow',
    projectId: json['projectId'] as String,
    updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String title;
  final String address;
  final String description;
  final String customerPhone;
  final String climatePointId;
  final String projectId;
  final int updatedAtEpochMs;

  DesignObject copyWith({
    String? id,
    String? title,
    String? address,
    String? description,
    String? customerPhone,
    String? climatePointId,
    String? projectId,
    int? updatedAtEpochMs,
  }) {
    return DesignObject(
      id: id ?? this.id,
      title: title ?? this.title,
      address: address ?? this.address,
      description: description ?? this.description,
      customerPhone: customerPhone ?? this.customerPhone,
      climatePointId: climatePointId ?? this.climatePointId,
      projectId: projectId ?? this.projectId,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'address': address,
    'description': description,
    'customerPhone': customerPhone,
    'climatePointId': climatePointId,
    'projectId': projectId,
    'updatedAtEpochMs': updatedAtEpochMs,
  };
}

class HeatingEconomicsSettings {
  const HeatingEconomicsSettings({
    this.electricityPricePerKwh = defaultElectricityPricePerKwh,
    this.gasPricePerCubicMeter = defaultGasPricePerCubicMeter,
    this.gasBoilerEfficiency = defaultGasBoilerEfficiency,
    this.heatPumpCop = defaultHeatPumpCop,
  });

  factory HeatingEconomicsSettings.fromJson(Map<String, dynamic> json) {
    return HeatingEconomicsSettings(
      electricityPricePerKwh:
          (json['electricityPricePerKwh'] as num?)?.toDouble() ??
          defaultElectricityPricePerKwh,
      gasPricePerCubicMeter:
          (json['gasPricePerCubicMeter'] as num?)?.toDouble() ??
          defaultGasPricePerCubicMeter,
      gasBoilerEfficiency:
          (json['gasBoilerEfficiency'] as num?)?.toDouble() ??
          defaultGasBoilerEfficiency,
      heatPumpCop:
          (json['heatPumpCop'] as num?)?.toDouble() ?? defaultHeatPumpCop,
    );
  }

  final double electricityPricePerKwh;
  final double gasPricePerCubicMeter;
  final double gasBoilerEfficiency;
  final double heatPumpCop;

  HeatingEconomicsSettings copyWith({
    double? electricityPricePerKwh,
    double? gasPricePerCubicMeter,
    double? gasBoilerEfficiency,
    double? heatPumpCop,
  }) {
    return HeatingEconomicsSettings(
      electricityPricePerKwh:
          electricityPricePerKwh ?? this.electricityPricePerKwh,
      gasPricePerCubicMeter:
          gasPricePerCubicMeter ?? this.gasPricePerCubicMeter,
      gasBoilerEfficiency: gasBoilerEfficiency ?? this.gasBoilerEfficiency,
      heatPumpCop: heatPumpCop ?? this.heatPumpCop,
    );
  }

  Map<String, dynamic> toJson() => {
    'electricityPricePerKwh': electricityPricePerKwh,
    'gasPricePerCubicMeter': gasPricePerCubicMeter,
    'gasBoilerEfficiency': gasBoilerEfficiency,
    'heatPumpCop': heatPumpCop,
  };
}

class ProjectConstructionSelection {
  const ProjectConstructionSelection({
    required this.constructionId,
    this.includedInCalculation = true,
  });

  factory ProjectConstructionSelection.fromJson(Map<String, dynamic> json) {
    return ProjectConstructionSelection(
      constructionId: json['constructionId'] as String,
      includedInCalculation: json['includedInCalculation'] as bool? ?? true,
    );
  }

  final String constructionId;
  final bool includedInCalculation;

  ProjectConstructionSelection copyWith({
    String? constructionId,
    bool? includedInCalculation,
  }) {
    return ProjectConstructionSelection(
      constructionId: constructionId ?? this.constructionId,
      includedInCalculation:
          includedInCalculation ?? this.includedInCalculation,
    );
  }

  Map<String, dynamic> toJson() => {
    'constructionId': constructionId,
    'includedInCalculation': includedInCalculation,
  };
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.climatePointId,
    required this.roomPreset,
    required this.constructions,
    this.customMaterials = const [],
    required this.houseModel,
    this.selectedConstructionIds = const [],
    this.projectConstructionSelections = const [],
    this.groundFloorCalculations = const [],
    this.heatingEconomicsSettings = const HeatingEconomicsSettings(),
    this.showBuildingStepRoomsOnboarding = true,
    this.datasetVersion,
    this.migratedFromDatasetVersion,
    this.sourceProjectFormatVersion = currentProjectFormatVersion,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    final formatVersion = (json['projectFormatVersion'] as num?)?.toInt() ?? 1;
    if (formatVersion > currentProjectFormatVersion) {
      throw StateError('Unsupported projectFormatVersion: $formatVersion');
    }

    final constructions = (json['constructions'] as List<dynamic>)
        .map((item) => Construction.fromJson(_asJsonMap(item)))
        .toList(growable: false);
    final houseModelJson = json['houseModel'];
    final groundFloorCalculations =
        ((json['groundFloorCalculations'] as List<dynamic>?) ?? const [])
            .map((item) => GroundFloorCalculation.fromJson(_asJsonMap(item)))
            .toList(growable: false);
    final heatingEconomicsSettingsJson = json['heatingEconomicsSettings'];

    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      climatePointId: json['climatePointId'] as String,
      roomPreset: parseRoomPreset(json['roomPreset'] as String),
      constructions: constructions,
      customMaterials: ((json['customMaterials'] as List<dynamic>?) ?? const [])
          .map((item) => MaterialEntry.fromJson(_asJsonMap(item)))
          .toList(growable: false),
      houseModel: houseModelJson == null
          ? HouseModel.bootstrapFromConstructions(constructions)
          : HouseModel.fromJson(
              _asJsonMap(houseModelJson),
              availableConstructions: constructions,
            ),
      selectedConstructionIds:
          ((json['selectedConstructionIds'] as List<dynamic>?) ?? const [])
              .map((item) => item as String)
              .toList(growable: false),
      projectConstructionSelections:
          ((json['projectConstructionSelections'] as List<dynamic>?) ??
                  const [])
              .map(
                (item) =>
                    ProjectConstructionSelection.fromJson(_asJsonMap(item)),
              )
              .toList(growable: false),
      groundFloorCalculations: groundFloorCalculations,
      heatingEconomicsSettings: heatingEconomicsSettingsJson == null
          ? const HeatingEconomicsSettings()
          : HeatingEconomicsSettings.fromJson(
              _asJsonMap(heatingEconomicsSettingsJson),
            ),
      showBuildingStepRoomsOnboarding:
          json['showBuildingStepRoomsOnboarding'] as bool? ?? true,
      datasetVersion: json['datasetVersion'] as String?,
      migratedFromDatasetVersion: json['migratedFromDatasetVersion'] as String?,
      sourceProjectFormatVersion: formatVersion,
    );
  }

  final String id;
  final String name;
  final String climatePointId;
  final RoomPreset roomPreset;
  final List<Construction> constructions;
  final List<MaterialEntry> customMaterials;
  final HouseModel houseModel;
  final List<String> selectedConstructionIds;
  final List<ProjectConstructionSelection> projectConstructionSelections;
  final List<GroundFloorCalculation> groundFloorCalculations;
  final HeatingEconomicsSettings heatingEconomicsSettings;
  final bool showBuildingStepRoomsOnboarding;
  final String? datasetVersion;
  final String? migratedFromDatasetVersion;
  final int sourceProjectFormatVersion;

  List<ProjectConstructionSelection>
  get effectiveProjectConstructionSelections {
    if (projectConstructionSelections.isNotEmpty) {
      return projectConstructionSelections;
    }
    if (selectedConstructionIds.isNotEmpty) {
      return selectedConstructionIds
          .map(
            (constructionId) =>
                ProjectConstructionSelection(constructionId: constructionId),
          )
          .toList(growable: false);
    }
    return constructions
        .map(
          (construction) =>
              ProjectConstructionSelection(constructionId: construction.id),
        )
        .toList(growable: false);
  }

  List<String> get effectiveSelectedConstructionIds =>
      effectiveProjectConstructionSelections
          .map((item) => item.constructionId)
          .toList(growable: false);

  List<String> get activeSelectedConstructionIds => [
    for (final item in effectiveProjectConstructionSelections)
      if (item.includedInCalculation) item.constructionId,
  ];

  bool get hasDatasetMigration => migratedFromDatasetVersion != null;

  String? get datasetMigrationLabel {
    final migratedFrom = migratedFromDatasetVersion;
    final datasetVersion = this.datasetVersion;
    if (migratedFrom == null || datasetVersion == null) {
      return null;
    }
    return 'Проект обновлен с версии $migratedFrom на $datasetVersion';
  }

  Project copyWith({
    String? id,
    String? name,
    String? climatePointId,
    RoomPreset? roomPreset,
    List<Construction>? constructions,
    List<MaterialEntry>? customMaterials,
    HouseModel? houseModel,
    List<String>? selectedConstructionIds,
    List<ProjectConstructionSelection>? projectConstructionSelections,
    List<GroundFloorCalculation>? groundFloorCalculations,
    HeatingEconomicsSettings? heatingEconomicsSettings,
    bool? showBuildingStepRoomsOnboarding,
    String? datasetVersion,
    String? migratedFromDatasetVersion,
    int? sourceProjectFormatVersion,
    bool clearMigratedFromDatasetVersion = false,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      climatePointId: climatePointId ?? this.climatePointId,
      roomPreset: roomPreset ?? this.roomPreset,
      constructions: constructions ?? this.constructions,
      customMaterials: customMaterials ?? this.customMaterials,
      houseModel: houseModel ?? this.houseModel,
      selectedConstructionIds:
          selectedConstructionIds ?? this.selectedConstructionIds,
      projectConstructionSelections:
          projectConstructionSelections ?? this.projectConstructionSelections,
      groundFloorCalculations:
          groundFloorCalculations ?? this.groundFloorCalculations,
      heatingEconomicsSettings:
          heatingEconomicsSettings ?? this.heatingEconomicsSettings,
      showBuildingStepRoomsOnboarding:
          showBuildingStepRoomsOnboarding ??
          this.showBuildingStepRoomsOnboarding,
      datasetVersion: datasetVersion ?? this.datasetVersion,
      migratedFromDatasetVersion: clearMigratedFromDatasetVersion
          ? null
          : migratedFromDatasetVersion ?? this.migratedFromDatasetVersion,
      sourceProjectFormatVersion:
          sourceProjectFormatVersion ?? this.sourceProjectFormatVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'projectFormatVersion': currentProjectFormatVersion,
    'id': id,
    'name': name,
    'climatePointId': climatePointId,
    'roomPreset': roomPreset.storageKey,
    'constructions': constructions
        .map((item) => item.toJson())
        .toList(growable: false),
    'customMaterials': customMaterials
        .map((item) => item.toJson())
        .toList(growable: false),
    'houseModel': houseModel.toJson(),
    'selectedConstructionIds': effectiveSelectedConstructionIds,
    'projectConstructionSelections': effectiveProjectConstructionSelections
        .map((item) => item.toJson())
        .toList(growable: false),
    'groundFloorCalculations': groundFloorCalculations
        .map((item) => item.toJson())
        .toList(growable: false),
    'heatingEconomicsSettings': heatingEconomicsSettings.toJson(),
    'showBuildingStepRoomsOnboarding': showBuildingStepRoomsOnboarding,
    'datasetVersion': datasetVersion,
    'migratedFromDatasetVersion': migratedFromDatasetVersion,
  };
}

Map<String, dynamic> _asJsonMap(Object? value) {
  return Map<String, dynamic>.from(value! as Map);
}

Construction _resolveElementConstruction(
  Map<String, dynamic> json, {
  List<Construction> availableConstructions = const [],
}) {
  final constructionJson = json['construction'];
  if (constructionJson != null) {
    return Construction.fromJson(_asJsonMap(constructionJson));
  }

  final sourceConstructionId = json['sourceConstructionId'] as String? ??
      json['constructionId'] as String?;
  if (sourceConstructionId != null) {
    for (final item in availableConstructions) {
      if (item.id == sourceConstructionId) {
        return item.copyWith();
      }
    }
  }

  return Construction(
    id: sourceConstructionId ?? 'missing-construction',
    title: json['sourceConstructionTitle'] as String? ??
        json['title'] as String? ??
        'Конструкция не найдена',
    elementKind: parseConstructionElementKind(json['elementKind'] as String),
    layers: const [],
  );
}
