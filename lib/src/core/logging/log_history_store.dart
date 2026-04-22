import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_log_record.dart';

class LogHistoryStore {
  LogHistoryStore({
    Future<Directory> Function()? getLogsDirectory,
    this.maxFiles = 5,
    this.maxFileSizeBytes = 512 * 1024,
  }) : _getLogsDirectory =
           getLogsDirectory ??
           (() async =>
               Directory(p.join(Directory.systemTemp.path, 'smartcalc_logs')));

  final Future<Directory> Function() _getLogsDirectory;
  final int maxFiles;
  final int maxFileSizeBytes;
  Future<void> _pendingWrite = Future<void>.value();

  static const _metadataFileName = '.log-history-meta.json';
  static const _filePrefix = 'smartcalc';
  static const _fileSuffix = '.jsonl';

  Future<void> append(AppLogRecord record) async {
    _pendingWrite = _pendingWrite.then((_) async {
      final file = await _resolveWritableFile();
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(
        '${record.toJsonLine()}\n',
        mode: FileMode.append,
        flush: true,
      );
    });
    await _pendingWrite;
  }

  Future<File> exportCurrentLogFile() async {
    final source = await currentFile();
    final directory = await _ensureDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final target = File(
      p.join(directory.path, 'smartcalc-export-$timestamp.jsonl'),
    );
    if (await source.exists()) {
      return source.copy(target.path);
    }
    await target.writeAsString('', flush: true);
    return target;
  }

  Future<File> currentFile() async {
    final directory = await _ensureDirectory();
    final metadata = await _readMetadata(directory);
    final file = File(
      p.join(directory.path, _buildFileName(metadata.currentFileIndex)),
    );
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<List<AppLogRecord>> readHistory() async {
    final directory = await _ensureDirectory();
    final files = await listLogFiles();
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    final result = <AppLogRecord>[];
    for (final file in files) {
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) {
          continue;
        }
        result.add(AppLogRecord.fromJsonLine(line));
      }
    }
    if (!await directory.exists()) {
      return const [];
    }
    return result;
  }

  Future<List<File>> listLogFiles() async {
    final directory = await _ensureDirectory();
    if (!await directory.exists()) {
      return const [];
    }
    final entities = await directory.list().toList();
    return entities
        .whereType<File>()
        .where(
          (file) =>
              p.basename(file.path).startsWith(_filePrefix) &&
              file.path.endsWith(_fileSuffix),
        )
        .toList(growable: false);
  }

  Future<File> _resolveWritableFile() async {
    final directory = await _ensureDirectory();
    final metadata = await _readMetadata(directory);
    var file = File(
      p.join(directory.path, _buildFileName(metadata.currentFileIndex)),
    );
    if (await file.exists() && await file.length() >= maxFileSizeBytes) {
      final nextIndex = (metadata.currentFileIndex + 1) % maxFiles;
      file = File(p.join(directory.path, _buildFileName(nextIndex)));
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
      } else {
        await file.create(recursive: true);
      }
      await _writeMetadata(
        directory,
        _LogStoreMetadata(currentFileIndex: nextIndex),
      );
    } else if (!await file.exists()) {
      await file.create(recursive: true);
      await _writeMetadata(directory, metadata);
    }
    return file;
  }

  Future<Directory> _ensureDirectory() async {
    final directory = await _getLogsDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<_LogStoreMetadata> _readMetadata(Directory directory) async {
    final file = File(p.join(directory.path, _metadataFileName));
    if (!await file.exists()) {
      final metadata = const _LogStoreMetadata(currentFileIndex: 0);
      await _writeMetadata(directory, metadata);
      return metadata;
    }
    final json = jsonDecode(await file.readAsString()) as Map;
    return _LogStoreMetadata.fromJson(json.cast<String, Object?>());
  }

  Future<void> _writeMetadata(
    Directory directory,
    _LogStoreMetadata metadata,
  ) async {
    final file = File(p.join(directory.path, _metadataFileName));
    await file.writeAsString(jsonEncode(metadata.toJson()), flush: true);
  }

  String _buildFileName(int index) => '$_filePrefix-$index$_fileSuffix';
}

class _LogStoreMetadata {
  const _LogStoreMetadata({required this.currentFileIndex});

  final int currentFileIndex;

  Map<String, Object?> toJson() => {'currentFileIndex': currentFileIndex};

  factory _LogStoreMetadata.fromJson(Map<String, Object?> json) {
    return _LogStoreMetadata(
      currentFileIndex: json['currentFileIndex']! as int,
    );
  }
}
