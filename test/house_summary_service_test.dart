import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
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
          elements: [
            buildEnvelopeElement(
              id: 'element-wall',
              title: 'Наружная стена',
              areaSquareMeters: 20,
              construction: buildWallConstruction(),
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
      expect(summary.totalOpeningHeatLossWatts, closeTo(202.4, 2));
      expect(summary.totalHeatLossWatts, closeTo(348.172, 3));
      expect(summary.totalHeatingDeviceCount, 1);
      expect(summary.totalInstalledHeatingPowerWatts, 450);
      expect(summary.totalHeatingPowerDeltaWatts, closeTo(101.828, 3));
      expect(summary.roomResults.single.totalOpaqueAreaSquareMeters, 16);
      expect(summary.roomResults.single.installedHeatingPowerWatts, 450);
    },
  );

  test(
    'building heat loss uses room comfort temperature for indoor temperature',
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
              comfortTemperatureC: 20,
            ),
            buildRoom(
              id: 'bedroom',
              title: 'Спальня',
              kind: RoomKind.bedroom,
              comfortTemperatureC: 18,
              layout: buildRoomLayout(xMeters: 6, yMeters: 0),
            ),
          ],
          elements: [
            buildEnvelopeElement(
              id: 'element-living',
              roomId: 'living',
              title: 'Стена гостиной',
              areaSquareMeters: 10,
              construction: buildWallConstruction(),
            ),
            buildEnvelopeElement(
              id: 'element-bedroom',
              roomId: 'bedroom',
              title: 'Стена спальни',
              areaSquareMeters: 10,
              construction: buildWallConstruction(),
            ),
          ],
          openings: const [],
        ),
      );
      final catalog = CatalogSnapshot(
        climatePoints: testCatalogSnapshot.climatePoints,
        materials: testCatalogSnapshot.materials,
        constructionTemplates: testCatalogSnapshot.constructionTemplates,
        norms: testCatalogSnapshot.norms,
        moistureRules: testCatalogSnapshot.moistureRules,
        roomKindConditions: const [
          RoomKindCondition(roomKindId: 'livingRoom', insideTemperature: 20),
          RoomKindCondition(roomKindId: 'bedroom', insideTemperature: 18),
        ],
        heatingDevices: testCatalogSnapshot.heatingDevices,
        openingCatalog: testCatalogSnapshot.openingCatalog,
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
            buildEnvelopeElement(
              id: 'element-wall',
              title: 'Наружная стена',
              areaSquareMeters: 10,
              construction: buildWallConstruction(),
            ),
            buildEnvelopeElement(
              id: 'element-floor',
              roomId: defaultRoomId,
              title: 'Пол над подвалом',
              areaSquareMeters: 16,
              construction: floor,
              elementKind: ConstructionElementKind.floor,
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
}
