import '../models/building_heat_loss.dart';
import '../models/calculation.dart';
import '../models/catalog.dart';
import '../models/project.dart';
import 'interfaces.dart';

class NormativeBuildingHeatLossService implements BuildingHeatLossService {
  const NormativeBuildingHeatLossService(this._engine);

  final ThermalCalculationEngine _engine;

  @override
  Future<BuildingHeatLossResult> calculate({
    required CatalogSnapshot catalog,
    required Project project,
  }) async {
    final climate = catalog.climatePoints.firstWhere(
      (point) => point.id == project.climatePointId,
      orElse: () => throw StateError(
        'Climate point ${project.climatePointId} is missing from the catalog.',
      ),
    );
    final openingsByElementId = <String, List<EnvelopeOpening>>{};
    for (final opening in project.houseModel.openings) {
      openingsByElementId.putIfAbsent(opening.elementId, () => []).add(opening);
    }

    final roomResults = <BuildingRoomHeatLossResult>[];
    final unresolvedElements = <HouseEnvelopeElement>[];

    for (final room in project.houseModel.rooms) {
      final roomElements = project.houseModel.elements
          .where((item) => item.roomId == room.id)
          .toList(growable: false);
      final roomElementIds = roomElements.map((item) => item.id).toSet();
      final roomOpenings = project.houseModel.openings
          .where((item) => roomElementIds.contains(item.elementId))
          .toList(growable: false);
      final roomHeatingDevices = project.houseModel.heatingDevices
          .where((item) => item.roomId == room.id)
          .toList(growable: false);
      final elementResults = <BuildingElementHeatLossResult>[];
      final roomUnresolvedElements = <HouseEnvelopeElement>[];
      final outsideAirTemperature = climate.designTemperature;
      final insideAirTemperature = room.comfortTemperatureC;
      final deltaTemperature = insideAirTemperature - outsideAirTemperature;

      for (final element in roomElements) {
        final construction = element.construction;

        final result = await _engine.calculate(
          catalog: catalog,
          project: project,
          construction: construction,
        );
        if (!result.scenarioStatus.isDirectlySupported) {
          roomUnresolvedElements.add(element);
          unresolvedElements.add(element);
          continue;
        }
        final elementOpenings =
            openingsByElementId[element.id] ?? const <EnvelopeOpening>[];
        final openingArea = elementOpenings.fold<double>(
          0,
          (sum, item) => sum + item.areaSquareMeters,
        );
        final orientationFactor =
            element.elementKind == ConstructionElementKind.wall
            ? (element.wallOrientation?.heatLossFactor ?? 1.0)
            : 1.0;
        final opaqueArea = (element.areaSquareMeters - openingArea).clamp(
          0.0,
          element.areaSquareMeters,
        );
        final opaqueHeatLoss =
            deltaTemperature / result.totalResistance * opaqueArea * orientationFactor;
        final openingHeatLoss = elementOpenings.fold<double>(
          0,
          (sum, item) =>
              sum +
              deltaTemperature *
                  item.heatTransferCoefficient *
                  item.areaSquareMeters *
                  orientationFactor,
        );

        elementResults.add(
          BuildingElementHeatLossResult(
            element: element,
            room: room,
            construction: construction,
            openingCount: elementOpenings.length,
            elementAreaSquareMeters: element.areaSquareMeters,
            opaqueAreaSquareMeters: opaqueArea,
            openingAreaSquareMeters: openingArea,
            insideAirTemperature: insideAirTemperature,
            outsideAirTemperature: outsideAirTemperature,
            deltaTemperature: deltaTemperature,
            totalResistance: result.totalResistance,
            opaqueHeatLossWatts: opaqueHeatLoss,
            openingHeatLossWatts: openingHeatLoss,
          ),
        );
      }

      final heatLossWatts = elementResults.fold<double>(
        0,
        (sum, item) => sum + item.totalHeatLossWatts,
      );
      final opaqueHeatLossWatts = elementResults.fold<double>(
        0,
        (sum, item) => sum + item.opaqueHeatLossWatts,
      );
      final openingHeatLossWatts = elementResults.fold<double>(
        0,
        (sum, item) => sum + item.openingHeatLossWatts,
      );
      final ventilationHeatLossWatts =
          0.335 * room.ventilationSupplyM3h * deltaTemperature;
      final totalEnvelopeAreaSquareMeters = roomElements.fold<double>(
        0,
        (sum, item) => sum + item.areaSquareMeters,
      );
      final totalOpeningAreaSquareMeters = roomOpenings.fold<double>(
        0,
        (sum, item) => sum + item.areaSquareMeters,
      );
      final installedHeatingPowerWatts = roomHeatingDevices.fold<double>(
        0,
        (sum, item) => sum + item.ratedPowerWatts,
      );

      roomResults.add(
        BuildingRoomHeatLossResult(
          room: room,
          elementResults: List.unmodifiable(elementResults),
          unresolvedElements: List.unmodifiable(roomUnresolvedElements),
          elementCount: roomElements.length,
          openingCount: roomOpenings.length,
          heatingDeviceCount: roomHeatingDevices.length,
          totalEnvelopeAreaSquareMeters: totalEnvelopeAreaSquareMeters,
          totalOpaqueAreaSquareMeters:
              (totalEnvelopeAreaSquareMeters - totalOpeningAreaSquareMeters).clamp(
                0.0,
                totalEnvelopeAreaSquareMeters,
              ),
          totalOpeningAreaSquareMeters: totalOpeningAreaSquareMeters,
          insideAirTemperature: insideAirTemperature,
          outsideAirTemperature: outsideAirTemperature,
          heatLossWatts: heatLossWatts + ventilationHeatLossWatts,
          opaqueHeatLossWatts: opaqueHeatLossWatts,
          openingHeatLossWatts: openingHeatLossWatts,
          ventilationHeatLossWatts: ventilationHeatLossWatts,
          installedHeatingPowerWatts: installedHeatingPowerWatts,
          heatingPowerDeltaWatts:
              installedHeatingPowerWatts -
              (heatLossWatts + ventilationHeatLossWatts),
        ),
      );
    }

    return BuildingHeatLossResult(
      roomResults: List.unmodifiable(roomResults),
      totalHeatLossWatts: roomResults.fold<double>(
        0,
        (sum, item) => sum + item.heatLossWatts,
      ),
      totalEnvelopeAreaSquareMeters:
          project.houseModel.totalEnvelopeAreaSquareMeters,
      totalOpaqueAreaSquareMeters: roomResults.fold<double>(
        0,
        (sum, item) => sum + item.totalOpaqueAreaSquareMeters,
      ),
      totalOpeningAreaSquareMeters:
          project.houseModel.totalOpeningAreaSquareMeters,
      totalRoomAreaSquareMeters: project.houseModel.totalRoomAreaSquareMeters,
      totalOpeningCount: project.houseModel.openings.length,
      totalOpaqueHeatLossWatts: roomResults.fold<double>(
        0,
        (sum, item) => sum + item.opaqueHeatLossWatts,
      ),
      totalOpeningHeatLossWatts: roomResults.fold<double>(
        0,
        (sum, item) => sum + item.openingHeatLossWatts,
      ),
      totalVentilationHeatLossWatts: roomResults.fold<double>(
        0,
        (sum, item) => sum + item.ventilationHeatLossWatts,
      ),
      totalHeatingDeviceCount: project.houseModel.heatingDevices.length,
      totalInstalledHeatingPowerWatts: roomResults.fold<double>(
        0,
        (sum, item) => sum + item.installedHeatingPowerWatts,
      ),
      totalHeatingPowerDeltaWatts: roomResults.fold<double>(
        0,
        (sum, item) => sum + item.heatingPowerDeltaWatts,
      ),
      outsideAirTemperature: climate.designTemperature,
      unresolvedElements: List.unmodifiable(unresolvedElements),
    );
  }
}
