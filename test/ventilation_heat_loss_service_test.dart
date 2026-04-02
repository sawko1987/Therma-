import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/models/ventilation_settings.dart';
import 'package:smartcalc_mobile/src/core/services/ventilation_heat_loss_service.dart';

import 'support/fakes.dart';

void main() {
  test('ventilation service calculates room heat loss with heat recovery', () async {
    final project = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Дом',
        rooms: [Room.defaultRoom()],
        elements: const [],
        openings: const [],
      ),
      ventilationSettings: const [
        VentilationSettings(
          id: 'vent-room',
          title: 'Приточно-вытяжная установка',
          kind: VentilationKind.heatRecovery,
          airExchangeRate: 0.7,
          heatRecoveryEfficiency: 0.65,
          roomId: defaultRoomId,
        ),
      ],
    );
    const service = NormativeVentilationCalculationService();

    final results = await service.calculate(
      catalog: testCatalogSnapshot,
      project: project,
    );

    expect(results, hasLength(1));
    final result = results.single;
    expect(result.volumeCubicMeters, closeTo(43.2, 0.01));
    expect(result.deltaTemperature, closeTo(46, 0.01));
    expect(result.heatRecoveryEfficiency, closeTo(0.65, 0.0001));
    expect(result.heatLossWatts, closeTo(163.23, 0.05));
    expect(result.appliedNormReferenceIds, contains(ventilationNormReferenceId));
  });
}
