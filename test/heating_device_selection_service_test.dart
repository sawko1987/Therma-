import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
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
}
