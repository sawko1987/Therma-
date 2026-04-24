import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/features/settings/application/heating_device_filter.dart';

void main() {
  test('heating device seed contains NRZ and Oasis only', () {
    final raw = File(
      'assets/data/heating_devices.seed.json',
    ).readAsStringSync();
    final entries = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(HeatingDeviceCatalogEntry.fromJson)
        .toList(growable: false);

    expect(entries.length, greaterThanOrEqualTo(40));
    expect(entries.map((entry) => entry.manufacturer), contains('НРЗ'));
    expect(entries.map((entry) => entry.manufacturer), contains('Оазис'));
    expect(
      entries.map((entry) => entry.manufacturer),
      isNot(contains('Oasis')),
    );
    expect(
      entries.map((entry) => entry.manufacturer),
      isNot(contains('Stelrad')),
    );

    final oasisPanels = entries.where((entry) => entry.manufacturer == 'Оазис');
    expect(oasisPanels, isNotEmpty);
    expect(oasisPanels.every((entry) => entry.sectionCount == null), isTrue);
    expect(oasisPanels.every((entry) => entry.panelType != null), isTrue);
  });

  test('heating device catalog entry round-trips extended fields', () {
    const entry = HeatingDeviceCatalogEntry(
      id: 'device',
      kind: 'radiator',
      title: 'НРЗ Профи',
      ratedPowerWatts: 1200,
      manufacturer: 'НРЗ',
      series: 'Профи',
      model: 'РА 500/100',
      sectionCount: 6,
      waterVolumePerSection: 0.4,
      workingPressureBar: 16,
    );

    final restored = HeatingDeviceCatalogEntry.fromJson(entry.toJson());

    expect(restored.series, 'Профи');
    expect(restored.waterVolumePerSection, 0.4);
    expect(restored.workingPressureBar, 16);
  });

  test(
    'heating device filter handles manufacturer, ranges, query and custom',
    () {
      const seedNrz = HeatingDeviceCatalogItem(
        source: HeatingDeviceCatalogSource.seed,
        entry: HeatingDeviceCatalogEntry(
          id: 'nrz',
          kind: 'radiator',
          title: 'НРЗ Люкс 2.0 РА 500/100, 6 секций',
          manufacturer: 'НРЗ',
          series: 'Люкс 2.0',
          model: 'РА 500/100',
          sectionCount: 6,
          heightMm: 500,
          ratedPowerWatts: 1200,
        ),
      );
      const seedOasis = HeatingDeviceCatalogItem(
        source: HeatingDeviceCatalogSource.seed,
        entry: HeatingDeviceCatalogEntry(
          id: 'oasis',
          kind: 'radiator',
          title: 'Оазис Pro 22 500x600',
          manufacturer: 'Оазис',
          series: 'Pro',
          model: '22/500/600',
          heightMm: 500,
          panelType: '22',
          ratedPowerWatts: 1442,
        ),
      );
      const custom = HeatingDeviceCatalogItem(
        source: HeatingDeviceCatalogSource.custom,
        entry: HeatingDeviceCatalogEntry(
          id: 'custom',
          kind: 'radiator',
          title: 'Мой радиатор',
          manufacturer: 'НРЗ',
          series: 'Профи',
          model: 'РА 350/100',
          sectionCount: 8,
          heightMm: 430,
          ratedPowerWatts: 1600,
        ),
      );
      const items = [seedNrz, seedOasis, custom];

      expect(
        applyHeatingDeviceFilter(
          items,
          const HeatingDeviceFilter(manufacturer: 'НРЗ'),
        ).map((item) => item.entry.id),
        ['custom', 'nrz'],
      );
      expect(
        applyHeatingDeviceFilter(
          items,
          const HeatingDeviceFilter(minHeightMm: 450, maxHeightMm: 550),
        ).map((item) => item.entry.id),
        ['nrz', 'oasis'],
      );
      expect(
        applyHeatingDeviceFilter(
          items,
          const HeatingDeviceFilter(query: 'профи'),
        ).map((item) => item.entry.id),
        ['custom'],
      );
      expect(
        applyHeatingDeviceFilter(
          items,
          const HeatingDeviceFilter(showCustomOnly: true),
        ).single.entry.id,
        'custom',
      );
      expect(
        applyHeatingDeviceFilter(
          items,
          const HeatingDeviceFilter(minSections: 6, maxSections: 6),
        ).single.entry.id,
        'nrz',
      );
    },
  );
}
