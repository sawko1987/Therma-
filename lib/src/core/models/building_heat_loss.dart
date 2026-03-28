import 'project.dart';

class BuildingElementHeatLossResult {
  const BuildingElementHeatLossResult({
    required this.element,
    required this.room,
    required this.construction,
    required this.openingCount,
    required this.elementAreaSquareMeters,
    required this.opaqueAreaSquareMeters,
    required this.openingAreaSquareMeters,
    required this.insideAirTemperature,
    required this.outsideAirTemperature,
    required this.deltaTemperature,
    required this.totalResistance,
    required this.opaqueHeatLossWatts,
    required this.openingHeatLossWatts,
  });

  final HouseEnvelopeElement element;
  final Room room;
  final Construction construction;
  final int openingCount;
  final double elementAreaSquareMeters;
  final double opaqueAreaSquareMeters;
  final double openingAreaSquareMeters;
  final double insideAirTemperature;
  final double outsideAirTemperature;
  final double deltaTemperature;
  final double totalResistance;
  final double opaqueHeatLossWatts;
  final double openingHeatLossWatts;

  double get totalHeatLossWatts => opaqueHeatLossWatts + openingHeatLossWatts;
}

class BuildingRoomHeatLossResult {
  const BuildingRoomHeatLossResult({
    required this.room,
    required this.elementResults,
    required this.unresolvedElements,
    required this.elementCount,
    required this.openingCount,
    required this.heatingDeviceCount,
    required this.totalEnvelopeAreaSquareMeters,
    required this.totalOpaqueAreaSquareMeters,
    required this.totalOpeningAreaSquareMeters,
    required this.insideAirTemperature,
    required this.outsideAirTemperature,
    required this.heatLossWatts,
    required this.opaqueHeatLossWatts,
    required this.openingHeatLossWatts,
    required this.installedHeatingPowerWatts,
    required this.heatingPowerDeltaWatts,
  });

  final Room room;
  final List<BuildingElementHeatLossResult> elementResults;
  final List<HouseEnvelopeElement> unresolvedElements;
  final int elementCount;
  final int openingCount;
  final int heatingDeviceCount;
  final double totalEnvelopeAreaSquareMeters;
  final double totalOpaqueAreaSquareMeters;
  final double totalOpeningAreaSquareMeters;
  final double insideAirTemperature;
  final double outsideAirTemperature;
  final double heatLossWatts;
  final double opaqueHeatLossWatts;
  final double openingHeatLossWatts;
  final double installedHeatingPowerWatts;
  final double heatingPowerDeltaWatts;
}

class BuildingHeatLossResult {
  const BuildingHeatLossResult({
    required this.roomResults,
    required this.totalHeatLossWatts,
    required this.totalEnvelopeAreaSquareMeters,
    required this.totalOpaqueAreaSquareMeters,
    required this.totalOpeningAreaSquareMeters,
    required this.totalRoomAreaSquareMeters,
    required this.totalOpeningCount,
    required this.totalOpaqueHeatLossWatts,
    required this.totalOpeningHeatLossWatts,
    required this.totalHeatingDeviceCount,
    required this.totalInstalledHeatingPowerWatts,
    required this.totalHeatingPowerDeltaWatts,
    required this.outsideAirTemperature,
    required this.unresolvedElements,
  });

  final List<BuildingRoomHeatLossResult> roomResults;
  final double totalHeatLossWatts;
  final double totalEnvelopeAreaSquareMeters;
  final double totalOpaqueAreaSquareMeters;
  final double totalOpeningAreaSquareMeters;
  final double totalRoomAreaSquareMeters;
  final int totalOpeningCount;
  final double totalOpaqueHeatLossWatts;
  final double totalOpeningHeatLossWatts;
  final int totalHeatingDeviceCount;
  final double totalInstalledHeatingPowerWatts;
  final double totalHeatingPowerDeltaWatts;
  final double outsideAirTemperature;
  final List<HouseEnvelopeElement> unresolvedElements;

  int get totalRoomCount => roomResults.length;
  int get totalElementCount =>
      roomResults.fold(0, (sum, item) => sum + item.elementCount);
}
