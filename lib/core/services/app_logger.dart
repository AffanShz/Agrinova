import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name.toUpperCase(),
        'tag': tag,
        'message': message,
        'error': error?.toString(),
        'stackTrace': stackTrace?.toString(),
      };
}

/// Layanan pencatatan log terpusat dengan sanitasi PII (Personally Identifiable Information).
/// Mencegah data sensitif seperti password, API key, token JWT, dan email bocor ke log.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  final List<AppLogEntry> _inMemoryLogs = [];
  static const int _maxLogs = 200;

  List<AppLogEntry> get logs => List.unmodifiable(_inMemoryLogs);

  static final _emailRegex = RegExp(
    r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+',
  );

  static final _tokenRegex = RegExp(
    r'(Bearer\s+[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*)|(sbp_[a-zA-Z0-9]{32,})|(sk-[a-zA-Z0-9]{20,})|(Mid-server-[a-zA-Z0-9-_]{20,})',
    caseSensitive: false,
  );

  static final _passwordRegex = RegExp(
    r'(password|kata_sandi|secret|api_key|token)["\s:=]+([^\s,;"]+)',
    caseSensitive: false,
  );

  /// Menyaring data sensitif dari pesan teks
  String sanitize(String input) {
    if (input.isEmpty) return input;
    var sanitized = input.replaceAllMapped(_emailRegex, (match) {
      final email = match.group(0)!;
      final parts = email.split('@');
      if (parts[0].length <= 2) {
        return '***@${parts[1]}';
      }
      return '${parts[0].substring(0, 2)}***@${parts[1]}';
    });

    sanitized = sanitized.replaceAllMapped(_tokenRegex, (_) => '[REDACTED_TOKEN]');

    sanitized = sanitized.replaceAllMapped(_passwordRegex, (match) {
      final key = match.group(1);
      return '$key: [REDACTED]';
    });

    return sanitized;
  }

  void _addLog(LogLevel level, String tag, String message,
      [Object? error, StackTrace? stackTrace]) {
    final sanitizedMessage = sanitize(message);
    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: sanitizedMessage,
      error: error,
      stackTrace: stackTrace,
    );

    if (_inMemoryLogs.length >= _maxLogs) {
      _inMemoryLogs.removeAt(0);
    }
    _inMemoryLogs.add(entry);

    if (kDebugMode) {
      final label = '[${level.name.toUpperCase()}][$tag] $sanitizedMessage';
      if (error != null) {
        debugPrint('$label | Error: $error');
      } else {
        debugPrint(label);
      }
    }
  }

  void debug(String tag, String message) =>
      _addLog(LogLevel.debug, tag, message);

  void info(String tag, String message) =>
      _addLog(LogLevel.info, tag, message);

  void warning(String tag, String message, [Object? error]) =>
      _addLog(LogLevel.warning, tag, message, error);

  void error(String tag, String message,
          [Object? error, StackTrace? stackTrace]) =>
      _addLog(LogLevel.error, tag, message, error, stackTrace);

  /// Inisialisasi global crash & unhandled exception observer
  static void initCrashReporting() {
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger().error(
        'FlutterError',
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLogger().error(
        'PlatformDispatcher',
        error.toString(),
        error,
        stack,
      );
      return true;
    };
  }
}
