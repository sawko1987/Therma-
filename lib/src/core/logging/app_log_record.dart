import 'dart:convert';

class AppLogRecord {
  const AppLogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
    this.category,
    this.context,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final String level;
  final String message;
  final String? category;
  final Map<String, Object?>? context;
  final String? error;
  final String? stackTrace;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level,
    'category': category,
    'message': message,
    'context': context,
    'error': error,
    'stackTrace': stackTrace,
  };

  String toJsonLine() => jsonEncode(toJson());

  factory AppLogRecord.fromJson(Map<String, Object?> json) {
    return AppLogRecord(
      timestamp: DateTime.parse(json['timestamp']! as String),
      level: json['level']! as String,
      category: json['category'] as String?,
      message: json['message']! as String,
      context: (json['context'] as Map?)?.cast<String, Object?>(),
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  factory AppLogRecord.fromJsonLine(String line) {
    return AppLogRecord.fromJson(
      (jsonDecode(line) as Map).cast<String, Object?>(),
    );
  }
}
