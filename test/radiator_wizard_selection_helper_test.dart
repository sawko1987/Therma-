import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/features/heating_devices/presentation/radiator_wizard_sheet.dart';

void main() {
  const helper = RadiatorWizardSelectionHelper();

  const entries = [
    HeatingDeviceCatalogEntry(
      id: 'panel-22-500',
      kind: 'radiator',
      title: 'Panel 22 500',
      ratedPowerWatts: 900,
      panelType: '22',
      heightMm: 500,
      widthMm: 1000,
    ),
    HeatingDeviceCatalogEntry(
      id: 'panel-33-500',
      kind: 'radiator',
      title: 'Panel 33 500',
      ratedPowerWatts: 1200,
      panelType: '33',
      heightMm: 500,
      widthMm: 1000,
    ),
    HeatingDeviceCatalogEntry(
      id: 'panel-22-600',
      kind: 'radiator',
      title: 'Panel 22 600',
      ratedPowerWatts: 1100,
      panelType: '22',
      heightMm: 600,
      widthMm: 1000,
    ),
    HeatingDeviceCatalogEntry(
      id: 'sectional-80-500',
      kind: 'radiator',
      title: 'Sectional 80 500',
      ratedPowerWatts: 600,
      sectionCount: 4,
      widthMm: 320,
      heightMm: 500,
    ),
  ];

  test('panel path filters catalog by panel type and height', () {
    final candidates = helper.panelCandidates(
      entries: entries,
      panelType: '22',
      heightMm: 500,
    );

    expect(candidates.map((entry) => entry.id), ['panel-22-500']);
  });

  test('sectional path filters by section width and height', () {
    final entry = helper.sectionalEntry(
      entries: entries,
      sectionWidthMm: 80,
      heightMm: 500,
    );

    expect(entry?.id, 'sectional-80-500');
    expect(helper.sectionWidth(entry!), 80);
  });

  test('manual entries store panel and single-section catalog data', () {
    final panel = helper.buildManualEntry(
      id: 'device-1',
      type: RadiatorWizardType.panel,
      title: 'Manual panel',
      panelType: '22',
      widthMm: 1200,
      heightMm: 500,
      ratedPowerWatts: 1300,
      flowTempC: 70,
      returnTempC: 55,
      roomTempC: 20,
    );
    final sectional = helper.buildManualEntry(
      id: 'device-2',
      type: RadiatorWizardType.sectional,
      title: 'Manual sectional',
      panelType: '22',
      widthMm: 80,
      heightMm: 500,
      ratedPowerWatts: 150,
      flowTempC: 70,
      returnTempC: 55,
      roomTempC: 20,
    );

    expect(panel.panelType, '22');
    expect(panel.widthMm, 1200);
    expect(panel.heightMm, 500);
    expect(panel.ratedPowerWatts, 1300);
    expect(sectional.sectionCount, 1);
    expect(sectional.widthMm, 80);
    expect(sectional.ratedPowerWatts, 150);
  });
}
