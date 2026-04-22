import 'dart:async';

import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'app_log_category.dart';
import 'app_log_record.dart';
import 'log_history_store.dart';

typedef AppLogContext = Map<String, Object?>;

class AppLogger {
  AppLogger(this.talker);

  final Talker talker;

  void debug(
    String message, {
    AppLogCategory? category,
    AppLogContext context = const {},
  }) {
    _log(
      message,
      logLevel: LogLevel.debug,
      category: category,
      context: context,
    );
  }

  void info(
    String message, {
    AppLogCategory? category,
    AppLogContext context = const {},
  }) {
    _log(
      message,
      logLevel: LogLevel.info,
      category: category,
      context: context,
    );
  }

  void warning(
    String message, {
    AppLogCategory? category,
    AppLogContext context = const {},
  }) {
    _log(
      message,
      logLevel: LogLevel.warning,
      category: category,
      context: context,
    );
  }

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    AppLogCategory? category,
    AppLogContext context = const {},
  }) {
    _log(
      message,
      logLevel: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
      category: category,
      context: context,
    );
  }

  void critical(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    AppLogCategory? category,
    AppLogContext context = const {},
  }) {
    _log(
      message,
      logLevel: LogLevel.critical,
      error: error,
      stackTrace: stackTrace,
      category: category,
      context: context,
    );
  }

  void handle(
    Object error,
    StackTrace? stackTrace, {
    String message = 'Unhandled application error',
    AppLogCategory? category,
    AppLogContext context = const {},
    bool critical = false,
  }) {
    _log(
      message,
      logLevel: critical ? LogLevel.critical : LogLevel.error,
      error: error,
      stackTrace: stackTrace,
      category: category,
      context: context,
    );
  }

  Future<T> runLoggedAction<T>({
    required String action,
    required Future<T> Function() operation,
    required AppLogCategory category,
    AppLogContext context = const {},
    String? successMessage,
    bool logStart = true,
  }) async {
    if (logStart) {
      debug('$action started', category: category, context: context);
    }
    try {
      final result = await operation();
      info(
        successMessage ?? '$action completed',
        category: category,
        context: context,
      );
      return result;
    } catch (error, stackTrace) {
      handle(
        error,
        stackTrace,
        message: '$action failed',
        category: category,
        context: context,
      );
      rethrow;
    }
  }

  void _log(
    String message, {
    required LogLevel logLevel,
    Object? error,
    StackTrace? stackTrace,
    AppLogCategory? category,
    AppLogContext context = const {},
  }) {
    talker.logCustom(
      AppTalkerLog(
        message,
        logLevel: logLevel,
        category: category,
        context: sanitizeContext(context),
        exceptionObject: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

class AppTalkerLog extends TalkerLog {
  AppTalkerLog(
    String message, {
    required LogLevel logLevel,
    this.category,
    this.context = const {},
    this.exceptionObject,
    StackTrace? stackTrace,
  }) : super(
         _buildMessage(message, category),
         logLevel: logLevel,
         exception: exceptionObject,
         stackTrace: stackTrace,
       );

  final AppLogCategory? category;
  final AppLogContext context;
  final Object? exceptionObject;

  @override
  String get key => TalkerKey.fromLogLevel(logLevel ?? LogLevel.debug);

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) {
    final buffer = StringBuffer();
    buffer.write(displayTitleWithTime(timeFormat: timeFormat));
    buffer.write(displayMessage);
    if (context.isNotEmpty) {
      buffer.write('\ncontext: $context');
    }
    if (exceptionObject != null) {
      buffer.write('\nerror: $exceptionObject');
    }
    if (stackTrace != null) {
      buffer.write('\nstackTrace: $stackTrace');
    }
    return buffer.toString();
  }

  static String _buildMessage(String message, AppLogCategory? category) {
    if (category == null) {
      return message;
    }
    return '[${category.key}] $message';
  }
}

class AppTalkerObserver extends TalkerObserver {
  const AppTalkerObserver(this._store);

  final LogHistoryStore _store;

  @override
  void onError(TalkerError err) {
    unawaited(_store.append(_toRecord(err)));
  }

  @override
  void onException(TalkerException err) {
    unawaited(_store.append(_toRecord(err)));
  }

  @override
  void onLog(TalkerData log) {
    unawaited(_store.append(_toRecord(log)));
  }

  AppLogRecord _toRecord(TalkerData data) {
    final category = switch (data) {
      AppTalkerLog log => log.category?.key,
      _ when data.key == TalkerKey.route => AppLogCategory.navigation.key,
      _ when (data.key ?? '').startsWith('riverpod-') =>
        AppLogCategory.provider.key,
      _ => null,
    };
    final context = switch (data) {
      AppTalkerLog log when log.context.isNotEmpty => log.context,
      _ => null,
    };
    return AppLogRecord(
      timestamp: data.time,
      level: (data.logLevel ?? LogLevel.debug).name,
      category: category,
      message: data.message ?? '',
      context: context,
      error: data.error?.toString() ?? data.exception?.toString(),
      stackTrace: data.stackTrace?.toString(),
    );
  }
}

Map<String, Object?> sanitizeContext(Map<String, Object?> input) {
  final result = <String, Object?>{};
  for (final entry in input.entries) {
    result[entry.key] = _sanitizeValue(entry.key, entry.value);
  }
  return result;
}

Object? _sanitizeValue(String key, Object? value) {
  if (value == null) {
    return null;
  }
  final normalizedKey = key.toLowerCase();
  if (normalizedKey.contains('customerphone') || normalizedKey == 'phone') {
    final text = value.toString();
    if (text.length <= 4) {
      return '***';
    }
    return '${text.substring(0, 2)}***${text.substring(text.length - 2)}';
  }
  if (normalizedKey.contains('address')) {
    return '[redacted-address]';
  }
  if (normalizedKey.contains('payloadjson')) {
    return '[redacted-payload ${value.toString().length} chars]';
  }
  if (value is String) {
    if (value.length > 256) {
      return '${value.substring(0, 128)}...[truncated ${value.length} chars]';
    }
    return value;
  }
  if (value is num || value is bool) {
    return value;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Enum) {
    return value.name;
  }
  if (value is Map) {
    return value.map(
      (mapKey, mapValue) => MapEntry(
        mapKey.toString(),
        _sanitizeValue(mapKey.toString(), mapValue),
      ),
    );
  }
  if (value is Iterable) {
    return value
        .map((item) => _sanitizeValue(key, item))
        .toList(growable: false);
  }
  return value.toString();
}

Talker buildTalker({required LogHistoryStore logHistoryStore}) {
  final settings = TalkerSettings(
    maxHistoryItems: 2000,
    titles: const {
      TalkerKey.critical: 'critical',
      TalkerKey.error: 'error',
      TalkerKey.warning: 'warning',
      TalkerKey.info: 'info',
      TalkerKey.debug: 'debug',
      TalkerKey.verbose: 'trace',
    },
    colors: {
      TalkerKey.critical: AnsiPen()..red(bold: true),
      TalkerKey.error: AnsiPen()..xterm(202),
      TalkerKey.exception: AnsiPen()..xterm(202),
      TalkerKey.warning: AnsiPen()..xterm(214),
      TalkerKey.info: AnsiPen()..xterm(45),
      TalkerKey.debug: AnsiPen()..xterm(245),
      TalkerKey.verbose: AnsiPen()..xterm(245),
      TalkerKey.route: AnsiPen()..xterm(45),
      TalkerKey.riverpodAdd: AnsiPen()..xterm(45),
      TalkerKey.riverpodUpdate: AnsiPen()..xterm(45),
      TalkerKey.riverpodDispose: AnsiPen()..xterm(245),
      TalkerKey.riverpodFail: AnsiPen()..xterm(202),
    },
  );
  return TalkerFlutter.init(
    settings: settings,
    observer: AppTalkerObserver(logHistoryStore),
  );
}

TalkerScreenTheme buildTalkerScreenTheme(ThemeData theme) {
  return TalkerScreenTheme.fromTheme(theme, {
    TalkerKey.critical: const Color(0xFFD32F2F),
    TalkerKey.error: const Color(0xFFE65100),
    TalkerKey.exception: const Color(0xFFE65100),
    TalkerKey.warning: const Color(0xFFFFB300),
    TalkerKey.info: const Color(0xFF00ACC1),
    TalkerKey.debug: const Color(0xFF9E9E9E),
    TalkerKey.verbose: const Color(0xFF9E9E9E),
    TalkerKey.route: const Color(0xFF00ACC1),
    TalkerKey.riverpodAdd: const Color(0xFF00ACC1),
    TalkerKey.riverpodUpdate: const Color(0xFF00ACC1),
    TalkerKey.riverpodDispose: const Color(0xFF9E9E9E),
    TalkerKey.riverpodFail: const Color(0xFFE65100),
  });
}
