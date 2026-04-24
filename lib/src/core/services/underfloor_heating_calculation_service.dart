import 'dart:math' as math;

import '../models/project.dart';

class UnderfloorHeatingCalculationService {
  const UnderfloorHeatingCalculationService();

  UnderfloorHeatingCalculation calculate(
    UnderfloorHeatingCalculation input, {
    RoomKind roomKind = RoomKind.livingRoom,
  }) {
    final loopLength =
        input.areaSquareMeters * 1000 / input.pipePitchMm +
        2 * input.supplyLengthMeters;
    final actualPower =
        input.heatFluxWattsPerSquareMeter * input.areaSquareMeters;
    final waterDeltaT = (input.flowTempC - input.returnTempC).abs();
    final flowRateLpm = waterDeltaT <= 0
        ? 0.0
        : actualPower / (4186 * 997 * waterDeltaT) * 60000;
    final balancingFlowRate = _roundToHalf(flowRateLpm);
    final pressureDropKpa = _pressureDropKpa(
      loopLengthMeters: loopLength,
      innerDiameterMm: _innerDiameterMm(input),
      flowRateLitersPerMinute: flowRateLpm,
    );
    final warnings = _warnings(
      input: input,
      loopLengthMeters: loopLength,
      flowRateLitersPerMinute: flowRateLpm,
      pressureDropKpa: pressureDropKpa,
      roomKind: roomKind,
    );

    return input.copyWith(
      actualPowerWatts: actualPower,
      loopLengthMeters: loopLength,
      flowRateLitersPerMinute: flowRateLpm,
      balancingFlowRateLitersPerMinute: balancingFlowRate,
      pressureDropKpa: pressureDropKpa,
      warnings: warnings,
    );
  }

  double _innerDiameterMm(UnderfloorHeatingCalculation input) {
    final explicit = input.pipeInnerDiameterMm;
    if (explicit != null && explicit > 0) {
      return explicit;
    }
    if (input.pipeOuterDiameterMm >= 20) {
      return 16;
    }
    return 12;
  }

  double _pressureDropKpa({
    required double loopLengthMeters,
    required double innerDiameterMm,
    required double flowRateLitersPerMinute,
  }) {
    if (loopLengthMeters <= 0 ||
        innerDiameterMm <= 0 ||
        flowRateLitersPerMinute <= 0) {
      return 0;
    }
    const rho = 997.0;
    const dynamicViscosity = 0.000653;
    final diameterMeters = innerDiameterMm / 1000;
    final flowM3s = flowRateLitersPerMinute / 1000 / 60;
    final area = math.pi * math.pow(diameterMeters, 2) / 4;
    final velocity = flowM3s / area;
    final reynolds = rho * velocity * diameterMeters / dynamicViscosity;
    final frictionFactor = reynolds < 2300
        ? 64 / reynolds
        : 0.3164 / math.pow(reynolds, 0.25);
    final pressurePa =
        frictionFactor *
        (loopLengthMeters / diameterMeters) *
        rho *
        math.pow(velocity, 2) /
        2;
    return pressurePa / 1000;
  }

  List<String> _warnings({
    required UnderfloorHeatingCalculation input,
    required double loopLengthMeters,
    required double flowRateLitersPerMinute,
    required double pressureDropKpa,
    required RoomKind roomKind,
  }) {
    final result = <String>[];
    final lengthLimit = input.pipeOuterDiameterMm >= 20 ? 100.0 : 80.0;
    if (loopLengthMeters > lengthLimit) {
      result.add(
        'Длина контура ${loopLengthMeters.toStringAsFixed(0)} м выше ${lengthLimit.toStringAsFixed(0)} м для трубы Ø${input.pipeOuterDiameterMm.toStringAsFixed(0)}.',
      );
    }
    if (flowRateLitersPerMinute < 2 || flowRateLitersPerMinute > 5) {
      result.add(
        'Расход ${flowRateLitersPerMinute.toStringAsFixed(1)} л/мин вне диапазона 2-5 л/мин.',
      );
    }
    if (pressureDropKpa > 25) {
      result.add(
        'Потери давления ${pressureDropKpa.toStringAsFixed(0)} кПа выше 25 кПа.',
      );
    } else if (pressureDropKpa > 20) {
      result.add(
        'Потери давления ${pressureDropKpa.toStringAsFixed(0)} кПа выше 20 кПа.',
      );
    }
    final floorLimit = switch (roomKind) {
      RoomKind.bathroom => 31.0,
      RoomKind.hall || RoomKind.boilerRoom => 35.0,
      _ => 29.0,
    };
    if (input.floorSurfaceTempC > floorLimit) {
      result.add(
        'Температура пола ${input.floorSurfaceTempC.toStringAsFixed(1)} °C выше лимита ${floorLimit.toStringAsFixed(0)} °C.',
      );
    }
    return result;
  }

  double _roundToHalf(double value) => (value * 2).round() / 2;
}
