import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/services/project_migration_service.dart';

import 'support/fakes.dart';

void main() {
  test(
    'migrate materializes opening width and height from legacy area payload',
    () {
      final project = buildTestProject(
        houseModel: HouseModel(
          id: 'house-model',
          title: 'Конструктор дома',
          rooms: [Room.defaultRoom()],
          elements: [
            buildEnvelopeElement(
              id: 'element-wall',
              title: 'Стена',
              areaSquareMeters: 10.8,
              construction: buildWallConstruction(),
              wallPlacement: buildWallPlacement(lengthMeters: 4),
            ),
          ],
          openings: [
            buildOpening(
              id: 'opening-window',
              elementId: 'element-wall',
              title: 'Окно',
              widthMeters: 1.2,
              heightMeters: 1.4,
            ),
          ],
        ),
      );
      final legacyPayload = project.toJson();
      legacyPayload['projectFormatVersion'] = 19;
      final openings =
          ((legacyPayload['houseModel'] as Map<String, dynamic>)['openings']
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      openings[0]
        ..remove('widthMeters')
        ..remove('heightMeters')
        ..remove('catalogTypeId')
        ..['areaSquareMeters'] = 1.68;

      final restored = Project.fromJson(legacyPayload);
      final migrated = const ProjectMigrationService().migrate(restored);
      final opening = migrated.project.houseModel.openings.single;

      expect(migrated.wasMigrated, isTrue);
      expect(
        migrated.project.sourceProjectFormatVersion,
        currentProjectFormatVersion,
      );
      expect(opening.widthMeters, closeTo(1.296, 0.001));
      expect(opening.heightMeters, closeTo(1.296, 0.001));
      expect(opening.areaSquareMeters, closeTo(1.68, 0.001));
    },
  );

  test('opening type entry reads legacy width and height as default hints', () {
    final entry = OpeningTypeEntry.fromJson({
      'id': 'legacy-window',
      'kind': 'window',
      'title': 'ПВХ окно 1200x1400',
      'subcategory': 'ПВХ окна',
      'manufacturer': 'REHAU',
      'widthMeters': 1.2,
      'heightMeters': 1.4,
      'heatTransferCoefficient': 1.0,
      'sourceUrl': 'https://example.com',
      'sourceLabel': 'Legacy source',
      'sourceCheckedAt': '2026-04-13',
    });

    expect(entry.defaultWidthMeters, 1.2);
    expect(entry.defaultHeightMeters, 1.4);
    expect(entry.toJson()['defaultWidthMeters'], 1.2);
    expect(entry.toJson()['defaultHeightMeters'], 1.4);
  });

  test('envelope opening json round-trips installation width', () {
    final opening = buildOpening(
      widthMeters: 1.2,
      installationWidthMeters: 1.1,
    );

    final restored = EnvelopeOpening.fromJson(opening.toJson());

    expect(restored.widthMeters, 1.2);
    expect(restored.installationWidthMeters, 1.1);
    expect(restored.effectiveInstallationWidthMeters, 1.1);
  });

  test(
    'envelope opening falls back to width as effective installation width',
    () {
      final payload = buildOpening(widthMeters: 1.3).toJson()
        ..remove('installationWidthMeters');

      final restored = EnvelopeOpening.fromJson(payload);

      expect(restored.installationWidthMeters, isNull);
      expect(restored.effectiveInstallationWidthMeters, 1.3);
    },
  );

  test(
    'migrate format 20 initializes underfloor loops and heat source fields',
    () {
      final project = buildTestProject();
      final payload = project.toJson();
      payload['projectFormatVersion'] = 20;
      final houseModel = payload['houseModel'] as Map<String, dynamic>;
      houseModel.remove('underfloorHeatingCalculations');
      payload.remove('heatingSystemParameters');

      final restored = Project.fromJson(payload);
      final migrated = const ProjectMigrationService().migrate(restored);

      expect(migrated.wasMigrated, isTrue);
      expect(
        migrated.project.houseModel.underfloorHeatingCalculations,
        isEmpty,
      );
      expect(migrated.project.heatingSystemParameters, isNull);
      expect(
        migrated.project.sourceProjectFormatVersion,
        currentProjectFormatVersion,
      );
    },
  );

  test('migrate format 21 leaves new radiator calculation fields empty', () {
    final project = buildTestProject(
      houseModel: buildHouseModel(heatingDevices: [buildHeatingDevice()]),
    );
    final payload = project.toJson();
    payload['projectFormatVersion'] = 21;
    final devices =
        ((payload['houseModel'] as Map<String, dynamic>)['heatingDevices']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    devices.single
      ..remove('valveCatalogItemId')
      ..remove('valveSetting')
      ..remove('designFlowRateLitersPerMinute')
      ..remove('valvePressureDropKpa')
      ..remove('calculatedPowerWatts')
      ..remove('requiredPowerWatts');

    final restored = Project.fromJson(payload);
    final migrated = const ProjectMigrationService().migrate(restored);
    final device = migrated.project.houseModel.heatingDevices.single;

    expect(migrated.wasMigrated, isTrue);
    expect(device.valveCatalogItemId, isNull);
    expect(device.designFlowRateLitersPerMinute, isNull);
    expect(device.calculatedPowerWatts, isNull);
    expect(
      migrated.project.sourceProjectFormatVersion,
      currentProjectFormatVersion,
    );
  });

  test('migrate format 22 maps legacy radiator valve to supply side', () {
    final project = buildTestProject(
      houseModel: buildHouseModel(
        heatingDevices: [
          buildHeatingDevice(
            valveCatalogItemId: 'legacy-valve',
            valveSetting: '2',
            valvePressureDropKpa: 6.5,
          ),
        ],
      ),
    );
    final payload = project.toJson();
    payload['projectFormatVersion'] = 22;
    final devices =
        ((payload['houseModel'] as Map<String, dynamic>)['heatingDevices']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    devices.single
      ..remove('supplyValveCatalogItemId')
      ..remove('supplyValveSetting')
      ..remove('supplyValvePressureDropKpa')
      ..remove('returnValveCatalogItemId')
      ..remove('returnValveSetting')
      ..remove('returnValvePressureDropKpa');

    final restored = Project.fromJson(payload);
    final migrated = const ProjectMigrationService().migrate(restored);
    final device = migrated.project.houseModel.heatingDevices.single;

    expect(migrated.wasMigrated, isTrue);
    expect(device.supplyValveCatalogItemId, 'legacy-valve');
    expect(device.supplyValveSetting, '2');
    expect(device.supplyValvePressureDropKpa, 6.5);
    expect(device.returnValveCatalogItemId, isNull);
    expect(
      migrated.project.sourceProjectFormatVersion,
      currentProjectFormatVersion,
    );
  });
}
