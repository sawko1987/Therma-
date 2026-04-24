import 'dart:math' as math;

import '../models/catalog.dart';

class HeatingDeviceSelectionService {
  const HeatingDeviceSelectionService();

  double adjustedPowerWatts({
    required HeatingDeviceCatalogEntry entry,
    required double flowTempC,
    required double returnTempC,
    required double roomTempC,
  }) {
    final deltaT = (flowTempC + returnTempC) / 2 - roomTempC;
    final nominalDeltaT = entry.nominalDeltaT;
    if (deltaT <= 0 || nominalDeltaT <= 0) {
      return 0;
    }
    final exponent = entry.heatOutputExponent ?? _defaultExponent(entry);
    return entry.ratedPowerWatts * math.pow(deltaT / nominalDeltaT, exponent);
  }

  SectionalHeatingDeviceSelection selectSectional({
    required HeatingDeviceCatalogEntry entry,
    required double requiredPowerWatts,
    required double flowTempC,
    required double returnTempC,
    required double roomTempC,
  }) {
    final catalogSections = entry.sectionCount ?? 1;
    final adjustedCatalogPower = adjustedPowerWatts(
      entry: entry,
      flowTempC: flowTempC,
      returnTempC: returnTempC,
      roomTempC: roomTempC,
    );
    final sectionPower = adjustedCatalogPower / catalogSections;
    final sections = sectionPower <= 0
        ? 0
        : (requiredPowerWatts / sectionPower).ceil();
    return SectionalHeatingDeviceSelection(
      entry: entry,
      requiredPowerWatts: requiredPowerWatts,
      adjustedSectionPowerWatts: sectionPower,
      sectionCount: sections,
      actualPowerWatts: sectionPower * sections,
    );
  }

  PanelHeatingDeviceSelection? selectPanel({
    required Iterable<HeatingDeviceCatalogEntry> entries,
    required double requiredPowerWatts,
    required double flowTempC,
    required double returnTempC,
    required double roomTempC,
  }) {
    final candidates =
        entries
            .map(
              (entry) => PanelHeatingDeviceSelection(
                entry: entry,
                requiredPowerWatts: requiredPowerWatts,
                actualPowerWatts: adjustedPowerWatts(
                  entry: entry,
                  flowTempC: flowTempC,
                  returnTempC: returnTempC,
                  roomTempC: roomTempC,
                ),
              ),
            )
            .where((item) => item.actualPowerWatts >= requiredPowerWatts)
            .toList(growable: false)
          ..sort((a, b) {
            final powerCompare = a.actualPowerWatts.compareTo(
              b.actualPowerWatts,
            );
            if (powerCompare != 0) {
              return powerCompare;
            }
            return (a.entry.widthMm ?? double.infinity).compareTo(
              b.entry.widthMm ?? double.infinity,
            );
          });
    return candidates.isEmpty ? null : candidates.first;
  }

  double _defaultExponent(HeatingDeviceCatalogEntry entry) {
    final panelType = entry.panelType;
    if (panelType != null && panelType.isNotEmpty) {
      return 1.3;
    }
    return 1.25;
  }
}

class SectionalHeatingDeviceSelection {
  const SectionalHeatingDeviceSelection({
    required this.entry,
    required this.requiredPowerWatts,
    required this.adjustedSectionPowerWatts,
    required this.sectionCount,
    required this.actualPowerWatts,
  });

  final HeatingDeviceCatalogEntry entry;
  final double requiredPowerWatts;
  final double adjustedSectionPowerWatts;
  final int sectionCount;
  final double actualPowerWatts;
}

class PanelHeatingDeviceSelection {
  const PanelHeatingDeviceSelection({
    required this.entry,
    required this.requiredPowerWatts,
    required this.actualPowerWatts,
  });

  final HeatingDeviceCatalogEntry entry;
  final double requiredPowerWatts;
  final double actualPowerWatts;
}
