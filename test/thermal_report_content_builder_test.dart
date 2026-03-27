import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';
import 'package:smartcalc_mobile/src/core/services/thermal_report_content_builder.dart';

import 'support/fakes.dart';

void main() {
  test('builds report content from current thermocalc data', () async {
    const builder = ThermalReportContentBuilder();
    const engine = NormativeThermalCalculationEngine();
    final project = buildTestProject();
    final construction = project.constructions.single;

    final calculation = await engine.calculate(
      catalog: testCatalogSnapshot,
      project: project,
      construction: construction,
    );

    final content = builder.buildContent(
      catalog: testCatalogSnapshot,
      project: project,
      construction: construction,
      calculation: calculation,
    );

    expect(content.title, 'Отчет thermocalc');
    expect(content.projectName, 'Demo project');
    expect(content.climateLabel, 'Москва, Московская область');
    expect(content.roomLabel, 'Жилая комната');
    expect(content.thermalMetrics, hasLength(4));
    expect(content.moistureSummary, isNotEmpty);
    expect(content.thermalLayerRows, hasLength(calculation.layerRows.length));
    expect(
      content.appliedNorms,
      contains(
        'СП 50.13330.2012 - Базовый набор требований по теплозащите и влагорежиму',
      ),
    );
  });
}
