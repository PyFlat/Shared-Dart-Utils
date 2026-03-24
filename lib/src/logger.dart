import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:intl/intl.dart';

class LogStyle {
  final String _ansi;

  const LogStyle._internal(this._ansi);

  factory LogStyle.custom(String ansiCode) => LogStyle._internal(ansiCode);

  static const none = LogStyle._internal('');
  static const bold = LogStyle._internal('\x1B[1m');
  static const italic = LogStyle._internal('\x1B[3m');
  static const underline = LogStyle._internal('\x1B[4m');

  static const black = LogStyle._internal('\x1B[30m');
  static const red = LogStyle._internal('\x1B[31m');
  static const green = LogStyle._internal('\x1B[32m');
  static const yellow = LogStyle._internal('\x1B[33m');
  static const blue = LogStyle._internal('\x1B[34m');
  static const magenta = LogStyle._internal('\x1B[35m');
  static const cyan = LogStyle._internal('\x1B[36m');
  static const white = LogStyle._internal('\x1B[37m');

  LogStyle operator +(LogStyle other) =>
      LogStyle._internal(_ansi + other._ansi);

  @override
  String toString() => _ansi;

  String apply(String message) => '$_ansi$message\x1B[0m';
}

enum LogLevel { debug, info, warn, error, critical }

const _defaultLevelStyle = {
  LogLevel.debug: LogStyle.cyan,
  LogLevel.info: LogStyle.green,
  LogLevel.warn: LogStyle.yellow,
  LogLevel.error: LogStyle.red,
  LogLevel.critical: LogStyle.magenta,
};

class LogService {
  final String name;
  bool disable;

  LogService(this.name, {this.disable = false});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogService &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name.toUpperCase();
}

class _FileInfo {
  final File file;
  final DateTime modified;
  _FileInfo(this.file, this.modified);
}

class Logger {
  IOSink? _fileSink;

  final List<LogService> services;

  final _streamController = StreamController<String>.broadcast();

  bool printTimestamp;
  bool writeToFile;
  bool deleteOldLogFilesOnStartup;

  int keepDays;

  int onlyKeepLastLogFiles;

  late int longestServiceNameLength;
  late int longestLogLevelNameLength;

  final Map<int, String> _activeTasks = {};
  int _taskIdCounter = 0;

  SendPort? isolateForwardPort;

  Logger({
    required this.services,
    this.writeToFile = true,
    this.printTimestamp = true,
    this.deleteOldLogFilesOnStartup = true,
    this.keepDays = 14,
    this.onlyKeepLastLogFiles = -1,
    this.isolateForwardPort,
  }) {
    if (writeToFile) {
      Directory('logs').createSync(recursive: true);

      final timestamp = DateFormat(
        "yyyy-MM-dd_HH-mm-ss",
      ).format(DateTime.now());
      final file = File('logs/$timestamp.log');

      _fileSink = file.openWrite(mode: FileMode.write);
    }

    longestServiceNameLength =
        (services.map((e) => e.name.length).reduce((a, b) => a > b ? a : b)) +
        2;

    longestLogLevelNameLength =
        (LogLevel.values
            .map((e) => e.name.length)
            .reduce((a, b) => a > b ? a : b)) +
        2;
    cleanLogs(
      deleteOldLogFilesOnStartup: deleteOldLogFilesOnStartup,
      keepDays: keepDays,
      onlyKeepLastLogFiles: onlyKeepLastLogFiles,
    );
  }

  void cleanLogs({
    bool deleteOldLogFilesOnStartup = true,
    int keepDays = 14,
    int onlyKeepLastLogFiles = 0,
  }) {
    final logDir = Directory('logs');
    if (!logDir.existsSync()) return;

    final now = DateTime.now();
    final files = logDir.listSync().whereType<File>().toList();

    final fileInfos = files.map((file) {
      final stat = file.statSync();
      return _FileInfo(file, stat.modified);
    }).toList();

    if (deleteOldLogFilesOnStartup) {
      for (var info in fileInfos) {
        if (now.difference(info.modified).inDays > keepDays) {
          try {
            info.file.deleteSync();
          } catch (_) {}
        }
      }
    }

    if (onlyKeepLastLogFiles > 0) {
      fileInfos.sort((a, b) => b.modified.compareTo(a.modified));

      for (var i = onlyKeepLastLogFiles; i < fileInfos.length; i++) {
        try {
          fileInfos[i].file.deleteSync();
        } catch (_) {}
      }
    }
  }

  String _formatLine(
    LogService service,
    LogLevel level,
    String message, {
    LogStyle? style,
    bool includeTimestamp = false,
  }) {
    final timestamp = DateFormat(
      "yyyy.MM.dd-HH:mm:ss.SSS",
    ).format(DateTime.now());

    final levelStr = "[${level.name.toUpperCase()}]".padRight(
      longestLogLevelNameLength,
    );

    final serviceStr = "[${service.name.toUpperCase()}]".padRight(
      longestServiceNameLength,
    );

    final baseLine = '$levelStr$serviceStr $message';

    final rawLine = includeTimestamp ? '[$timestamp]$baseLine' : baseLine;

    final effectiveStyle =
        (style ?? _defaultLevelStyle[level] ?? LogStyle.none);

    return effectiveStyle.apply(rawLine);
  }

