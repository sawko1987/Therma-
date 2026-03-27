import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/report.dart';
import 'package:smartcalc_mobile/src/core/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildReport returns a pdf document with bytes and filename', () async {
    final service = PdfReportService(rootBundle);
    final content = ReportContent(
      title: 'Отчет thermocalc',
      projectName: 'Demo project',
      climateLabel: 'Москва, Московская область',
      roomLabel: 'Жилая комната',
      constructionTitle: 'Наружная стена',
      datasetVersion: 'test-v1',
      generatedAt: DateTime(2026, 3, 27, 16, 20),
      thermalMetrics: const [
        ReportMetric(label: 'Фактическое R', value: '4.12 м2·°C/Вт'),
      ],
      thermalIndicators: const [
        ReportIndicatorEntry(
          title: 'Сопротивление теплопередаче',
          value: '4.12 / 3.65 м2·°C/Вт',
          normCode: 'СП 50.13330.2012',
          isPassed: true,
        ),
      ],
      moistureSummary: 'Сезон устойчив.',
      moistureMetrics: const [
        ReportMetric(label: 'Итог', value: 'Сезон устойчив'),
      ],
      moistureIndicators: const [
        ReportIndicatorEntry(
          title: 'Накопление влаги',
          value: '0.010 / 0.200 кг/м2',
          normCode: 'СП 50.13330.2012',
          isPassed: true,
        ),
      ],
      thermalLayerRows: const [
        ReportRowEntry(
          title: 'Газобетон D500',
          details: '375 мм, λ 0.140, R 2.68',
          trailing: '18.0 -> -8.1 °C',
        ),
      ],
      vaporLayerRows: const [
        ReportRowEntry(
          title: 'Минеральная вата',
          details: '100 мм, δ 0.30, Z 0.33',
          trailing: 'Σ 1.22',
        ),
      ],
      seasonalRows: const [
        ReportRowEntry(
          title: 'Зимний период',
          details: '120 дн., tнар -14 °C',
          trailing: 'Σ 0.010',
        ),
      ],
      appliedNorms: const ['СП 50.13330.2012 - Тепловая защита зданий'],
    );

    final document = await service.buildReport(content: content);

    expect(document.fileName, endsWith('.pdf'));
    expect(document.bytes, isNotEmpty);
    expect(String.fromCharCodes(document.bytes.take(4)), '%PDF');
  });
}
