import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/report.dart';
import 'interfaces.dart';

class LocalReportFileStore implements ReportFileStore {
  LocalReportFileStore({Future<Directory> Function()? getDocumentsDirectory})
    : _getDocumentsDirectory =
          getDocumentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _getDocumentsDirectory;

  @override
  Future<SavedReport> saveReport(ReportDocument document) async {
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

    return SavedReport(fileName: document.fileName, filePath: file.path);
  }
}
