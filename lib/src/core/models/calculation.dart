import 'dart:math';

import 'catalog.dart';
import 'project.dart';

class LayerCalculationRow {
  const LayerCalculationRow({
    required this.title,
    required this.thicknessMm,
    required this.resistance,
    required this.tempStart,
    required this.tempEnd,
  });

  final String title;
  final double thicknessMm;
  final double resistance;
  final double tempStart;
  final double tempEnd;
}

class GraphSeries {
  const GraphSeries({
    required this.title,
    required this.points,
  });

  final String title;
  final List<Point<double>> points;
}

class ComplianceIndicator {
  const ComplianceIndicator({
    required this.title,
    required this.actual,
    required this.target,
    required this.isPassed,
  });

  final String title;
  final double actual;
  final double target;
  final bool isPassed;
}

class ConstructionPerformance {
  const ConstructionPerformance({
    required this.constructionId,
    required this.constructionTitle,
    required this.totalResistance,
    required this.uValue,
    required this.layerRows,
    required this.temperatureSeries,
    required this.humiditySeries,
    required this.complianceIndicators,
  });

  final String constructionId;
  final String constructionTitle;
  final double totalResistance;
  final double uValue;
  final List<LayerCalculationRow> layerRows;
  final GraphSeries temperatureSeries;
  final GraphSeries humiditySeries;
  final List<ComplianceIndicator> complianceIndicators;
}

class BuildingCalculationInput {
  const BuildingCalculationInput({
    required this.project,
    required this.climatePoint,
    required this.roomInputs,
  });

  final Project project;
  final ClimatePoint climatePoint;
  final List<RoomCalculationInput> roomInputs;
}

class RoomCalculationInput {
  const RoomCalculationInput({
    required this.room,
    required this.targetTemperatureC,
    required this.airChangesPerHour,
    required this.volumeM3,
    required this.boundaryInputs,
  });

  final Room room;
  final double targetTemperatureC;
  final double airChangesPerHour;
  final double volumeM3;
  final List<BoundaryCalculationInput> boundaryInputs;
}

class BoundaryCalculationInput {
  const BoundaryCalculationInput({
    required this.boundary,
    required this.deltaTemperatureC,
    required this.opaqueAreaM2,
    required this.opaquePerformance,
    required this.openingInputs,
    required this.isIncludedInLosses,
  });

  final RoomBoundary boundary;
  final double deltaTemperatureC;
  final double opaqueAreaM2;
  final ConstructionPerformance opaquePerformance;
  final List<OpeningCalculationInput> openingInputs;
  final bool isIncludedInLosses;
}

class OpeningCalculationInput {
  const OpeningCalculationInput({
    required this.opening,
    required this.deltaTemperatureC,
    required this.performance,
  });

  final Opening opening;
  final double deltaTemperatureC;
  final ConstructionPerformance performance;
}

class OpeningHeatLossResult {
  const OpeningHeatLossResult({
    required this.openingId,
    required this.title,
    required this.kind,
    required this.areaM2,
    required this.heatLossCoefficientWPerK,
    required this.lossW,
    required this.constructionTitle,
  });

  final String openingId;
  final String title;
  final OpeningKind kind;
  final double areaM2;
  final double heatLossCoefficientWPerK;
  final double lossW;
  final String constructionTitle;
}

class BoundaryHeatLossResult {
  const BoundaryHeatLossResult({
    required this.boundaryId,
    required this.title,
    required this.surfaceType,
    required this.boundaryCondition,
    required this.grossAreaM2,
    required this.opaqueAreaM2,
    required this.deltaTemperatureC,
    required this.heatLossCoefficientWPerK,
    required this.lossW,
    required this.opaqueConstructionTitle,
    required this.openings,
  });

  final String boundaryId;
  final String title;
  final SurfaceType surfaceType;
  final BoundaryCondition boundaryCondition;
  final double grossAreaM2;
  final double opaqueAreaM2;
  final double deltaTemperatureC;
  final double heatLossCoefficientWPerK;
  final double lossW;
  final String opaqueConstructionTitle;
  final List<OpeningHeatLossResult> openings;
}

class RoomHeatLossResult {
  const RoomHeatLossResult({
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.targetTemperatureC,
    required this.airChangesPerHour,
    required this.volumeM3,
    required this.transmissionLossW,
    required this.ventilationLossW,
    required this.totalLossW,
    required this.heatLossCoefficientWPerK,
    required this.boundaryResults,
  });

  final String roomId;
  final String roomName;
  final RoomType roomType;
  final double targetTemperatureC;
  final double airChangesPerHour;
  final double volumeM3;
  final double transmissionLossW;
  final double ventilationLossW;
  final double totalLossW;
  final double heatLossCoefficientWPerK;
  final List<BoundaryHeatLossResult> boundaryResults;
}

class BuildingHeatLossResult {
  const BuildingHeatLossResult({
    required this.projectName,
    required this.climatePoint,
    required this.transmissionLossW,
    required this.ventilationLossW,
    required this.totalLossW,
    required this.heatLossCoefficientWPerK,
    required this.roomResults,
  });

  final String projectName;
  final ClimatePoint climatePoint;
  final double transmissionLossW;
  final double ventilationLossW;
  final double totalLossW;
  final double heatLossCoefficientWPerK;
  final List<RoomHeatLossResult> roomResults;
}
