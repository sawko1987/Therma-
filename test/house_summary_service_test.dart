import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/services/house_summary_service.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';

import 'support/fakes.dart';

void main() {
  test('buildSummary subtracts openings from opaque area and counts opening loss', () async {
    final project = buildTestProject(
      houseModel: HouseModel(
        id: 'house-model',
        title: 'Конструктор дома',
        rooms: [
          Room.defaultRoom(),
        ],
        elements: const [
          HouseEnvelopeElement(
            id: 'element-wall',
            roomId: defaultRoomId,
            title: 'Наружная стена',
            elementKind: ConstructionElementKind.wall,
            areaSquareMeters: 20,
            constructionId: 'wall',
          ),
        ],
        openings: const [
          EnvelopeOpening(
            id: 'opening-window',
            elementId: 'element-wall',
            title: 'Окно',
            kind: OpeningKind.window,
            areaSquareMeters: 4,
            heatTransferCoefficient: 1.0,
          ),
        ],
      ),
    );
    const service = HouseSummaryService(NormativeThermalCalculationEngine());

    final summary = await service.buildSummary(
      catalog: testCatalogSnapshot,
      project: project,
    );

    expect(summary.totalEnvelopeAreaSquareMeters, 20);
    expect(summary.totalOpeningAreaSquareMeters, 4);
    expect(summary.totalOpaqueAreaSquareMeters, 16);
    expect(summary.totalOpeningCount, 1);
    expect(summary.totalOpeningHeatLossWatts, closeTo(172, 2));
    expect(summary.totalHeatLossWatts, closeTo(294, 3));
    expect(summary.roomSummaries.single.totalOpaqueAreaSquareMeters, 16);
  });
}
