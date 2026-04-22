import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/logging/app_logging.dart';
import '../../../core/providers.dart';

class DiagnosticsLogsScreen extends ConsumerWidget {
  const DiagnosticsLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final talker = ref.watch(talkerProvider);
    final theme = buildTalkerScreenTheme(buildAppTheme());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Диагностика и логи'),
        actions: [
          IconButton(
            tooltip: 'Экспорт лога',
            onPressed: () => _exportCurrentLog(context, ref),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Фильтрация',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Уровни фильтруются через цветные чипы, категории ищутся по тегам вроде [storage], [calculation] и [report].',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TalkerView(
              talker: talker,
              theme: theme,
              appBarTitle: 'Диагностика',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCurrentLog(BuildContext context, WidgetRef ref) async {
    final reporter = ref.read(appErrorReporterProvider);
    final file = await reporter.runUiAction(
      context: context,
      action: () => ref.read(logHistoryStoreProvider).exportCurrentLogFile(),
      operation: 'Failed to export current log file',
      userMessage: 'Не удалось экспортировать текущий лог-файл.',
      category: AppLogCategory.storage,
      contextData: const {'action': 'exportCurrentLogFile'},
    );
    if (!context.mounted || file == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Лог экспортирован: ${file.path}')));
  }
}
