import 'dart:async';
import 'dart:io';

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

  Logger({
    required this.services,
    this.writeToFile = true,
    this.printTimestamp = true,
    this.deleteOldLogFilesOnStartup = true,
    this.keepDays = 14,
    this.onlyKeepLastLogFiles = -1,
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

  void log(
    LogService service,
    LogLevel level,
    String message, {
    LogStyle? style,
    bool printRawMessage = false,
    bool noPrint = false,
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
    final timestampedLine = '[$timestamp]$baseLine';

    final effectiveStyle =
        (style ?? _defaultLevelStyle[level] ?? LogStyle.none);

    final coloredTimestamped = effectiveStyle.apply(timestampedLine);
    final coloredBase = effectiveStyle.apply(baseLine);

    if (_fileSink != null) {
      _fileSink!.writeln(coloredTimestamped);
    }

    _streamController.add(timestampedLine);

    if (!service.disable && !printRawMessage && !noPrint) {
      stdout.writeln(printTimestamp ? coloredTimestamped : coloredBase);
    }

    if (printRawMessage) {
      stdout.writeln(message);
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
}