  void log(
    LogService service,
    LogLevel level,
    String message, {
    LogStyle? style,
    bool printRawMessage = false,
    bool noPrint = false,
  }) {
    if (isolateForwardPort != null) {
      isolateForwardPort!.send({
        'type': 'log',
        'service': service.name,
        'level': level.name,
        'message': message,
        'style': style?.toString() ?? '',
        'printRawMessage': printRawMessage,
        'noPrint': noPrint,
      });
      return;
    }

    final timestamped = _formatLine(
      service,
      level,
      message,
      style: style,
      includeTimestamp: true,
    );

    _fileSink?.writeln(timestamped);
    _streamController.add(timestamped);

    if (service.disable || noPrint) return;

    final output = printRawMessage
        ? message
        : (printTimestamp
              ? timestamped
              : _formatLine(service, level, message, style: style));

    if (stdout.hasTerminal && _activeTasks.isNotEmpty) {
      for (var i = 0; i < _activeTasks.length; i++) {
        stdout.write('\x1B[1A\x1B[2K');
      }

      stdout.writeln(output);

      for (var taskLine in _activeTasks.values) {
        stdout.writeln(taskLine);
      }

      stdout.write('\x1B[G');
    } else {
      stdout.writeln(output);
    }
  }

  Future<T> timedTask<T>(
    LogService service,
    LogLevel level,
    String message,
    Future<T> Function() task, {
    LogStyle? style,
    bool noPrint = false,
  }) async {
    if (isolateForwardPort != null || noPrint) {
      final stopwatch = Stopwatch()..start();
      try {
        final result = await task();
        final ms = stopwatch.elapsedMilliseconds;
        final sec = (ms / 1000).toStringAsFixed(2);
        final timeReport =
            '[${sec.padLeft(6)}s | ${ms.toString().padLeft(6)}ms]';

        log(
          service,
          level,
          '$timeReport $message',
          style: style,
          noPrint: noPrint,
        );
        return result;
      } catch (e) {
        log(service, level, '$message FAILED', style: style, noPrint: noPrint);
        rethrow;
      }
    }

    final id = _taskIdCounter++;
    final stopwatch = Stopwatch()..start();

    if (stdout.hasTerminal) {
      _activeTasks[id] = "";
      stdout.writeln();
    }

    void updateDisplay() {
      if (service.disable || !stdout.hasTerminal) return;

      final elapsed = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
      final timedMessage = '$message (${elapsed}s)';
      final formatted = _formatLine(
        service,
        level,
        timedMessage,
        style: style,
        includeTimestamp: printTimestamp,
      );

      _activeTasks[id] = formatted;

      final keys = _activeTasks.keys.toList();
      int linesUp = keys.length - keys.indexOf(id);

      stdout.write('\x1B[${linesUp}A\r\x1B[2K$formatted\x1B[${linesUp}B\r');
    }

    final timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => updateDisplay(),
    );

    try {
      final result = await task();
      timer.cancel();
      _removeTask(id);

      final ms = stopwatch.elapsedMilliseconds;
      final sec = (ms / 1000).toStringAsFixed(2);

      final timeReport = '[${sec.padLeft(6)}s | ${ms.toString().padLeft(6)}ms]';

      log(service, level, '$timeReport $message', style: style);
      return result;
    } catch (e) {
      timer.cancel();
      _removeTask(id);
      log(service, level, '$message FAILED', style: style);
      rethrow;
    }
  }

  void _removeTask(int id) {
    if (!stdout.hasTerminal) {
      _activeTasks.remove(id);
      return;
    }

    for (var i = 0; i < _activeTasks.length; i++) {
      stdout.write('\x1B[1A\x1B[2K');
    }

    _activeTasks.remove(id);

    for (var taskLine in _activeTasks.values) {
      stdout.writeln(taskLine);
    }
  }

  Stream<String> get logStream => _streamController.stream;

  void shutdown() {
    _fileSink?.close();
    _streamController.close();
  }
}

class ServiceLogger {
  final Logger _logger;
  final LogService service;

  const ServiceLogger(this._logger, this.service);

  void debug(
    String m, {
    LogStyle? style,
    bool printRawMessage = false,
    bool noPrint = false,
  }) => _logger.log(
    service,
    LogLevel.debug,
    m,
    style: style,
    printRawMessage: printRawMessage,
    noPrint: noPrint,
  );

  void info(
    String m, {
    LogStyle? style,
    bool printRawMessage = false,
    bool noPrint = false,
  }) => _logger.log(
    service,
    LogLevel.info,
    m,
    style: style,
    printRawMessage: printRawMessage,
    noPrint: noPrint,
  );

  void warn(
    String m, {
    LogStyle? style,
    bool printRawMessage = false,
    bool noPrint = false,
  }) => _logger.log(
    service,
    LogLevel.warn,
    m,
    style: style,
    printRawMessage: printRawMessage,
    noPrint: noPrint,
  );

  void error(
    String m, {
    LogStyle? style,
    bool printRawMessage = false,
    bool noPrint = false,
  }) => _logger.log(
    service,
    LogLevel.error,
    m,
    style: style,
    printRawMessage: printRawMessage,
    noPrint: noPrint,
  );

  void critical(
    String m, {
    LogStyle? style,
    bool printRawMessage = false,
    bool noPrint = false,
  }) => _logger.log(
    service,
    LogLevel.critical,
    m,
    style: style,
    printRawMessage: printRawMessage,
    noPrint: noPrint,
  );

  Future<T> timed<T>(
    String message,
    Future<T> Function() task, {
    LogLevel level = LogLevel.info,
    LogStyle? style,
    bool noPrint = false,
  }) => _logger.timedTask(
    service,
    level,
    message,
    task,
    style: style,
    noPrint: noPrint,
  );
}
