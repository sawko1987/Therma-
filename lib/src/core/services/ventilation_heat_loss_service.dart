import '../models/catalog.dart';
import '../models/project.dart';
import '../models/ventilation_settings.dart';
import 'interfaces.dart';

const double ventilationAirDensityKgPerCubicMeter = 1.2;
const double ventilationAirSpecificHeatKjPerKgC = 1.005;
const double ventilationKilojoulePerHourToWattsFactor = 0.278;
const String ventilationNormReferenceId = 'sp_60';

class VentilationHeatLossResult {
  const VentilationHeatLossResult({
    required this.settings,
    required this.room,
    required this.volumeCubicMeters,
    required this.outsideAirTemperature,
    required this.insideAirTemperature,
    required this.deltaTemperature,
    required this.heatRecoveryEfficiency,
    required this.heatLossWatts,
    required this.appliedNormReferenceIds,
  });

  final VentilationSettings settings;
  final Room? room;
  final double volumeCubicMeters;
  final double outsideAirTemperature;
  final double insideAirTemperature;
  final double deltaTemperature;
  final double heatRecoveryEfficiency;
  final double heatLossWatts;
  final List<String> appliedNormReferenceIds;
}

class NormativeVentilationCalculationService
    implements VentilationHeatLossService {
  const NormativeVentilationCalculationService();

  @override
  Future<List<VentilationHeatLossResult>> calculate({
    required CatalogSnapshot catalog,
    required Project project,
  }) async {
    final climate = catalog.climatePoints.firstWhere(
      (point) => point.id == project.climatePointId,
      orElse: () => throw StateError(
        'Climate point ${project.climatePointId} is missing from the catalog.',
      ),
    );
    final roomConditionMap = {
      for (final condition in catalog.roomKindConditions)
        condition.roomKindId: condition,
    };
    final roomMap = {for (final room in project.houseModel.rooms) room.id: room};

    return project.ventilationSettings.map((settings) {
      final room = switch (settings.roomId) {
        final String roomId => roomMap[roomId],
        null => null,
      };
      if (settings.roomId != null && room == null) {
        throw StateError(
          'Room ${settings.roomId} is missing for ventilation setting ${settings.id}.',
        );
      }

      final scopedRooms = room == null ? project.houseModel.rooms : [room];
      final roomVolumes = {
        for (final scopedRoom in scopedRooms)
          scopedRoom.id: scopedRoom.areaSquareMeters * scopedRoom.heightMeters,
      };
      final volumeCubicMeters = roomVolumes.values.fold<double>(
        0,
        (sum, item) => sum + item,
      );
      final insideAirTemperature = volumeCubicMeters <= 0
          ? 0.0
          : scopedRooms.fold<double>(0, (sum, item) {
              final condition = roomConditionMap[item.kind.storageKey];
              if (condition == null) {
                throw StateError(
                  'Room kind ${item.kind.storageKey} is missing from room conditions.',
                );
              }
              final roomVolume = roomVolumes[item.id] ?? 0.0;
              return sum + condition.insideTemperature * roomVolume;
            }) /
                volumeCubicMeters;
      final outsideAirTemperature = climate.designTemperature;
      final deltaTemperature = insideAirTemperature - outsideAirTemperature;
      final heatRecoveryEfficiency = settings.effectiveHeatRecoveryEfficiency;
      final heatLossWatts =
          ventilationKilojoulePerHourToWattsFactor *
          settings.airExchangeRate *
          volumeCubicMeters *
          ventilationAirDensityKgPerCubicMeter *
          ventilationAirSpecificHeatKjPerKgC *
          deltaTemperature *
          (1 - heatRecoveryEfficiency);

      return VentilationHeatLossResult(
        settings: settings,
        room: room,
        volumeCubicMeters: volumeCubicMeters,
        outsideAirTemperature: outsideAirTemperature,
        insideAirTemperature: insideAirTemperature,
        deltaTemperature: deltaTemperature,
        heatRecoveryEfficiency: heatRecoveryEfficiency,
        heatLossWatts: heatLossWatts,
        appliedNormReferenceIds: const [ventilationNormReferenceId],
      );
    }).toList(growable: false);
  }
}
