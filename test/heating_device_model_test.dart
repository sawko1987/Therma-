import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';

void main() {
  test('HeatingDevice JSON round-trips supply and return valve fields', () {
    const device = HeatingDevice(
      id: 'device-1',
      roomId: 'room-1',
      title: 'Радиатор',
      kind: HeatingDeviceKind.radiator,
      ratedPowerWatts: 1200,
      supplyValveCatalogItemId: 'supply',
      supplyValveSetting: '3',
      supplyValvePressureDropKpa: 7.5,
      returnValveCatalogItemId: 'return',
      returnValveSetting: '2',
      returnValvePressureDropKpa: 4.2,
      valveCatalogItemId: 'supply',
      valveSetting: '3',
      valvePressureDropKpa: 11.7,
    );

    final restored = HeatingDevice.fromJson(device.toJson());

    expect(restored.supplyValveCatalogItemId, 'supply');
    expect(restored.supplyValveSetting, '3');
    expect(restored.supplyValvePressureDropKpa, 7.5);
    expect(restored.returnValveCatalogItemId, 'return');
    expect(restored.returnValveSetting, '2');
    expect(restored.returnValvePressureDropKpa, 4.2);
    expect(restored.valvePressureDropKpa, 11.7);
  });

  test('HeatingDevice maps legacy single valve to supply side', () {
    final restored = HeatingDevice.fromJson({
      'id': 'device-1',
      'roomId': 'room-1',
      'title': 'Радиатор',
      'kind': 'radiator',
      'ratedPowerWatts': 1200,
      'valveCatalogItemId': 'legacy-valve',
      'valveSetting': '4',
      'valvePressureDropKpa': 9.1,
    });

    expect(restored.supplyValveCatalogItemId, 'legacy-valve');
    expect(restored.supplyValveSetting, '4');
    expect(restored.supplyValvePressureDropKpa, 9.1);
    expect(restored.returnValveCatalogItemId, isNull);
  });
}
