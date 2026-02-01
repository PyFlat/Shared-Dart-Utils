import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';

const _reset = '\x1B[0m';
const _red = '\x1B[31m';
const _green = '\x1B[32m';
const _yellow = '\x1B[33m';
const _magenta = '\x1B[35m';
const _cyan = '\x1B[36m';
const _blue = '\x1B[34m';
const _bold = '\x1B[1m';
const _italic = '\x1B[3m';

enum LogLevel { start, debug, info, warn, error, critical }

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

  void _log(
    LogService service,
    LogLevel level,
    String message, {
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
    if (_fileSink != null) {
      final coloredLine = '${_colorForLevel(level)}$timestampedLine$_reset';
      _fileSink?.writeln(coloredLine);
    }
    _streamController.add(timestampedLine);
    if (!service.disable && !printRawMessage && !noPrint) {
      final line = printTimestamp ? timestampedLine : baseLine;
      final coloredLine = '${_colorForLevel(level)}$line$_reset';
      stdout.writeln(coloredLine);
    }
    if (printRawMessage) {
      stdout.writeln(message);
    }
  }

  String _colorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.start:
        return _bold + _blue + _italic;
      case LogLevel.debug:
        return _cyan;
      case LogLevel.info:
        return _green;
      case LogLevel.warn:
        return _yellow;
      case LogLevel.error:
        return _red;
      case LogLevel.critical:
        return _magenta;
    }
  }

  void start(
    LogService service,
    String message, {
    bool printRawMessage = false,
    bool noPrint = false,
  }) {
    _log(
      service,
      LogLevel.start,
      message,
      printRawMessage: printRawMessage,
      noPrint: noPrint,
    );
  }

  void debug(
    LogService service,
    String message, {
    bool printRawMessage = false,
    bool noPrint = false,
  }) {
    _log(
      service,
      LogLevel.debug,
      message,
      printRawMessage: printRawMessage,
      noPrint: noPrint,
    );
  }

  void info(
    LogService service,
    String message, {
    bool printRawMessage = false,
    bool noPrint = false,
  }) {
    _log(
      service,
      LogLevel.info,
      message,
      printRawMessage: printRawMessage,
      noPrint: noPrint,
    );
  }

  void warn(
    LogService service,
    String message, {
    bool printRawMessage = false,
    bool noPrint = false,
  }) {
    _log(
      service,
      LogLevel.warn,
      message,
      printRawMessage: printRawMessage,
      noPrint: noPrint,
    );
  }

  void error(
    LogService service,
    String message, {
    bool printRawMessage = false,
    bool noPrint = false,
  }) {
    _log(
      service,
      LogLevel.error,
      message,
      printRawMessage: printRawMessage,
      noPrint: noPrint,
    );
  }

  void critical(
    LogService service,
    String message, {
    bool printRawMessage = false,
    bool noPrint = false,
  }) {
    _log(
      service,
      LogLevel.critical,
      message,
      printRawMessage: printRawMessage,
      noPrint: noPrint,
    );
  }

  Stream<String> get logStream => _streamController.stream;

  void shutdown() {
    _fileSink?.close();
    _streamController.close();
  }
}
