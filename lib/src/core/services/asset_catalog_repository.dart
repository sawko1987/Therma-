import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/catalog.dart';
import 'interfaces.dart';

class AssetCatalogRepository implements CatalogRepository {
  const AssetCatalogRepository(this.bundle);

  final AssetBundle bundle;

  @override
  Future<CatalogSnapshot> loadSnapshot() async {
    final climateRaw = await bundle.loadString('assets/data/climate.seed.json');
    final materialsRaw =
        await bundle.loadString('assets/data/materials.seed.json');
    final normsRaw = await bundle.loadString('assets/data/norms.seed.json');

    final climate = (jsonDecode(climateRaw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ClimatePoint.fromJson)
        .toList();
    final materials = (jsonDecode(materialsRaw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MaterialEntry.fromJson)
        .toList();
    final norms = (jsonDecode(normsRaw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(NormReference.fromJson)
        .toList();

    return CatalogSnapshot(
      climatePoints: climate,
      materials: materials,
      norms: norms,
      datasetVersion: 'seed-2026-03-27',
    );
  }
}
