import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/services/heating_device_selection_service.dart';

void main() {
  const service = HeatingDeviceSelectionService();

  test('adjustedPowerWatts uses passport delta T from water mean', () {
    const entry = HeatingDeviceCatalogEntry(
      id: 'section',
      kind: 'radiator',
      title: 'Section',
      ratedPowerWatts: 151,
      sectionCount: 1,
      designFlowTempC: 90,
      designReturnTempC: 70,
      roomTempC: 20,
      heatOutputExponent: 1.25,
    );

    final actual = service.adjustedPowerWatts(
      entry: entry,
      flowTempC: 75,
      returnTempC: 65,
      roomTempC: 20,
    );

    expect(entry.nominalDeltaT, 60);
    expect(actual, closeTo(151 * math.pow(50 / 60, 1.25), 0.001));
  });

  test('selectSectional rounds section count up and stores actual power', () {
    const entry = HeatingDeviceCatalogEntry(
      id: 'oasis',
      kind: 'radiator',
      title: 'Oasis section',
      ratedPowerWatts: 151,
      sectionCount: 1,
      designFlowTempC: 90,
      designReturnTempC: 70,
      roomTempC: 20,
      heatOutputExponent: 1.25,
    );

    final selection = service.selectSectional(
      entry: entry,
      requiredPowerWatts: 1000,
      flowTempC: 90,
      returnTempC: 70,
      roomTempC: 20,
    );

    expect(selection.sectionCount, 7);
    expect(selection.actualPowerWatts, 1057);
  });

  test(
    'selectPanel returns the smallest adjusted type size covering demand',
    () {
      const entries = [
        HeatingDeviceCatalogEntry(
          id: 'small',
          kind: 'radiator',
          title: 'Small',
          ratedPowerWatts: 730,
          widthMm: 1000,
          panelType: '22',
        ),
        HeatingDeviceCatalogEntry(
          id: 'medium',
          kind: 'radiator',
          title: 'Medium',
          ratedPowerWatts: 876,
          widthMm: 1200,
          panelType: '22',
        ),
        HeatingDeviceCatalogEntry(
          id: 'large',
          kind: 'radiator',
          title: 'Large',
          ratedPowerWatts: 1023,
          widthMm: 1400,
          panelType: '22',
        ),
      ];

      final selection = service.selectPanel(
        entries: entries,
        requiredPowerWatts: 850,
        flowTempC: 75,
        returnTempC: 65,
        roomTempC: 20,
      );

      expect(selection?.entry.id, 'medium');
      expect(selection?.actualPowerWatts, 876);
    },
  );

  test('selectPanel filters candidates by max width', () {
    const entries = [
      HeatingDeviceCatalogEntry(
        id: 'wide',
        kind: 'radiator',
        title: 'Wide',
        ratedPowerWatts: 900,
        widthMm: 1400,
        panelType: '22',
      ),
      HeatingDeviceCatalogEntry(
        id: 'fit',
        kind: 'radiator',
        title: 'Fit',
        ratedPowerWatts: 1000,
        widthMm: 1000,
        panelType: '22',
      ),
    ];

    final selection = service.selectPanel(
      entries: entries,
      requiredPowerWatts: 850,
      flowTempC: 75,
      returnTempC: 65,
      roomTempC: 20,
      maxWidthMm: 1200,
    );

    expect(selection?.entry.id, 'fit');
  });

  test('design flow rate changes when supply return delta changes', () {
    final highDelta = service.designFlowRateLitersPerMinute(
      powerWatts: 1000,
      flowTempC: 75,
      returnTempC: 65,
    );
    final lowDelta = service.designFlowRateLitersPerMinute(
      powerWatts: 1000,
      flowTempC: 70,
      returnTempC: 65,
    );

    expect(highDelta, closeTo(1.43, 0.01));
    expect(lowDelta, greaterThan(highDelta));
  });

  test('valve pressure drop is calculated from Kv', () {
    final drop = service.valvePressureDropKpa(
      flowRateLitersPerMinute: 1.0,
      kv: 0.3,
    );

    expect(drop, closeTo(4.0, 0.001));
  });

  test('calculateDevice picks residual load and warns for ball valve', () {
    const radiator = HeatingDeviceCatalogEntry(
      id: 'panel',
      kind: 'radiator',
      title: 'Panel',
      ratedPowerWatts: 1000,
      panelType: '22',
      designFlowTempC: 75,
      designReturnTempC: 65,
      roomTempC: 20,
    );
    const ballValve = HeatingValveCatalogEntry(
      id: 'ball',
      kind: HeatingValveKind.ballValve,
      title: 'Ball',
      connectionDiameterMm: 15,
      kvs: 12,
    );
    const device = HeatingDevice(
      id: 'd1',
      roomId: 'r1',
      title: 'R1',
      kind: HeatingDeviceKind.radiator,
      ratedPowerWatts: 1000,
      catalogItemId: 'panel',
      valveCatalogItemId: 'ball',
      requiredPowerWatts: 700,
    );

    final result = service.calculateDevice(
      device: device,
      deviceCatalog: const [radiator],
      valveCatalog: const [ballValve],
      flowTempC: 75,
      returnTempC: 65,
      roomTempC: 20,
      requiredPowerWatts: 700,
    );

    expect(result.calculatedPowerWatts, 1000);
    expect(result.flowRateLitersPerMinute, closeTo(1.43, 0.01));
    expect(
      result.warnings,
      contains(
        'Подача: шаровый кран не предназначен для балансировки расхода.',
      ),
    );
    expect(result.warnings, contains('Запас мощности выше 25%.'));
  });

  test('calculateDevice selects closest regulating valve setting', () {
    const radiator = HeatingDeviceCatalogEntry(
      id: 'panel',
      kind: 'radiator',
      title: 'Panel',
      ratedPowerWatts: 1000,
      panelType: '22',
    );
    const valve = HeatingValveCatalogEntry(
      id: 'balancing',
      kind: HeatingValveKind.balancingValve,
      title: 'Balancing',
      connectionDiameterMm: 15,
      kvs: 2.5,
      settingKvMap: {'1': 0.1, '2': 0.3, '3': 0.8},
    );
    const device = HeatingDevice(
      id: 'd1',
      roomId: 'r1',
      title: 'R1',
      kind: HeatingDeviceKind.radiator,
      ratedPowerWatts: 1000,
      catalogItemId: 'panel',
      valveCatalogItemId: 'balancing',
    );

    final result = service.calculateDevice(
      device: device,
      deviceCatalog: const [radiator],
      valveCatalog: const [valve],
      flowTempC: 75,
      returnTempC: 65,
      roomTempC: 20,
    );

    expect(result.valveSetting, '2');
    expect(result.valvePressureDropKpa, closeTo(8.16, 0.1));
  });

  test('calculateDevice selects supply and return valves independently', () {
    const radiator = HeatingDeviceCatalogEntry(
      id: 'panel',
      kind: 'radiator',
      title: 'Panel',
      ratedPowerWatts: 1000,
      panelType: '22',
    );
    const supplyValve = HeatingValveCatalogEntry(
      id: 'supply',
      kind: HeatingValveKind.thermostaticValve,
      title: 'Supply',
      connectionDiameterMm: 15,
      kvs: 1.2,
      settingKvMap: {'1': 0.1, '2': 0.3},
    );
    const returnValve = HeatingValveCatalogEntry(
      id: 'return',
      kind: HeatingValveKind.balancingValve,
      title: 'Return',
      connectionDiameterMm: 15,
      kvs: 2.5,
      settingKvMap: {'A': 0.2, 'B': 0.6},
    );
    const device = HeatingDevice(
      id: 'd1',
      roomId: 'r1',
      title: 'R1',
      kind: HeatingDeviceKind.radiator,
      ratedPowerWatts: 1000,
      catalogItemId: 'panel',
      supplyValveCatalogItemId: 'supply',
      supplyValveSetting: '2',
      returnValveCatalogItemId: 'return',
    );

    final result = service.calculateDevice(
      device: device,
      deviceCatalog: const [radiator],
      valveCatalog: const [supplyValve, returnValve],
      flowTempC: 75,
      returnTempC: 65,
      roomTempC: 20,
    );

    expect(result.supplyValveSetting, '2');
    expect(result.returnValveSetting, 'B');
    expect(result.supplyValvePressureDropKpa, closeTo(8.16, 0.1));
    expect(result.returnValvePressureDropKpa, closeTo(2.04, 0.1));
    expect(result.valvePressureDropKpa, closeTo(10.20, 0.1));
  });
}
