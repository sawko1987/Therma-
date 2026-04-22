import 'package:flutter/material.dart';

import 'app_log_category.dart';
import 'app_logger.dart';

class AppErrorReporter {
  AppErrorReporter(this._logger);

  final AppLogger _logger;

  Future<T?> runUiAction<T>({
    required BuildContext context,
    required Future<T> Function() action,
    required String operation,
    required String userMessage,
    required AppLogCategory category,
    AppLogContext contextData = const {},
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      _logger.handle(
        error,
        stackTrace,
        message: operation,
        category: category,
        context: contextData,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userMessage)));
      }
      return null;
    }
  }
}
