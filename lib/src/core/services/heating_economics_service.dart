import '../models/building_heat_loss.dart';
import '../models/catalog.dart';
import '../models/heating_economics.dart';
import '../models/project.dart';
import 'interfaces.dart';

const double gasLowerHeatingValueKwhPerCubicMeter = 9.3;

class NormativeHeatingEconomicsService implements HeatingEconomicsService {
  const NormativeHeatingEconomicsService();

  @override
  Future<HeatingEconomicsResult> calculate({
    required CatalogSnapshot catalog,
    required Project project,
    required BuildingHeatLossResult buildingHeatLoss,
  }) async {
    final climate = catalog.climatePoints.firstWhere(
      (item) => item.id == project.climatePointId,
      orElse: () => throw StateError(
        'Climate point ${project.climatePointId} is missing from the catalog.',
      ),
    );
    final averageIndoorTemperature = _resolveAverageIndoorTemperature(
      buildingHeatLoss,
    );
    final designDeltaTemperature =
        averageIndoorTemperature - climate.designTemperature;
    final seasonalDeltaTemperature =
        averageIndoorTemperature - climate.averageHeatingSeasonTemperature;
    final seasonalHeatDemandKwh =
        designDeltaTemperature <= 0 || seasonalDeltaTemperature <= 0
        ? 0.0
        : buildingHeatLoss.totalHeatLossWatts /
              1000 *
              24 *
              climate.heatingPeriodDays *
              (seasonalDeltaTemperature / designDeltaTemperature);
    final averageMonthlySeasonLength = climate.heatingPeriodDays / 30.0;
    final settings = project.heatingEconomicsSettings;

    final electricityEnergyInputKwh = seasonalHeatDemandKwh;
    final electricitySeasonalCost =
        electricityEnergyInputKwh * settings.electricityPricePerKwh;

    final gasEnergyInputKwh =
        seasonalHeatDemandKwh / settings.gasBoilerEfficiency;
    final gasConsumptionCubicMeters =
        gasEnergyInputKwh / gasLowerHeatingValueKwhPerCubicMeter;
    final gasSeasonalCost =
        gasConsumptionCubicMeters * settings.gasPricePerCubicMeter;

    final heatPumpEnergyInputKwh = seasonalHeatDemandKwh / settings.heatPumpCop;
    final heatPumpSeasonalCost =
        heatPumpEnergyInputKwh * settings.electricityPricePerKwh;

    return HeatingEconomicsResult(
      seasonalHeatDemandKwh: seasonalHeatDemandKwh,
      averageIndoorTemperature: averageIndoorTemperature,
      designDeltaTemperature: designDeltaTemperature,
      seasonalDeltaTemperature: seasonalDeltaTemperature,
      heatingPeriodDays: climate.heatingPeriodDays,
      averageMonthlySeasonLength: averageMonthlySeasonLength,
      electricity: HeatingSourceEconomicsResult(
        energyInputKwh: electricityEnergyInputKwh,
        seasonalCost: electricitySeasonalCost,
        averageMonthlyCost:
            electricitySeasonalCost / averageMonthlySeasonLength,
      ),
      gas: HeatingSourceEconomicsResult(
        energyInputKwh: gasEnergyInputKwh,
        gasConsumptionCubicMeters: gasConsumptionCubicMeters,
        seasonalCost: gasSeasonalCost,
        averageMonthlyCost: gasSeasonalCost / averageMonthlySeasonLength,
      ),
      heatPump: HeatingSourceEconomicsResult(
        energyInputKwh: heatPumpEnergyInputKwh,
        seasonalCost: heatPumpSeasonalCost,
        averageMonthlyCost: heatPumpSeasonalCost / averageMonthlySeasonLength,
      ),
    );
  }

  double _resolveAverageIndoorTemperature(
    BuildingHeatLossResult buildingHeatLoss,
  ) {
    if (buildingHeatLoss.roomResults.isEmpty ||
        buildingHeatLoss.totalHeatLossWatts <= 0) {
      return 20;
    }
    final weightedTemperature = buildingHeatLoss.roomResults.fold<double>(
      0,
      (sum, room) => sum + room.insideAirTemperature * room.heatLossWatts,
    );
    return weightedTemperature / buildingHeatLoss.totalHeatLossWatts;
  }
}
