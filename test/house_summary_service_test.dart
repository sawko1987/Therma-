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
          rooms: [
            Room.defaultRoom(),
          ],
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
      expect(summary.totalOpeningHeatLossWatts, closeTo(172, 2));
      expect(summary.totalHeatLossWatts, closeTo(294, 3));
      expect(summary.totalHeatingDeviceCount, 1);
      expect(summary.totalInstalledHeatingPowerWatts, 450);
      expect(summary.totalHeatingPowerDeltaWatts, closeTo(156, 3));
      expect(summary.roomResults.single.totalOpaqueAreaSquareMeters, 16);
      expect(summary.roomResults.single.installedHeatingPowerWatts, 450);
    },
  );

  test('building heat loss uses room kind conditions for indoor temperature', () async {
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
      norms: testCatalogSnapshot.norms,
      moistureRules: testCatalogSnapshot.moistureRules,
      roomKindConditions: const [
        RoomKindCondition(
          roomKindId: 'livingRoom',
          insideTemperature: 20,
        ),
        RoomKindCondition(
          roomKindId: 'bedroom',
          insideTemperature: 18,
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
  });
}
