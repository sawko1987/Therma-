import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/logging/app_logging.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';

void main() {
  test(
    'AppLogger routes levels and categories and persists jsonl history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'app_logger_test_',
      );
      final store = LogHistoryStore(getLogsDirectory: () async => directory);
      final talker = buildTalker(logHistoryStore: store);
      final logger = AppLogger(talker);

      logger.debug('Debug event', category: AppLogCategory.ui);
      logger.info('Info event', category: AppLogCategory.report);
      logger.warning('Warning event', category: AppLogCategory.storage);
      logger.error('Error event', category: AppLogCategory.repository);
      logger.critical('Critical event', category: AppLogCategory.calculation);

      final history = talker.history;
      expect(history.length, 5);
      expect(history.first.key, 'debug');
      expect(history.last.key, 'critical');

      final persisted = await _waitForHistory(store, expectedCount: 5);
      expect(persisted.length, 5);
      expect(persisted.first.category, AppLogCategory.ui.key);
      expect(persisted.last.level, 'critical');
    },
  );

  test('sanitizeContext masks phone address and payloadJson', () {
    final sanitized = sanitizeContext({
      'customerPhone': '+79991234567',
      'address': 'Москва, ул. Пушкина, дом 1',
      'payloadJson': '{"large":true}',
    });

    expect(sanitized['customerPhone'], '+7***67');
    expect(sanitized['address'], '[redacted-address]');
    expect(sanitized['payloadJson'], '[redacted-payload 14 chars]');
  });

  test('LogHistoryStore rotates files and restores history', () async {
    final directory = await Directory.systemTemp.createTemp('log_store_test_');
    final store = LogHistoryStore(
      getLogsDirectory: () async => directory,
      maxFiles: 2,
      maxFileSizeBytes: 120,
    );

    for (var index = 0; index < 6; index++) {
      await store.append(
        AppLogRecord(
          timestamp: DateTime(2026, 1, 1, 0, 0, index),
          level: 'info',
          category: AppLogCategory.storage.key,
          message: 'entry-$index-${'x' * 50}',
        ),
      );
    }

    final files = await store.listLogFiles();
    expect(files.length, 2);

    final restored = LogHistoryStore(getLogsDirectory: () async => directory);
    final history = await restored.readHistory();
    expect(history, isNotEmpty);
    expect(history.map((item) => item.message).join('\n'), contains('entry-5'));
  });
}

Future<List<AppLogRecord>> _waitForHistory(
  LogHistoryStore store, {
  required int expectedCount,
}) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final history = await store.readHistory();
    if (history.length >= expectedCount) {
      return history;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return store.readHistory();
}
