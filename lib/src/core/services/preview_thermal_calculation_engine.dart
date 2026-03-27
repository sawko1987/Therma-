import 'dart:math';

import '../models/calculation.dart';
import '../models/catalog.dart';
import '../models/project.dart';
import 'interfaces.dart';

class PreviewThermalCalculationEngine implements ThermalCalculationEngine {
  const PreviewThermalCalculationEngine();

  @override
  Future<CalculationResult> calculate({
    required CatalogSnapshot catalog,
    required Project project,
    required Construction construction,
  }) async {
    final climate = catalog.climatePoints.firstWhere(
      (point) => point.id == project.climatePointId,
    );
    final materialMap = {
      for (final material in catalog.materials) material.id: material,
    };

    final insideTemp = switch (project.roomPreset) {
      RoomPreset.livingRoom => 20.0,
      RoomPreset.attic => 18.0,
      RoomPreset.basement => 16.0,
    };
    final outsideTemp = climate.designTemperature;

    final enabledLayers =
        construction.layers.where((layer) => layer.enabled).toList();
    final layerResistances = enabledLayers.map((layer) {
      final material = materialMap[layer.materialId];
      final lambda = material?.thermalConductivity ?? 0.18;
      return (layer.thicknessMm / 1000.0) / lambda;
    }).toList();

    final totalResistance = layerResistances.fold<double>(0.0, (a, b) => a + b);
    final effectiveResistance = totalResistance == 0 ? 0.1 : totalResistance;
    final delta = insideTemp - outsideTemp;

    var currentResistance = 0.0;
    final rows = <LayerCalculationRow>[];
    final temperaturePoints = <Point<double>>[Point(0, insideTemp)];
    final humidityPoints = <Point<double>>[const Point(0, 55)];
    var currentPosition = 0.0;

    for (var i = 0; i < enabledLayers.length; i++) {
      final layer = enabledLayers[i];
      final material = materialMap[layer.materialId];
      final resistance = layerResistances[i];
      final tempStart =
          insideTemp - delta * (currentResistance / effectiveResistance);
      currentResistance += resistance;
      final tempEnd = insideTemp - delta * (currentResistance / effectiveResistance);
      currentPosition += layer.thicknessMm;

      rows.add(
        LayerCalculationRow(
          title: material?.name ?? layer.materialId,
          thicknessMm: layer.thicknessMm,
          resistance: resistance,
          tempStart: tempStart,
          tempEnd: tempEnd,
        ),
      );

      temperaturePoints.add(Point(currentPosition, tempEnd));
      humidityPoints.add(Point(currentPosition, 55 + i * 7.0));
    }

    final heatLoss = delta / effectiveResistance;

    return CalculationResult(
      totalResistance: totalResistance,
      heatLossPerSqm: heatLoss,
      layerRows: rows,
      temperatureSeries: GraphSeries(
        title: 'Температура',
        points: temperaturePoints,
      ),
      humiditySeries: GraphSeries(
        title: 'Влажность',
        points: humidityPoints,
      ),
      complianceIndicators: [
        ComplianceIndicator(
          title: 'Тепловая защита',
          actual: totalResistance,
          target: 3.2,
          isPassed: totalResistance >= 3.2,
        ),
        ComplianceIndicator(
          title: 'Влагорежим',
          actual: max(0, 100 - heatLoss),
          target: 65,
          isPassed: heatLoss < 35,
        ),
      ],
    );
  }
}
