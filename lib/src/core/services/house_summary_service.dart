import '../models/catalog.dart';
import '../models/project.dart';
import 'interfaces.dart';

class RoomThermalSummary {
  const RoomThermalSummary({
    required this.room,
    required this.elementCount,
    required this.totalEnvelopeAreaSquareMeters,
    required this.heatLossWatts,
  });

  final Room room;
  final int elementCount;
  final double totalEnvelopeAreaSquareMeters;
  final double heatLossWatts;
}

class HouseThermalSummary {
  const HouseThermalSummary({
    required this.roomSummaries,
    required this.totalHeatLossWatts,
    required this.totalEnvelopeAreaSquareMeters,
    required this.totalRoomAreaSquareMeters,
  });

  final List<RoomThermalSummary> roomSummaries;
  final double totalHeatLossWatts;
  final double totalEnvelopeAreaSquareMeters;
  final double totalRoomAreaSquareMeters;
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
      var roomHeatLossWatts = 0.0;

      for (final element in roomElements) {
        final construction = constructionMap[element.constructionId];
        if (construction == null) {
          continue;
        }
        final result = await _engine.calculate(
          catalog: catalog,
          project: project,
          construction: construction,
        );
        final deltaT =
            result.insideAirTemperature - result.outsideAirTemperature;
        roomHeatLossWatts += deltaT / result.totalResistance * element.areaSquareMeters;
      }

      final totalEnvelopeAreaSquareMeters = roomElements.fold<double>(
        0,
        (sum, item) => sum + item.areaSquareMeters,
      );
      roomSummaries.add(
        RoomThermalSummary(
          room: room,
          elementCount: roomElements.length,
          totalEnvelopeAreaSquareMeters: totalEnvelopeAreaSquareMeters,
          heatLossWatts: roomHeatLossWatts,
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
      totalRoomAreaSquareMeters: project.houseModel.totalRoomAreaSquareMeters,
    );
  }
}
