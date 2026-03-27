import 'dart:math';

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

class CalculationResult {
  const CalculationResult({
    required this.totalResistance,
    required this.heatLossPerSqm,
    required this.layerRows,
    required this.temperatureSeries,
    required this.humiditySeries,
    required this.complianceIndicators,
  });

  final double totalResistance;
  final double heatLossPerSqm;
  final List<LayerCalculationRow> layerRows;
  final GraphSeries temperatureSeries;
  final GraphSeries humiditySeries;
  final List<ComplianceIndicator> complianceIndicators;
}
