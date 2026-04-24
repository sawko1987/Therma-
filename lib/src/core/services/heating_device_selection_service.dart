import 'dart:math' as math;

import '../models/catalog.dart';
import '../models/project.dart';

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

  double designFlowRateLitersPerMinute({
    required double powerWatts,
    required double flowTempC,
    required double returnTempC,
  }) {
    final deltaT = flowTempC - returnTempC;
    if (powerWatts <= 0 || deltaT <= 0) {
      return 0;
    }
    return powerWatts / (4187 * deltaT) * 60;
  }

  double valvePressureDropKpa({
    required double flowRateLitersPerMinute,
    required double kv,
  }) {
    if (flowRateLitersPerMinute <= 0 || kv <= 0) {
      return 0;
    }
    final flowRateM3h = flowRateLitersPerMinute * 0.06;
    return 100 * math.pow(flowRateM3h / kv, 2).toDouble();
  }

  HeatingDeviceCalculation calculateDevice({
    required HeatingDevice device,
    required Iterable<HeatingDeviceCatalogEntry> deviceCatalog,
    required Iterable<HeatingValveCatalogEntry> valveCatalog,
    required double flowTempC,
    required double returnTempC,
    required double roomTempC,
    double? requiredPowerWatts,
  }) {
    final entry = _findDeviceEntry(device, deviceCatalog);
    final valve = _findValveEntry(device, valveCatalog);
    final powerWatts = _adjustedDevicePowerWatts(
      device: device,
      entry: entry,
      flowTempC: flowTempC,
      returnTempC: returnTempC,
      roomTempC: roomTempC,
    );
    final flowRate = designFlowRateLitersPerMinute(
      powerWatts: powerWatts,
      flowTempC: flowTempC,
      returnTempC: returnTempC,
    );
    final selectedValve = _selectValveSetting(
      valve: valve,
      requestedSetting: device.valveSetting,
      flowRateLitersPerMinute: flowRate,
    );
    final pressureDrop = selectedValve == null
        ? null
        : valvePressureDropKpa(
            flowRateLitersPerMinute: flowRate,
            kv: selectedValve.kv,
          );
    final warnings = _deviceWarnings(
      device: device,
      valve: valve,
      requiredPowerWatts: requiredPowerWatts ?? device.requiredPowerWatts,
      powerWatts: powerWatts,
      flowRateLitersPerMinute: flowRate,
      pressureDropKpa: pressureDrop,
    );
    return HeatingDeviceCalculation(
      device: device,
      catalogEntry: entry,
      valve: valve,
      valveSetting: selectedValve?.setting,
      valveKv: selectedValve?.kv,
      deltaT: (flowTempC + returnTempC) / 2 - roomTempC,
      calculatedPowerWatts: powerWatts,
      flowRateLitersPerMinute: flowRate,
      valvePressureDropKpa: pressureDrop,
      warnings: warnings,
    );
  }

  HeatingDeviceCatalogEntry? _findDeviceEntry(
    HeatingDevice device,
    Iterable<HeatingDeviceCatalogEntry> catalog,
  ) {
    final id = device.catalogItemId;
    if (id == null) {
      return null;
    }
    for (final entry in catalog) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  HeatingValveCatalogEntry? _findValveEntry(
    HeatingDevice device,
    Iterable<HeatingValveCatalogEntry> catalog,
  ) {
    final id = device.valveCatalogItemId;
    if (id == null) {
      return null;
    }
    for (final entry in catalog) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  double _adjustedDevicePowerWatts({
    required HeatingDevice device,
    required HeatingDeviceCatalogEntry? entry,
    required double flowTempC,
    required double returnTempC,
    required double roomTempC,
  }) {
    if (entry == null) {
      return device.calculatedPowerWatts ?? device.ratedPowerWatts;
    }
    final catalogPower = adjustedPowerWatts(
      entry: entry,
      flowTempC: flowTempC,
      returnTempC: returnTempC,
      roomTempC: roomTempC,
    );
    if (!entry.isSectional) {
      return catalogPower;
    }
    final catalogSections = entry.sectionCount ?? 1;
    final selectedSections = device.sectionCount ?? catalogSections;
    if (catalogSections <= 0 || selectedSections <= 0) {
      return 0;
    }
    return catalogPower / catalogSections * selectedSections;
  }

  _SelectedValveSetting? _selectValveSetting({
    required HeatingValveCatalogEntry? valve,
    required String? requestedSetting,
    required double flowRateLitersPerMinute,
  }) {
    if (valve == null) {
      return null;
    }
    if (valve.settingKvMap.isEmpty) {
      return _SelectedValveSetting(setting: null, kv: valve.kvs);
    }
    final requestedKv = requestedSetting == null
        ? null
        : valve.settingKvMap[requestedSetting];
    if (requestedKv != null) {
      return _SelectedValveSetting(setting: requestedSetting, kv: requestedKv);
    }
    const targetPressureDropKpa = 10.0;
    _SelectedValveSetting? best;
    double? bestDistance;
    for (final entry in valve.settingKvMap.entries) {
      final pressureDrop = valvePressureDropKpa(
        flowRateLitersPerMinute: flowRateLitersPerMinute,
        kv: entry.value,
      );
      final distance = (pressureDrop - targetPressureDropKpa).abs();
      if (bestDistance == null || distance < bestDistance) {
        best = _SelectedValveSetting(setting: entry.key, kv: entry.value);
        bestDistance = distance;
      }
    }
    return best;
  }

  List<String> _deviceWarnings({
    required HeatingDevice device,
    required HeatingValveCatalogEntry? valve,
    required double? requiredPowerWatts,
    required double powerWatts,
    required double flowRateLitersPerMinute,
    required double? pressureDropKpa,
  }) {
    final warnings = <String>[];
    if (valve?.kind == HeatingValveKind.ballValve) {
      warnings.add('Шаровый кран не предназначен для балансировки расхода.');
    }
    if (flowRateLitersPerMinute > 0 && flowRateLitersPerMinute < 0.2) {
      warnings.add('Расход ниже 0,2 л/мин, настройка может быть нестабильной.');
    }
    if (flowRateLitersPerMinute > 3.0) {
      warnings.add('Расход выше 3,0 л/мин, проверьте шум и потери давления.');
    }
    if (pressureDropKpa != null && pressureDropKpa < 3) {
      warnings.add('Падение на арматуре ниже 3 кПа, балансировка грубая.');
    }
    if (pressureDropKpa != null && pressureDropKpa > 20) {
      warnings.add('Падение на арматуре выше 20 кПа, возможен шум.');
    }
    if (requiredPowerWatts != null && requiredPowerWatts > 0) {
      final reserve = (powerWatts - requiredPowerWatts) / requiredPowerWatts;
      if (reserve < -0.05) {
        warnings.add(
          'Мощности радиатора недостаточно для остаточной нагрузки.',
        );
      } else if (reserve > 0.25) {
        warnings.add('Запас мощности выше 25%.');
      }
    }
    return List.unmodifiable(warnings);
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

class HeatingDeviceCalculation {
  const HeatingDeviceCalculation({
    required this.device,
    required this.catalogEntry,
    required this.valve,
    required this.valveSetting,
    required this.valveKv,
    required this.deltaT,
    required this.calculatedPowerWatts,
    required this.flowRateLitersPerMinute,
    required this.valvePressureDropKpa,
    required this.warnings,
  });

  final HeatingDevice device;
  final HeatingDeviceCatalogEntry? catalogEntry;
  final HeatingValveCatalogEntry? valve;
  final String? valveSetting;
  final double? valveKv;
  final double deltaT;
  final double calculatedPowerWatts;
  final double flowRateLitersPerMinute;
  final double? valvePressureDropKpa;
  final List<String> warnings;
}

class _SelectedValveSetting {
  const _SelectedValveSetting({required this.setting, required this.kv});

  final String? setting;
  final double kv;
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
