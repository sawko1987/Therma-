import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/report.dart';
import 'package:smartcalc_mobile/src/core/services/local_report_file_store.dart';

void main() {
  test('saveReport writes the pdf file into the reports directory', () async {
    final tempRoot = await Directory.systemTemp.createTemp('therma_report_test');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final store = LocalReportFileStore(getDocumentsDirectory: () async => tempRoot);
    const document = ReportDocument(
      fileName: 'thermocalc_demo.pdf',
      bytes: [1, 2, 3, 4],
    );

    final savedReport = await store.saveReport(document);
    final file = File(savedReport.filePath);

    expect(savedReport.fileName, 'thermocalc_demo.pdf');
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    expect(file.parent.path, endsWith('${Platform.pathSeparator}reports'));
  });
}
