import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

enum LogLevel {
  telemetry, // [TEL] - Telephony events
  microphone, // [MIC] - Microphone events
  vad, // [VAD] - Voice Activity Detection events
  io, // [I/O] - File I/O events
  engine, // [ENG] - Engine state events
  error, // [ERR] - Error events
  info, // [INF] - Info events
}

class ActivityLog {
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  ActivityLog({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  String get formattedTime => DateFormat('HH:mm:ss.SSS').format(timestamp);

  String get prefix {
    switch (level) {
      case LogLevel.telemetry:
        return '[TEL]';
      case LogLevel.microphone:
        return '[MIC]';
      case LogLevel.vad:
        return '[VAD]';
      case LogLevel.io:
        return '[I/O]';
      case LogLevel.engine:
        return '[ENG]';
      case LogLevel.error:
        return '[ERR]';
      case LogLevel.info:
        return '[INF]';
    }
  }

  String get formatted => '$formattedTime $prefix $message';

  @override
  String toString() => formatted;
}

class ActivityLogService extends ChangeNotifier {
  final Logger _logger = Logger();
  final List<ActivityLog> _logs = [];
  static const int maxLogs = 500;

  List<ActivityLog> get logs => _logs;
  List<ActivityLog> get recentLogs => _logs.length > 50 ? _logs.sublist(_logs.length - 50) : _logs;

  void log(String message, LogLevel level) {
    final logEntry = ActivityLog(
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );

    _logs.add(logEntry);

    // Keep log history manageable
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }

    _logger.i(logEntry.formatted);
    notifyListeners();
  }

  void logTelemetry(String message) => log(message, LogLevel.telemetry);
  void logMicrophone(String message) => log(message, LogLevel.microphone);
  void logVAD(String message) => log(message, LogLevel.vad);
  void logIO(String message) => log(message, LogLevel.io);
  void logEngine(String message) => log(message, LogLevel.engine);
  void logError(String message) => log(message, LogLevel.error);
  void logInfo(String message) => log(message, LogLevel.info);

  void clear() {
    _logs.clear();
    _logger.i('Activity log cleared');
    notifyListeners();
  }

  String export() => _logs.map((log) => log.formatted).join('\n');
}
