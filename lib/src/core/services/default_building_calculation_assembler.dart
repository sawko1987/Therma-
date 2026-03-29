import '../models/calculation.dart';
import '../models/catalog.dart';
import '../models/project.dart';
import 'interfaces.dart';

class DefaultBuildingCalculationAssembler implements BuildingCalculationAssembler {
  const DefaultBuildingCalculationAssembler(this._constructionEngine);

  final ConstructionPerformanceEngine _constructionEngine;

  @override
  Future<BuildingCalculationInput> assemble({
    required CatalogSnapshot catalog,
    required Project project,
  }) async {
    final climatePoint = catalog.climatePoints.firstWhere(
      (point) => point.id == project.climatePointId,
    );
    final constructions = {
      for (final construction in project.constructions) construction.id: construction,
    };

    final roomIds = {for (final room in project.rooms) room.id};
    final roomInputs = <RoomCalculationInput>[];

    for (final room in project.rooms) {
      final boundaryInputs = <BoundaryCalculationInput>[];

      for (final boundary in room.boundaries) {
        final opaqueConstruction = constructions[boundary.constructionId];
        if (opaqueConstruction == null) {
          throw StateError(
            'Поверхность "${boundary.title}" ссылается на неизвестную конструкцию ${boundary.constructionId}.',
          );
        }
        if (boundary.opaqueAreaM2 < 0) {
          throw StateError(
            'Площадь проемов больше площади поверхности "${boundary.title}".',
          );
        }
        if (boundary.adjacentRoomId != null &&
            !roomIds.contains(boundary.adjacentRoomId)) {
          throw StateError(
            'Поверхность "${boundary.title}" ссылается на неизвестную комнату ${boundary.adjacentRoomId}.',
          );
        }

        final opaquePerformance = await _constructionEngine.calculate(
          catalog: catalog,
          project: project,
          construction: opaqueConstruction,
        );

        final deltaTemperatureC = switch (boundary.boundaryCondition) {
          BoundaryCondition.outdoor =>
            room.targetTemperatureC - climatePoint.designTemperature,
          BoundaryCondition.ground ||
          BoundaryCondition.unheatedSpace =>
            room.targetTemperatureC - (boundary.adjacentTemperatureC ?? 5),
          BoundaryCondition.heatedAdjacent => 0.0,
        }.toDouble();
        final isIncludedInLosses =
            boundary.boundaryCondition != BoundaryCondition.heatedAdjacent;

        final openingInputs = <OpeningCalculationInput>[];
        for (final opening in boundary.openings) {
          final openingConstruction = constructions[opening.constructionId];
          if (openingConstruction == null) {
            throw StateError(
              'Проем "${opening.title}" ссылается на неизвестную конструкцию ${opening.constructionId}.',
            );
          }
          final performance = await _constructionEngine.calculate(
            catalog: catalog,
            project: project,
            construction: openingConstruction,
          );
          openingInputs.add(
            OpeningCalculationInput(
              opening: opening,
              deltaTemperatureC: deltaTemperatureC,
              performance: performance,
            ),
          );
        }

        boundaryInputs.add(
          BoundaryCalculationInput(
            boundary: boundary,
            deltaTemperatureC: deltaTemperatureC,
            opaqueAreaM2: boundary.opaqueAreaM2,
            opaquePerformance: opaquePerformance,
            openingInputs: openingInputs,
            isIncludedInLosses: isIncludedInLosses,
          ),
        );
      }

      roomInputs.add(
        RoomCalculationInput(
          room: room,
          targetTemperatureC: room.targetTemperatureC,
          airChangesPerHour: room.airChangesPerHour,
          volumeM3: room.volumeM3,
          boundaryInputs: boundaryInputs,
        ),
      );
    }

    return BuildingCalculationInput(
      project: project,
      climatePoint: climatePoint,
      roomInputs: roomInputs,
    );
  }
}
