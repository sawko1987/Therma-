import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logging/app_logging.dart';
import '../models/report.dart';
import 'interfaces.dart';

class LocalReportFileStore implements ReportFileStore {
  LocalReportFileStore({
    Future<Directory> Function()? getDocumentsDirectory,
    AppLogger? logger,
  }) : _getDocumentsDirectory =
           getDocumentsDirectory ?? getApplicationDocumentsDirectory,
       _logger = logger;

  final Future<Directory> Function() _getDocumentsDirectory;
  final AppLogger? _logger;

  @override
  Future<SavedReport> saveReport(ReportDocument document) async {
    _logger?.debug(
      'Save PDF report to local storage',
      category: AppLogCategory.report,
      context: {'fileName': document.fileName, 'bytes': document.bytes.length},
    );
    final rootDirectory = await _getDocumentsDirectory();
    final reportsDirectory = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}reports',
    );
    if (!await reportsDirectory.exists()) {
      await reportsDirectory.create(recursive: true);
    }

    final file = File(
      '${reportsDirectory.path}${Platform.pathSeparator}${document.fileName}',
    );
    await file.writeAsBytes(document.bytes, flush: true);

    _logger?.info(
      'PDF report saved to local storage',
      category: AppLogCategory.report,
      context: {'fileName': document.fileName, 'filePath': file.path},
    );
    return SavedReport(fileName: document.fileName, filePath: file.path);
  }
}
