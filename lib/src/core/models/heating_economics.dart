class HeatingSourceEconomicsResult {
  const HeatingSourceEconomicsResult({
    required this.energyInputKwh,
    required this.seasonalCost,
    required this.averageMonthlyCost,
    this.gasConsumptionCubicMeters,
  });

  final double energyInputKwh;
  final double seasonalCost;
  final double averageMonthlyCost;
  final double? gasConsumptionCubicMeters;
}

class HeatingEconomicsResult {
  const HeatingEconomicsResult({
    required this.seasonalHeatDemandKwh,
    required this.averageIndoorTemperature,
    required this.designDeltaTemperature,
    required this.seasonalDeltaTemperature,
    required this.heatingPeriodDays,
    required this.averageMonthlySeasonLength,
    required this.electricity,
    required this.gas,
    required this.heatPump,
  });

  final double seasonalHeatDemandKwh;
  final double averageIndoorTemperature;
  final double designDeltaTemperature;
  final double seasonalDeltaTemperature;
  final int heatingPeriodDays;
  final double averageMonthlySeasonLength;
  final HeatingSourceEconomicsResult electricity;
  final HeatingSourceEconomicsResult gas;
  final HeatingSourceEconomicsResult heatPump;
}
