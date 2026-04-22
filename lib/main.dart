import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

import 'src/core/logging/app_logging.dart';
import 'src/core/providers.dart';
import 'src/app/app.dart';

Future<void> main() async {
  AppLogger? appLogger;

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final logHistoryStore = LogHistoryStore(
        getLogsDirectory: () async {
          final root = await getApplicationDocumentsDirectory();
          return Directory(p.join(root.path, 'logs'));
        },
      );
      final talker = buildTalker(logHistoryStore: logHistoryStore);
      final currentAppLogger = AppLogger(talker);
      appLogger = currentAppLogger;

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        currentAppLogger.handle(
          details.exception,
          details.stack,
          message: 'Flutter framework error',
          category: AppLogCategory.ui,
          context: {
            'library': details.library,
            'context': details.context?.toDescription(),
          },
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        currentAppLogger.handle(
          error,
          stackTrace,
          message: 'Platform dispatcher error',
          category: AppLogCategory.ui,
          critical: true,
        );
        return true;
      };

      runApp(
        ProviderScope(
          overrides: [
            logHistoryStoreProvider.overrideWithValue(logHistoryStore),
            talkerProvider.overrideWithValue(talker),
            appLoggerProvider.overrideWithValue(currentAppLogger),
            appErrorReporterProvider.overrideWithValue(
              AppErrorReporter(currentAppLogger),
            ),
          ],
          observers: [TalkerRiverpodObserver(talker: talker)],
          child: const SmartCalcApp(),
        ),
      );
    },
    (error, stackTrace) {
      appLogger?.handle(
        error,
        stackTrace,
        message: 'Uncaught zone error',
        category: AppLogCategory.ui,
        critical: true,
      );
    },
  );
}
