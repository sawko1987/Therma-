import '../models/building_heat_loss.dart';
import '../models/calculation.dart';
import '../models/catalog.dart';
import '../models/project.dart';
import 'interfaces.dart';
import 'room_adjacency_geometry.dart';

class NormativeBuildingHeatLossService implements BuildingHeatLossService {
  const NormativeBuildingHeatLossService(this._engine);

  final ThermalCalculationEngine _engine;
  static const double _ventilationHeatCapacityFactor = 0.335;
  static const double _internalSurfaceResistance = 0.13;

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
    final constructionMap = {
      for (final construction in project.constructions)
        construction.id: construction,
    };
    final roomConditionMap = {
      for (final condition in catalog.roomKindConditions)
        condition.roomKindId: condition,
    };
    final openingsByElementId = <String, List<EnvelopeOpening>>{};
    for (final opening in project.houseModel.openings) {
      openingsByElementId.putIfAbsent(opening.elementId, () => []).add(opening);
    }

    final roomCalculationData = <String, _RoomCalculationData>{};
    final unresolvedElements = <HouseEnvelopeElement>[];

    for (final room in project.houseModel.rooms) {
      final roomCondition = roomConditionMap[room.kind.storageKey];
      if (roomCondition == null) {
        throw StateError(
          'Room kind ${room.kind.storageKey} is missing from room conditions.',
        );
      }

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
      final insideAirTemperature = roomCondition.insideTemperature;
      final deltaTemperature = insideAirTemperature - outsideAirTemperature;
      final airChangesPerHour = roomCondition.airChangesPerHour ?? 0.0;
      final roomVolumeCubicMeters = room.areaSquareMeters * room.heightMeters;

      for (final element in roomElements) {
        final construction = constructionMap[element.constructionId];
        if (construction == null) {
          roomUnresolvedElements.add(element);
          unresolvedElements.add(element);
          continue;
        }

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
        final opaqueArea = (element.areaSquareMeters - openingArea).clamp(
          0.0,
          element.areaSquareMeters,
        );
        final opaqueHeatLoss =
            deltaTemperature / result.totalResistance * opaqueArea;
        final openingHeatLoss = elementOpenings.fold<double>(
          0,
          (sum, item) =>
              sum +
              deltaTemperature *
                  item.heatTransferCoefficient *
                  item.areaSquareMeters,
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
          _ventilationHeatCapacityFactor *
          airChangesPerHour *
          roomVolumeCubicMeters *
          deltaTemperature;
      final infiltrationAirFlowCubicMetersPerHour = roomOpenings.fold<double>(
        0,
        (sum, item) =>
            sum +
            item.areaSquareMeters *
                item.leakagePreset.leakageRateCubicMetersPerHourPerSquareMeter,
      );
      final infiltrationHeatLossWatts =
          _ventilationHeatCapacityFactor *
          infiltrationAirFlowCubicMetersPerHour *
          deltaTemperature;
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

      roomCalculationData[room.id] = _RoomCalculationData(
        room: room,
        elementResults: List.unmodifiable(elementResults),
        unresolvedElements: List.unmodifiable(roomUnresolvedElements),
        elementCount: roomElements.length,
        openingCount: roomOpenings.length,
        heatingDeviceCount: roomHeatingDevices.length,
        totalEnvelopeAreaSquareMeters: totalEnvelopeAreaSquareMeters,
        totalOpaqueAreaSquareMeters:
            (totalEnvelopeAreaSquareMeters - totalOpeningAreaSquareMeters)
                .clamp(0.0, totalEnvelopeAreaSquareMeters),
        totalOpeningAreaSquareMeters: totalOpeningAreaSquareMeters,
        insideAirTemperature: insideAirTemperature,
        outsideAirTemperature: outsideAirTemperature,
        airChangesPerHour: airChangesPerHour,
        roomVolumeCubicMeters: roomVolumeCubicMeters,
        heatLossWatts:
            heatLossWatts +
            ventilationHeatLossWatts +
            infiltrationHeatLossWatts,
        opaqueHeatLossWatts: opaqueHeatLossWatts,
        openingHeatLossWatts: openingHeatLossWatts,
        ventilationHeatLossWatts: ventilationHeatLossWatts,
        infiltrationHeatLossWatts: infiltrationHeatLossWatts,
        installedHeatingPowerWatts: installedHeatingPowerWatts,
      );
    }

    final internalHeatTransferResults = <BuildingInternalHeatTransferResult>[];
    final adjacentRoomHeatGainByRoomId = <String, double>{
      for (final room in project.houseModel.rooms) room.id: 0.0,
    };
    final internalResultsByRoomId =
        <String, List<BuildingInternalHeatTransferResult>>{
          for (final room in project.houseModel.rooms) room.id: [],
        };
    final internalPartitionConstruction =
        switch (project.houseModel.internalPartitionConstructionId) {
          final String constructionId => constructionMap[constructionId],
          null => null,
        };
    if (internalPartitionConstruction != null &&
        internalPartitionConstruction.elementKind ==
            ConstructionElementKind.wall) {
      final totalResistance = _calculateInternalPartitionResistance(
        catalog,
        internalPartitionConstruction,
      );
      for (final boundary in buildSharedRoomBoundaries(
        project.houseModel.rooms,
      )) {
        final primaryRoom = roomCalculationData[boundary.primaryRoomId];
        final secondaryRoom = roomCalculationData[boundary.secondaryRoomId];
        if (primaryRoom == null || secondaryRoom == null) {
          continue;
        }
        final warmerRoom =
            primaryRoom.insideAirTemperature >=
                secondaryRoom.insideAirTemperature
            ? primaryRoom
            : secondaryRoom;
        final coolerRoom = identical(warmerRoom, primaryRoom)
            ? secondaryRoom
            : primaryRoom;
        final deltaTemperature =
            warmerRoom.insideAirTemperature - coolerRoom.insideAirTemperature;
        if (deltaTemperature <= 0) {
          continue;
        }
        final partitionAreaSquareMeters =
            boundary.segment.lengthMeters *
            _sharedPartitionHeightMeters(warmerRoom.room, coolerRoom.room);
        if (partitionAreaSquareMeters <= 0) {
          continue;
        }
        final heatTransferWatts =
            deltaTemperature / totalResistance * partitionAreaSquareMeters;
        final result = BuildingInternalHeatTransferResult(
          fromRoom: warmerRoom.room,
          toRoom: coolerRoom.room,
          construction: internalPartitionConstruction,
          segment: boundary.segment,
          partitionAreaSquareMeters: partitionAreaSquareMeters,
          fromRoomTemperature: warmerRoom.insideAirTemperature,
          toRoomTemperature: coolerRoom.insideAirTemperature,
          deltaTemperature: deltaTemperature,
          totalResistance: totalResistance,
          heatTransferWatts: heatTransferWatts,
        );
        internalHeatTransferResults.add(result);
        adjacentRoomHeatGainByRoomId[warmerRoom.room.id] =
            (adjacentRoomHeatGainByRoomId[warmerRoom.room.id] ?? 0) -
            heatTransferWatts;
        adjacentRoomHeatGainByRoomId[coolerRoom.room.id] =
            (adjacentRoomHeatGainByRoomId[coolerRoom.room.id] ?? 0) +
            heatTransferWatts;
        internalResultsByRoomId[warmerRoom.room.id]!.add(result);
        internalResultsByRoomId[coolerRoom.room.id]!.add(result);
      }
    }

    final roomResults = roomCalculationData.values
        .map((item) {
          final adjacentRoomHeatGainWatts =
              adjacentRoomHeatGainByRoomId[item.room.id] ?? 0.0;
          final netHeatingDemandWatts =
              item.heatLossWatts - adjacentRoomHeatGainWatts;
          return BuildingRoomHeatLossResult(
            room: item.room,
            elementResults: item.elementResults,
            internalHeatTransferResults: List.unmodifiable(
              internalResultsByRoomId[item.room.id] ??
                  const <BuildingInternalHeatTransferResult>[],
            ),
            unresolvedElements: item.unresolvedElements,
            elementCount: item.elementCount,
            openingCount: item.openingCount,
            heatingDeviceCount: item.heatingDeviceCount,
            totalEnvelopeAreaSquareMeters: item.totalEnvelopeAreaSquareMeters,
            totalOpaqueAreaSquareMeters: item.totalOpaqueAreaSquareMeters,
            totalOpeningAreaSquareMeters: item.totalOpeningAreaSquareMeters,
            insideAirTemperature: item.insideAirTemperature,
            outsideAirTemperature: item.outsideAirTemperature,
            airChangesPerHour: item.airChangesPerHour,
            roomVolumeCubicMeters: item.roomVolumeCubicMeters,
            heatLossWatts: item.heatLossWatts,
            opaqueHeatLossWatts: item.opaqueHeatLossWatts,
            openingHeatLossWatts: item.openingHeatLossWatts,
            ventilationHeatLossWatts: item.ventilationHeatLossWatts,
            infiltrationHeatLossWatts: item.infiltrationHeatLossWatts,
            adjacentRoomHeatGainWatts: adjacentRoomHeatGainWatts,
            netHeatingDemandWatts: netHeatingDemandWatts,
            installedHeatingPowerWatts: item.installedHeatingPowerWatts,
            heatingPowerDeltaWatts:
                item.installedHeatingPowerWatts - netHeatingDemandWatts,
          );
        })
        .toList(growable: false);

    return BuildingHeatLossResult(
      roomResults: List.unmodifiable(roomResults),
      internalHeatTransferResults: List.unmodifiable(
        internalHeatTransferResults,
      ),
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
      totalInfiltrationHeatLossWatts: roomResults.fold<double>(
        0,
        (sum, item) => sum + item.infiltrationHeatLossWatts,
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

  double _calculateInternalPartitionResistance(
    CatalogSnapshot catalog,
    Construction construction,
  ) {
    final materials = {
      for (final material in catalog.materials) material.id: material,
    };
    final layerResistance = construction.layers
        .where((item) => item.enabled)
        .fold<double>(0, (sum, item) {
          final material = materials[item.materialId];
          if (material == null) {
            throw StateError(
              'Material ${item.materialId} is missing from the catalog.',
            );
          }
          if (material.thermalConductivity <= 0) {
            throw StateError(
              'Material ${item.materialId} has invalid thermal conductivity.',
            );
          }
          return sum +
              (item.thicknessMm / 1000.0) / material.thermalConductivity;
        });
    return _internalSurfaceResistance +
        layerResistance +
        _internalSurfaceResistance;
  }

  double _sharedPartitionHeightMeters(Room first, Room second) {
    return first.heightMeters < second.heightMeters
        ? first.heightMeters
        : second.heightMeters;
  }
}

class _RoomCalculationData {
  const _RoomCalculationData({
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
    required this.airChangesPerHour,
    required this.roomVolumeCubicMeters,
    required this.heatLossWatts,
    required this.opaqueHeatLossWatts,
    required this.openingHeatLossWatts,
    required this.ventilationHeatLossWatts,
    required this.infiltrationHeatLossWatts,
    required this.installedHeatingPowerWatts,
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
  final double airChangesPerHour;
  final double roomVolumeCubicMeters;
  final double heatLossWatts;
  final double opaqueHeatLossWatts;
  final double openingHeatLossWatts;
  final double ventilationHeatLossWatts;
  final double infiltrationHeatLossWatts;
  final double installedHeatingPowerWatts;
}
