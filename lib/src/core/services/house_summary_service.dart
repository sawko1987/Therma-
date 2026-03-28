import '../models/catalog.dart';
import '../models/project.dart';
import 'interfaces.dart';

class RoomThermalSummary {
  const RoomThermalSummary({
    required this.room,
    required this.elementCount,
    required this.openingCount,
    required this.heatingDeviceCount,
    required this.totalEnvelopeAreaSquareMeters,
    required this.totalOpaqueAreaSquareMeters,
    required this.totalOpeningAreaSquareMeters,
    required this.heatLossWatts,
    required this.opaqueHeatLossWatts,
    required this.openingHeatLossWatts,
    required this.installedHeatingPowerWatts,
    required this.heatingPowerDeltaWatts,
  });

  final Room room;
  final int elementCount;
  final int openingCount;
  final int heatingDeviceCount;
  final double totalEnvelopeAreaSquareMeters;
  final double totalOpaqueAreaSquareMeters;
  final double totalOpeningAreaSquareMeters;
  final double heatLossWatts;
  final double opaqueHeatLossWatts;
  final double openingHeatLossWatts;
  final double installedHeatingPowerWatts;
  final double heatingPowerDeltaWatts;
}

class HouseThermalSummary {
  const HouseThermalSummary({
    required this.roomSummaries,
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
  });

  final List<RoomThermalSummary> roomSummaries;
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
}

class HouseSummaryService {
  const HouseSummaryService(this._engine);

  final ThermalCalculationEngine _engine;

  Future<HouseThermalSummary> buildSummary({
    required CatalogSnapshot catalog,
    required Project project,
  }) async {
    final constructionMap = {
      for (final construction in project.constructions) construction.id: construction,
    };
    final roomSummaries = <RoomThermalSummary>[];

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
      var roomHeatLossWatts = 0.0;
      var roomOpaqueHeatLossWatts = 0.0;
      var roomOpeningHeatLossWatts = 0.0;

      for (final element in roomElements) {
        final construction = constructionMap[element.constructionId];
        if (construction == null) {
          continue;
        }
        final elementOpenings = project.houseModel.openings
            .where((item) => item.elementId == element.id)
            .toList(growable: false);
        final openingArea = elementOpenings.fold<double>(
          0,
          (sum, item) => sum + item.areaSquareMeters,
        );
        final opaqueArea = (element.areaSquareMeters - openingArea).clamp(
          0.0,
          element.areaSquareMeters,
        );
        final result = await _engine.calculate(
          catalog: catalog,
          project: project,
          construction: construction,
        );
        final deltaT =
            result.insideAirTemperature - result.outsideAirTemperature;
        final opaqueHeatLoss =
            deltaT / result.totalResistance * opaqueArea;
        final openingHeatLoss = elementOpenings.fold<double>(
          0,
          (sum, item) =>
              sum + deltaT * item.heatTransferCoefficient * item.areaSquareMeters,
        );
        roomOpaqueHeatLossWatts += opaqueHeatLoss;
        roomOpeningHeatLossWatts += openingHeatLoss;
        roomHeatLossWatts += opaqueHeatLoss + openingHeatLoss;
      }

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
      roomSummaries.add(
        RoomThermalSummary(
          room: room,
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
          heatLossWatts: roomHeatLossWatts,
          opaqueHeatLossWatts: roomOpaqueHeatLossWatts,
          openingHeatLossWatts: roomOpeningHeatLossWatts,
          installedHeatingPowerWatts: installedHeatingPowerWatts,
          heatingPowerDeltaWatts:
              installedHeatingPowerWatts - roomHeatLossWatts,
        ),
      );
    }

    final totalHeatLossWatts = roomSummaries.fold<double>(
      0,
      (sum, item) => sum + item.heatLossWatts,
    );
    return HouseThermalSummary(
      roomSummaries: roomSummaries,
      totalHeatLossWatts: totalHeatLossWatts,
      totalEnvelopeAreaSquareMeters:
          project.houseModel.totalEnvelopeAreaSquareMeters,
      totalOpaqueAreaSquareMeters: roomSummaries.fold<double>(
        0,
        (sum, item) => sum + item.totalOpaqueAreaSquareMeters,
      ),
      totalOpeningAreaSquareMeters:
          project.houseModel.totalOpeningAreaSquareMeters,
      totalRoomAreaSquareMeters: project.houseModel.totalRoomAreaSquareMeters,
      totalOpeningCount: project.houseModel.openings.length,
      totalOpaqueHeatLossWatts: roomSummaries.fold<double>(
        0,
        (sum, item) => sum + item.opaqueHeatLossWatts,
      ),
      totalOpeningHeatLossWatts: roomSummaries.fold<double>(
        0,
        (sum, item) => sum + item.openingHeatLossWatts,
      ),
      totalHeatingDeviceCount: project.houseModel.heatingDevices.length,
      totalInstalledHeatingPowerWatts: roomSummaries.fold<double>(
        0,
        (sum, item) => sum + item.installedHeatingPowerWatts,
      ),
      totalHeatingPowerDeltaWatts: roomSummaries.fold<double>(
        0,
        (sum, item) => sum + item.heatingPowerDeltaWatts,
      ),
    );
  }
}
