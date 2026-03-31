import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/building_heat_loss.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/services/heating_economics_service.dart';

import 'support/fakes.dart';

void main() {
  test('heating economics uses climate season and project tariffs', () async {
    const service = NormativeHeatingEconomicsService();
    final project = buildTestProject().copyWith(
      heatingEconomicsSettings: const HeatingEconomicsSettings(
        electricityPricePerKwh: 8,
        gasPricePerCubicMeter: 9,
        gasBoilerEfficiency: 0.9,
        heatPumpCop: 4,
      ),
    );
    const buildingHeatLoss = BuildingHeatLossResult(
      roomResults: [
        BuildingRoomHeatLossResult(
          room: Room(
            id: 'living',
            title: 'Гостиная',
            kind: RoomKind.livingRoom,
            heightMeters: defaultRoomHeightMeters,
            layout: RoomLayoutRect(
              xMeters: 0,
              yMeters: 0,
              widthMeters: 4,
              heightMeters: 4,
            ),
          ),
          elementResults: [],
          internalHeatTransferResults: [],
          unresolvedElements: [],
          elementCount: 2,
          openingCount: 1,
          heatingDeviceCount: 1,
          totalEnvelopeAreaSquareMeters: 40,
          totalOpaqueAreaSquareMeters: 35,
          totalOpeningAreaSquareMeters: 5,
          insideAirTemperature: 20,
          outsideAirTemperature: -26,
          airChangesPerHour: 0.5,
          roomVolumeCubicMeters: 43.2,
          heatLossWatts: 4600,
          opaqueHeatLossWatts: 3600,
          openingHeatLossWatts: 1000,
          ventilationHeatLossWatts: 0,
          infiltrationHeatLossWatts: 200,
          adjacentRoomHeatGainWatts: 0,
          netHeatingDemandWatts: 4600,
          installedHeatingPowerWatts: 5000,
          heatingPowerDeltaWatts: 400,
        ),
        BuildingRoomHeatLossResult(
          room: Room(
            id: 'bath',
            title: 'Санузел',
            kind: RoomKind.bathroom,
            heightMeters: defaultRoomHeightMeters,
            layout: RoomLayoutRect(
              xMeters: 4,
              yMeters: 0,
              widthMeters: 2,
              heightMeters: 2,
            ),
          ),
          elementResults: [],
          internalHeatTransferResults: [],
          unresolvedElements: [],
          elementCount: 1,
          openingCount: 0,
          heatingDeviceCount: 1,
          totalEnvelopeAreaSquareMeters: 10,
          totalOpaqueAreaSquareMeters: 10,
          totalOpeningAreaSquareMeters: 0,
          insideAirTemperature: 24,
          outsideAirTemperature: -26,
          airChangesPerHour: 1.2,
          roomVolumeCubicMeters: 10.8,
          heatLossWatts: 1400,
          opaqueHeatLossWatts: 1400,
          openingHeatLossWatts: 0,
          ventilationHeatLossWatts: 0,
          infiltrationHeatLossWatts: 100,
          adjacentRoomHeatGainWatts: 0,
          netHeatingDemandWatts: 1400,
          installedHeatingPowerWatts: 1600,
          heatingPowerDeltaWatts: 200,
        ),
      ],
      internalHeatTransferResults: [],
      totalHeatLossWatts: 6000,
      totalEnvelopeAreaSquareMeters: 50,
      totalOpaqueAreaSquareMeters: 45,
      totalOpeningAreaSquareMeters: 5,
      totalRoomAreaSquareMeters: 20,
      totalOpeningCount: 1,
      totalOpaqueHeatLossWatts: 5000,
      totalOpeningHeatLossWatts: 1000,
      totalVentilationHeatLossWatts: 0,
      totalInfiltrationHeatLossWatts: 300,
      totalHeatingDeviceCount: 2,
      totalInstalledHeatingPowerWatts: 6600,
      totalHeatingPowerDeltaWatts: 600,
      outsideAirTemperature: -26,
      unresolvedElements: [],
    );

    final result = await service.calculate(
      catalog: testCatalogSnapshot,
      project: project,
      buildingHeatLoss: buildingHeatLoss,
    );

    expect(result.averageIndoorTemperature, closeTo(20.93, 0.01));
    expect(result.seasonalHeatDemandKwh, closeTo(14479.36, 0.1));
    expect(result.electricity.seasonalCost, closeTo(115834.91, 0.2));
    expect(result.gas.gasConsumptionCubicMeters, closeTo(1729.91, 0.1));
    expect(result.gas.seasonalCost, closeTo(15569.21, 0.2));
    expect(result.heatPump.seasonalCost, closeTo(28958.73, 0.2));
    expect(result.averageMonthlySeasonLength, closeTo(6.8, 0.01));
  });
}
