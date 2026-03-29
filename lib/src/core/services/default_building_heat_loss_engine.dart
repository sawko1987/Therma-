import '../models/calculation.dart';
import 'interfaces.dart';

class DefaultBuildingHeatLossEngine implements BuildingHeatLossEngine {
  const DefaultBuildingHeatLossEngine();

  @override
  Future<BuildingHeatLossResult> calculate({
    required BuildingCalculationInput input,
  }) async {
    final roomResults = <RoomHeatLossResult>[];

    for (final roomInput in input.roomInputs) {
      final boundaryResults = <BoundaryHeatLossResult>[];
      var roomTransmissionLossW = 0.0;
      var roomTransmissionCoefficient = 0.0;

      for (final boundaryInput in roomInput.boundaryInputs) {
        final openingResults = <OpeningHeatLossResult>[];
        var boundaryLossW = 0.0;
        var boundaryCoefficient = 0.0;

        if (boundaryInput.isIncludedInLosses) {
          final opaqueCoefficient =
              boundaryInput.opaquePerformance.uValue * boundaryInput.opaqueAreaM2;
          final opaqueLoss = opaqueCoefficient * boundaryInput.deltaTemperatureC;
          boundaryCoefficient += opaqueCoefficient;
          boundaryLossW += opaqueLoss;

          for (final openingInput in boundaryInput.openingInputs) {
            final coefficient =
                openingInput.performance.uValue * openingInput.opening.areaM2;
            final loss = coefficient * openingInput.deltaTemperatureC;
            boundaryCoefficient += coefficient;
            boundaryLossW += loss;
            openingResults.add(
              OpeningHeatLossResult(
                openingId: openingInput.opening.id,
                title: openingInput.opening.title,
                kind: openingInput.opening.kind,
                areaM2: openingInput.opening.areaM2,
                heatLossCoefficientWPerK: coefficient,
                lossW: loss,
                constructionTitle: openingInput.performance.constructionTitle,
              ),
            );
          }
        }

        roomTransmissionLossW += boundaryLossW;
        roomTransmissionCoefficient += boundaryCoefficient;

        boundaryResults.add(
          BoundaryHeatLossResult(
            boundaryId: boundaryInput.boundary.id,
            title: boundaryInput.boundary.title,
            surfaceType: boundaryInput.boundary.surfaceType,
            boundaryCondition: boundaryInput.boundary.boundaryCondition,
            grossAreaM2: boundaryInput.boundary.grossAreaM2,
            opaqueAreaM2: boundaryInput.opaqueAreaM2,
            deltaTemperatureC: boundaryInput.deltaTemperatureC,
            heatLossCoefficientWPerK: boundaryCoefficient,
            lossW: boundaryLossW,
            opaqueConstructionTitle:
                boundaryInput.opaquePerformance.constructionTitle,
            openings: openingResults,
          ),
        );
      }

      final deltaTemperatureC =
          roomInput.targetTemperatureC - input.climatePoint.designTemperature;
      final ventilationCoefficient =
          0.335 * roomInput.airChangesPerHour * roomInput.volumeM3;
      final ventilationLossW = ventilationCoefficient * deltaTemperatureC;
      final totalCoefficient = roomTransmissionCoefficient + ventilationCoefficient;

      roomResults.add(
        RoomHeatLossResult(
          roomId: roomInput.room.id,
          roomName: roomInput.room.name,
          roomType: roomInput.room.roomType,
          targetTemperatureC: roomInput.targetTemperatureC,
          airChangesPerHour: roomInput.airChangesPerHour,
          volumeM3: roomInput.volumeM3,
          transmissionLossW: roomTransmissionLossW,
          ventilationLossW: ventilationLossW,
          totalLossW: roomTransmissionLossW + ventilationLossW,
          heatLossCoefficientWPerK: totalCoefficient,
          boundaryResults: boundaryResults,
        ),
      );
    }

    final transmissionLossW = roomResults.fold<double>(
      0,
      (sum, room) => sum + room.transmissionLossW,
    );
    final ventilationLossW = roomResults.fold<double>(
      0,
      (sum, room) => sum + room.ventilationLossW,
    );
    final heatLossCoefficientWPerK = roomResults.fold<double>(
      0,
      (sum, room) => sum + room.heatLossCoefficientWPerK,
    );

    return BuildingHeatLossResult(
      projectName: input.project.name,
      climatePoint: input.climatePoint,
      transmissionLossW: transmissionLossW,
      ventilationLossW: ventilationLossW,
      totalLossW: transmissionLossW + ventilationLossW,
      heatLossCoefficientWPerK: heatLossCoefficientWPerK,
      roomResults: roomResults,
    );
  }
}
