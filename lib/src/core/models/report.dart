class ReportMetric {
  const ReportMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class ReportIndicatorEntry {
  const ReportIndicatorEntry({
    required this.title,
    required this.value,
    required this.normCode,
    required this.isPassed,
  });

  final String title;
  final String value;
  final String normCode;
  final bool isPassed;
}

class ReportRowEntry {
  const ReportRowEntry({
    required this.title,
    required this.details,
    required this.trailing,
  });

  final String title;
  final String details;
  final String trailing;
}

class ReportContent {
  const ReportContent({
    required this.title,
    required this.projectName,
    required this.climateLabel,
    required this.roomLabel,
    required this.constructionTitle,
    required this.datasetVersion,
    required this.generatedAt,
    required this.thermalMetrics,
    required this.thermalIndicators,
    required this.moistureSummary,
    required this.moistureMetrics,
    required this.moistureIndicators,
    required this.thermalLayerRows,
    required this.vaporLayerRows,
    required this.seasonalRows,
    required this.appliedNorms,
  });

  final String title;
  final String projectName;
  final String climateLabel;
  final String roomLabel;
  final String constructionTitle;
  final String datasetVersion;
  final DateTime generatedAt;
  final List<ReportMetric> thermalMetrics;
  final List<ReportIndicatorEntry> thermalIndicators;
  final String moistureSummary;
  final List<ReportMetric> moistureMetrics;
  final List<ReportIndicatorEntry> moistureIndicators;
  final List<ReportRowEntry> thermalLayerRows;
  final List<ReportRowEntry> vaporLayerRows;
  final List<ReportRowEntry> seasonalRows;
  final List<String> appliedNorms;
}

class ReportDocument {
  const ReportDocument({
    required this.fileName,
    required this.bytes,
    this.mimeType = 'application/pdf',
  });

  final String fileName;
  final List<int> bytes;
  final String mimeType;
}

class SavedReport {
  const SavedReport({required this.fileName, required this.filePath});

  final String fileName;
  final String filePath;
}
