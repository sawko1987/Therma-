import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/core/models/ground_floor_calculation.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/services/building_heat_loss_service.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';

import 'support/fakes.dart';

void main() {
  test(
    'building heat loss subtracts openings and tracks heating balance',
    () async {
      final project = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Конструктор дома',
          rooms: [Room.defaultRoom()],
          elements: const [
            HouseEnvelopeElement(
              id: 'element-wall',
              roomId: defaultRoomId,
              title: 'Наружная стена',
              elementKind: ConstructionElementKind.wall,
              areaSquareMeters: 20,
              constructionId: 'wall',
            ),
          ],
          openings: const [
            EnvelopeOpening(
              id: 'opening-window',
              elementId: 'element-wall',
              title: 'Окно',
              kind: OpeningKind.window,
              areaSquareMeters: 4,
              heatTransferCoefficient: 1.0,
            ),
          ],
          heatingDevices: const [
            HeatingDevice(
              id: 'device-radiator',
              roomId: defaultRoomId,
              title: 'Радиатор',
              kind: HeatingDeviceKind.radiator,
              ratedPowerWatts: 450,
            ),
          ],
        ),
      );
      const service = NormativeBuildingHeatLossService(
        NormativeThermalCalculationEngine(),
      );

      final summary = await service.calculate(
        catalog: testCatalogSnapshot,
        project: project,
      );

      expect(summary.totalEnvelopeAreaSquareMeters, 20);
      expect(summary.totalOpeningAreaSquareMeters, 4);
      expect(summary.totalOpaqueAreaSquareMeters, 16);
      expect(summary.totalOpeningCount, 1);
      expect(summary.totalOpeningHeatLossWatts, closeTo(184, 2));
      expect(summary.totalVentilationHeatLossWatts, closeTo(332.86, 0.1));
      expect(summary.totalInfiltrationHeatLossWatts, closeTo(184.92, 0.2));
      expect(summary.totalHeatLossWatts, closeTo(834.30, 0.2));
      expect(summary.totalHeatingDeviceCount, 1);
      expect(summary.totalInstalledHeatingPowerWatts, 450);
      expect(summary.totalHeatingPowerDeltaWatts, closeTo(-384.30, 0.2));
      expect(summary.internalHeatTransferResults, isEmpty);
      expect(summary.roomResults.single.totalOpaqueAreaSquareMeters, 16);
      expect(summary.roomResults.single.installedHeatingPowerWatts, 450);
      expect(
        summary.roomResults.single.ventilationHeatLossWatts,
        closeTo(332.86, 0.1),
      );
      expect(
        summary.roomResults.single.infiltrationHeatLossWatts,
        closeTo(184.92, 0.2),
      );
      expect(summary.roomResults.single.adjacentRoomHeatGainWatts, 0);
      expect(
        summary.roomResults.single.netHeatingDemandWatts,
        closeTo(summary.roomResults.single.heatLossWatts, 0.01),
      );
    },
  );

  test(
    'building heat loss uses room kind conditions for indoor temperature',
    () async {
      final project = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'РљРѕРЅСЃС‚СЂСѓРєС‚РѕСЂ РґРѕРјР°',
          rooms: [
            buildRoom(
              id: 'living',
              title: 'Гостиная',
              kind: RoomKind.livingRoom,
            ),
            buildRoom(
              id: 'bedroom',
              title: 'Спальня',
              kind: RoomKind.bedroom,
              layout: buildRoomLayout(xMeters: 6, yMeters: 0),
            ),
          ],
          elements: const [
            HouseEnvelopeElement(
              id: 'element-living',
              roomId: 'living',
              title: 'Стена гостиной',
              elementKind: ConstructionElementKind.wall,
              areaSquareMeters: 10,
              constructionId: 'wall',
            ),
            HouseEnvelopeElement(
              id: 'element-bedroom',
              roomId: 'bedroom',
              title: 'Стена спальни',
              elementKind: ConstructionElementKind.wall,
              areaSquareMeters: 10,
              constructionId: 'wall',
            ),
          ],
          openings: const [],
        ),
      );
      final catalog = CatalogSnapshot(
        climatePoints: testCatalogSnapshot.climatePoints,
        materials: testCatalogSnapshot.materials,
        constructionTemplates: testCatalogSnapshot.constructionTemplates,
        roomShapeTemplates: testCatalogSnapshot.roomShapeTemplates,
        norms: testCatalogSnapshot.norms,
        moistureRules: testCatalogSnapshot.moistureRules,
        roomKindConditions: const [
          RoomKindCondition(
            roomKindId: 'livingRoom',
            insideTemperature: 20,
            airChangesPerHour: 0.5,
          ),
          RoomKindCondition(
            roomKindId: 'bedroom',
            insideTemperature: 18,
            airChangesPerHour: 0.3,
          ),
        ],
        heatingDevices: testCatalogSnapshot.heatingDevices,
        datasetVersion: testCatalogSnapshot.datasetVersion,
      );
      const service = NormativeBuildingHeatLossService(
        NormativeThermalCalculationEngine(),
      );

      final summary = await service.calculate(
        catalog: catalog,
        project: project,
      );
      final livingRoom = summary.roomResults.firstWhere(
        (item) => item.room.id == 'living',
      );
      final bedroom = summary.roomResults.firstWhere(
        (item) => item.room.id == 'bedroom',
      );

      expect(livingRoom.insideAirTemperature, 20);
      expect(bedroom.insideAirTemperature, 18);
      expect(livingRoom.heatLossWatts, greaterThan(bedroom.heatLossWatts));
      expect(livingRoom.airChangesPerHour, 0.5);
      expect(bedroom.airChangesPerHour, 0.3);
    },
  );

  test(
    'building heat loss includes supported floor scenarios in envelope sum',
    () async {
      final floor = Construction(
        id: 'floor-over-basement',
        title: 'Пол над подвалом',
        elementKind: ConstructionElementKind.floor,
        floorConstructionType: FloorConstructionType.overBasement,
        layers: buildWallConstruction().layers,
      );
      final project = buildTestProject(
        constructions: [buildWallConstruction(), floor],
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Конструктор дома',
          rooms: [Room.defaultRoom()],
          elements: [
            const HouseEnvelopeElement(
              id: 'element-wall',
              roomId: defaultRoomId,
              title: 'Наружная стена',
              elementKind: ConstructionElementKind.wall,
              areaSquareMeters: 10,
              constructionId: 'wall',
            ),
            HouseEnvelopeElement(
              id: 'element-floor',
              roomId: defaultRoomId,
              title: 'Пол над подвалом',
              elementKind: ConstructionElementKind.floor,
              areaSquareMeters: 16,
              constructionId: floor.id,
            ),
          ],
          openings: const [],
        ),
      );
      const service = NormativeBuildingHeatLossService(
        NormativeThermalCalculationEngine(),
      );

      final summary = await service.calculate(
        catalog: testCatalogSnapshot,
        project: project,
      );

      expect(summary.roomResults.single.unresolvedElements, isEmpty);
      expect(summary.totalEnvelopeAreaSquareMeters, 26);
      expect(summary.totalHeatLossWatts, greaterThan(0));
    },
  );

  test(
    'building heat loss resolves on-ground floor through linked ground floor calculation',
    () async {
      final floor = Construction(
        id: 'floor-on-ground',
        title: 'Пол по грунту',
        elementKind: ConstructionElementKind.floor,
        floorConstructionType: FloorConstructionType.onGround,
        layers: buildWallConstruction().layers,
      );
      final project = buildTestProject(
        constructions: [buildWallConstruction(), floor],
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Конструктор дома',
          rooms: [Room.defaultRoom()],
          elements: [
            HouseEnvelopeElement(
              id: 'element-floor',
              roomId: defaultRoomId,
              title: 'Пол комнаты',
              elementKind: ConstructionElementKind.floor,
              areaSquareMeters: 16,
              constructionId: floor.id,
            ),
          ],
          openings: const [],
        ),
        groundFloorCalculations: const [
          GroundFloorCalculation(
            id: 'gf-linked',
            title: 'Связанный пол',
            kind: GroundFloorCalculationKind.slabOnGround,
            constructionId: 'floor-on-ground',
            areaSquareMeters: 16,
            perimeterMeters: 16,
            slabWidthMeters: 4,
            slabLengthMeters: 4,
            edgeInsulationWidthMeters: 0.6,
            edgeInsulationResistance: 1.5,
            houseElementId: 'element-floor',
          ),
        ],
      );
      const service = NormativeBuildingHeatLossService(
        NormativeThermalCalculationEngine(),
      );

      final summary = await service.calculate(
        catalog: testCatalogSnapshot,
        project: project,
      );

      expect(summary.roomResults.single.unresolvedElements, isEmpty);
      expect(summary.totalHeatLossWatts, greaterThan(0));
    },
  );

  test(
    'building heat loss adds ventilation using room volume and air change rate',
    () async {
      final project = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Конструктор дома',
          rooms: [
            buildRoom(
              id: 'bath',
              title: 'Санузел',
              kind: RoomKind.bathroom,
              heightMeters: 2.8,
              layout: const RoomLayoutRect(
                xMeters: 0,
                yMeters: 0,
                widthMeters: 2,
                heightMeters: 2,
              ),
            ),
          ],
          elements: const [],
          openings: const [],
        ),
      );
      const service = NormativeBuildingHeatLossService(
        NormativeThermalCalculationEngine(),
      );

      final summary = await service.calculate(
        catalog: testCatalogSnapshot,
        project: project,
      );
      final room = summary.roomResults.single;

      expect(room.roomVolumeCubicMeters, closeTo(11.2, 0.01));
      expect(room.airChangesPerHour, 1.2);
      expect(room.ventilationHeatLossWatts, closeTo(225.12, 0.2));
      expect(room.infiltrationHeatLossWatts, 0);
      expect(room.heatLossWatts, closeTo(room.ventilationHeatLossWatts, 0.01));
      expect(room.netHeatingDemandWatts, closeTo(room.heatLossWatts, 0.01));
      expect(summary.totalVentilationHeatLossWatts, closeTo(225.12, 0.2));
      expect(summary.totalInfiltrationHeatLossWatts, 0);
    },
  );

  test(
    'building heat loss uses opening leakage preset for infiltration',
    () async {
      final project = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Дом',
          rooms: [Room.defaultRoom()],
          elements: const [
            HouseEnvelopeElement(
              id: 'wall-main',
              roomId: defaultRoomId,
              title: 'Стена',
              elementKind: ConstructionElementKind.wall,
              areaSquareMeters: 12,
              constructionId: 'wall',
            ),
          ],
          openings: const [
            EnvelopeOpening(
              id: 'window-tight',
              elementId: 'wall-main',
              title: 'Окно',
              kind: OpeningKind.window,
              areaSquareMeters: 1,
              heatTransferCoefficient: 1.0,
              leakagePreset: OpeningLeakagePreset.tight,
            ),
            EnvelopeOpening(
              id: 'door-leaky',
              elementId: 'wall-main',
              title: 'Дверь',
              kind: OpeningKind.door,
              areaSquareMeters: 2,
              heatTransferCoefficient: 1.5,
              leakagePreset: OpeningLeakagePreset.leaky,
            ),
          ],
        ),
      );
      const service = NormativeBuildingHeatLossService(
        NormativeThermalCalculationEngine(),
      );

      final summary = await service.calculate(
        catalog: testCatalogSnapshot,
        project: project,
      );

      expect(summary.totalInfiltrationHeatLossWatts, closeTo(200.33, 0.2));
      expect(
        summary.roomResults.single.infiltrationHeatLossWatts,
        closeTo(200.33, 0.2),
      );
    },
  );

  test(
    'building heat loss adds internal heat transfer without changing house total',
    () async {
      final houseModel = HouseModel(
        id: 'house-model',
        title: 'Дом',
        rooms: [
          buildRoom(
            id: 'living',
            title: 'Гостиная',
            kind: RoomKind.livingRoom,
            layout: buildRoomLayout(widthMeters: 4, heightMeters: 4),
          ),
          buildRoom(
            id: 'hall',
            title: 'Холл',
            kind: RoomKind.hall,
            layout: buildRoomLayout(
              xMeters: 4,
              widthMeters: 4,
              heightMeters: 4,
            ),
          ),
        ],
        elements: const [
          HouseEnvelopeElement(
            id: 'living-wall',
            roomId: 'living',
            title: 'Стена гостиной',
            elementKind: ConstructionElementKind.wall,
            areaSquareMeters: 10,
            constructionId: 'wall',
          ),
          HouseEnvelopeElement(
            id: 'hall-wall',
            roomId: 'hall',
            title: 'Стена холла',
            elementKind: ConstructionElementKind.wall,
            areaSquareMeters: 10,
            constructionId: 'wall',
          ),
        ],
        openings: const [],
        internalPartitionConstructionId: 'wall',
      );
      final projectWithoutInternal = buildTestProject(houseModel: houseModel);
      final projectWithInternal = buildTestProject(
        houseModel: houseModel.copyWith(
          internalPartitionConstructionId: 'wall',
        ),
      );
      const service = NormativeBuildingHeatLossService(
        NormativeThermalCalculationEngine(),
      );

      final withoutInternal = await service.calculate(
        catalog: testCatalogSnapshot,
        project: projectWithoutInternal.copyWith(
          houseModel: projectWithoutInternal.houseModel.copyWith(
            clearInternalPartitionConstructionId: true,
          ),
        ),
      );
      final withInternal = await service.calculate(
        catalog: testCatalogSnapshot,
        project: projectWithInternal,
      );
      final living = withInternal.roomResults.firstWhere(
        (item) => item.room.id == 'living',
      );
      final hall = withInternal.roomResults.firstWhere(
        (item) => item.room.id == 'hall',
      );

      expect(
        withInternal.totalHeatLossWatts,
        closeTo(withoutInternal.totalHeatLossWatts, 0.01),
      );
      expect(withInternal.internalHeatTransferResults, hasLength(1));
      expect(
        living.adjacentRoomHeatGainWatts + hall.adjacentRoomHeatGainWatts,
        closeTo(0, 0.01),
      );
      expect(living.adjacentRoomHeatGainWatts, lessThan(0));
      expect(hall.adjacentRoomHeatGainWatts, greaterThan(0));
      expect(living.netHeatingDemandWatts, greaterThan(living.heatLossWatts));
      expect(hall.netHeatingDemandWatts, lessThan(hall.heatLossWatts));
    },
  );

  test(
    'building heat loss uses minimum room height for internal partition area',
    () async {
      final project = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Дом',
          rooms: [
            buildRoom(
              id: 'living',
              title: 'Гостиная',
              kind: RoomKind.livingRoom,
              heightMeters: 3.0,
              layout: buildRoomLayout(widthMeters: 4, heightMeters: 4),
            ),
            buildRoom(
              id: 'hall',
              title: 'Холл',
              kind: RoomKind.hall,
              heightMeters: 2.5,
              layout: buildRoomLayout(
                xMeters: 4,
                widthMeters: 4,
                heightMeters: 4,
              ),
            ),
          ],
          elements: const [],
          openings: const [],
          internalPartitionConstructionId: 'wall',
        ),
      );
      const service = NormativeBuildingHeatLossService(
        NormativeThermalCalculationEngine(),
      );

      final summary = await service.calculate(
        catalog: testCatalogSnapshot,
        project: project,
      );

      expect(summary.internalHeatTransferResults, hasLength(1));
      expect(
        summary.internalHeatTransferResults.single.partitionAreaSquareMeters,
        closeTo(10, 0.01),
      );
    },
  );
}
