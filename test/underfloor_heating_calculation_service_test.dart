import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/services/underfloor_heating_calculation_service.dart';

void main() {
  const service = UnderfloorHeatingCalculationService();

  UnderfloorHeatingCalculation input({
    double area = 15,
    double pitch = 200,
    double supply = 7.5,
    double diameter = 16,
    double heatFlux = 70,
    double flow = 40,
    double ret = 35,
    double floor = 27,
  }) {
    return UnderfloorHeatingCalculation(
      id: 'loop',
      roomId: defaultRoomId,
      title: 'Loop',
      areaSquareMeters: area,
      pipePitchMm: pitch,
      supplyLengthMeters: supply,
      pipeOuterDiameterMm: diameter,
      flowTempC: flow,
      returnTempC: ret,
      roomTempC: 20,
      floorSurfaceTempC: floor,
      heatFluxWattsPerSquareMeter: heatFlux,
      actualPowerWatts: 0,
    );
  }

  test('calculates loop length and rounds balancing flow to 0.5 l/min', () {
    final result = service.calculate(input());

    expect(result.loopLengthMeters, closeTo(90, 0.001));
    expect(result.actualPowerWatts, 1050);
    expect(result.flowRateLitersPerMinute, closeTo(3.02, 0.02));
    expect(result.balancingFlowRateLitersPerMinute, 3.0);
  });

  test('warns on long 16 mm loop and floor surface limit', () {
    final result = service.calculate(
      input(area: 18, pitch: 150, supply: 5, floor: 30),
      roomKind: RoomKind.livingRoom,
    );

    expect(result.loopLengthMeters, closeTo(130, 0.001));
    expect(result.warnings.any((item) => item.contains('выше 80 м')), isTrue);
    expect(
      result.warnings.any((item) => item.contains('выше лимита 29')),
      isTrue,
    );
  });

  test('warns on high pressure drop', () {
    final result = service.calculate(
      input(area: 20, pitch: 100, supply: 10, heatFlux: 120, flow: 40, ret: 35),
    );

    expect(result.pressureDropKpa, greaterThan(20));
    expect(
      result.warnings.any((item) => item.contains('Потери давления')),
      isTrue,
    );
  });
}
