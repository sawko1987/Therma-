import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/catalog.dart';
import '../models/project.dart';
import '../models/versioning.dart';
import 'interfaces.dart';

class AssetCatalogRepository implements CatalogRepository {
  const AssetCatalogRepository(this.bundle);

  final AssetBundle bundle;

  @override
  Future<CatalogSnapshot> loadSnapshot() async {
    final climateRaw = await bundle.loadString('assets/data/climate.seed.json');
    final materialsRaw = await bundle.loadString(
      'assets/data/materials.seed.json',
    );
    final constructionTemplatesRaw = await bundle.loadString(
      'assets/data/construction_templates.seed.json',
    );
    final normsRaw = await bundle.loadString('assets/data/norms.seed.json');
    final moistureRulesRaw = await bundle.loadString(
      'assets/data/moisture_rules.seed.json',
    );
    final roomKindConditionsRaw = await bundle.loadString(
      'assets/data/room_kind_conditions.seed.json',
    );
    final heatingDevicesRaw = await bundle.loadString(
      'assets/data/heating_devices.seed.json',
    );

    final climate = (jsonDecode(climateRaw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ClimatePoint.fromJson)
        .toList();
    final materials = (jsonDecode(materialsRaw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MaterialEntry.fromJson)
        .toList();
    final constructionTemplates =
        (jsonDecode(constructionTemplatesRaw) as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(Construction.fromJson)
            .toList();
    final norms = (jsonDecode(normsRaw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(NormReference.fromJson)
        .toList();
    final moistureRules = MoistureRuleSet.fromJson(
      jsonDecode(moistureRulesRaw) as Map<String, dynamic>,
    );
    final roomKindConditions =
        (jsonDecode(roomKindConditionsRaw) as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(RoomKindCondition.fromJson)
            .toList();
    final heatingDevices = (jsonDecode(heatingDevicesRaw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(HeatingDeviceCatalogEntry.fromJson)
        .toList();

    return CatalogSnapshot(
      climatePoints: climate,
      materials: materials,
      constructionTemplates: constructionTemplates,
      norms: norms,
      moistureRules: moistureRules,
      roomKindConditions: roomKindConditions,
      heatingDevices: heatingDevices,
      datasetVersion: currentDatasetVersion,
    );
  }
}
