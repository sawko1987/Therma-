import '../models/project.dart';
import 'interfaces.dart';

class PreviewReportService implements ReportService {
  const PreviewReportService();

  @override
  Future<String> buildReport(Project project) async {
    return 'PDF service placeholder for ${project.name}';
  }
}
