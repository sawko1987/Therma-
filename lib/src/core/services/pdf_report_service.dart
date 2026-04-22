import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report.dart';
import 'interfaces.dart';

class PdfReportService implements ReportService {
  const PdfReportService(this._assetBundle);

  final AssetBundle _assetBundle;

  @override
  Future<ReportDocument> buildReport({required ReportContent content}) async {
    final regularFont = pw.Font.ttf(
      await _assetBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await _assetBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );

    final document = pw.Document(
      compress: true,
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            content.title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Проект: ${content.projectName}'),
          pw.Text('Конструкция: ${content.constructionTitle}'),
          pw.Text('Климат: ${content.climateLabel}'),
          pw.Text('Помещение: ${content.roomLabel}'),
          pw.Text('Dataset: ${content.datasetVersion}'),
          pw.Text('Сформировано: ${_formatTimestamp(content.generatedAt)}'),
          pw.SizedBox(height: 18),
          _buildMetricSection('Нормативные показатели', content.thermalMetrics),
          pw.SizedBox(height: 12),
          _buildIndicatorSection(
            'Индикаторы теплотехники',
            content.thermalIndicators,
          ),
          pw.SizedBox(height: 12),
          _buildMetricSection('Сезонный влагорежим', content.moistureMetrics),
          pw.SizedBox(height: 8),
          pw.Text(content.moistureSummary),
          pw.SizedBox(height: 12),
          _buildIndicatorSection(
            'Индикаторы влагорежима',
            content.moistureIndicators,
          ),
          pw.SizedBox(height: 12),
          _buildRowSection('Послойный расчет', content.thermalLayerRows),
          pw.SizedBox(height: 12),
          _buildRowSection(
            'Послойное паросопротивление',
            content.vaporLayerRows,
          ),
          pw.SizedBox(height: 12),
          _buildRowSection('Сезонный баланс влаги', content.seasonalRows),
          pw.SizedBox(height: 12),
          _buildNormSection(content.appliedNorms),
        ],
      ),
    );

    return ReportDocument(
      fileName: _buildFileName(
        projectName: content.projectName,
        constructionTitle: content.constructionTitle,
        generatedAt: content.generatedAt,
      ),
      bytes: await document.save(),
    );
  }

  pw.Widget _buildMetricSection(String title, List<ReportMetric> metrics) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        pw.SizedBox(height: 8),
        ...metrics.map(
          (metric) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    metric.label,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(flex: 3, child: pw.Text(metric.value)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildIndicatorSection(
    String title,
    List<ReportIndicatorEntry> indicators,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        pw.SizedBox(height: 8),
        ...indicators.map(
          (indicator) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: indicator.isPassed ? PdfColors.teal : PdfColors.orange,
              ),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  indicator.title,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(indicator.value),
                pw.Text(indicator.normCode, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildRowSection(String title, List<ReportRowEntry> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        pw.SizedBox(height: 8),
        ...rows.map(
          (row) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    row.title,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(flex: 4, child: pw.Text(row.details)),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    row.trailing,
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildNormSection(List<String> norms) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Примененные нормы'),
        pw.SizedBox(height: 8),
        ...norms.map(
          (norm) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(norm),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    );
  }

  String _buildFileName({
    required String projectName,
    required String constructionTitle,
    required DateTime generatedAt,
  }) {
    final timestamp =
        '${generatedAt.year.toString().padLeft(4, '0')}${generatedAt.month.toString().padLeft(2, '0')}${generatedAt.day.toString().padLeft(2, '0')}_${generatedAt.hour.toString().padLeft(2, '0')}${generatedAt.minute.toString().padLeft(2, '0')}${generatedAt.second.toString().padLeft(2, '0')}';
    final baseName = '${_sanitize(projectName)}_${_sanitize(constructionTitle)}';
    return 'thermocalc_${baseName}_$timestamp.pdf';
  }

  String _sanitize(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'\s+'), '_');
    return normalized.replaceAll(RegExp(r'[^\w\-а-яА-Я]'), '');
  }

  String _formatTimestamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
