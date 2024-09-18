import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '/main.dart';

/// Prints all logs with `level >= Logger.level` even in production.
class VariableFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // Always print in debug mode
    if (kDebugMode) {
      return true;
    }
    // If the setting is unavailable, return false
    if (sharedStorage.getBool("enable_logging") ?? false) {
      return true;
    }
    return false;
  }
}

/// SimpleLogger from logger package. Following changes were made:
/// Better time formatting (no date, only hours, minutes and seconds)
/// Print whole message with color, not just the prefix
/// Also the logs are written to a file asynchronously
class BetterSimplePrinter extends LogPrinter {
  static final levelPrefixes = {
    Level.trace: '[T]',
    Level.debug: '[D]',
    Level.info: '[I]',
    Level.warning: '[W]',
    Level.error: '[E]',
    Level.fatal: '[FATAL]',
  };

  static final levelColors = {
    Level.trace: const AnsiColor.fg(2), // green
    Level.debug: const AnsiColor.fg(246), // gray
    Level.info: const AnsiColor.fg(12), // blue
    Level.warning: const AnsiColor.fg(208), // yellow
    Level.error: const AnsiColor.fg(196), // red
    Level.fatal: const AnsiColor.fg(199), // purple
  };

  File? logFile;

  BetterSimplePrinter() {
    _initLogFiles();
  }

  void _initLogFiles() {
    getApplicationSupportDirectory().then((directory) {
      final logDir = Directory('${directory.path}/logs').path;
      if (!(Directory('${directory.path}/logs').existsSync())) {
        Directory('${directory.path}/logs').createSync();
        logger.i("Created log directory at $logDir");
      } else {
        // move last log file to begin writing new one before rotation is done
        // rotation files takes quite a while and slows down the app startup
        // (the whole app is forced to wait for the logger to init to avoid losing some of the initial logs)
        File('$logDir/current.log').renameSync('$logDir/current.log.old');
        _rotateLogFiles(logDir);
      }

      logFile = File('$logDir/current.log');
      // Print header to log file
      logFile!
          .writeAsStringSync('Log Date: ${DateTime.now()}\n\n', flush: true);
      logger.i("Log file initialized at ${logFile!.path}");
      // Warn about logging being disabled
      if (!kDebugMode &&
          (sharedStorage.getBool("enable_debug_logs") ?? false)) {
        logger.e(
            "Logging is currently disabled. Enable it in settings to see logs.");
      }
    });
  }

  Future<void> _rotateLogFiles(String logDir) async {
    logger.i("Rotating log files");
    // Delete log.prev-4 if exists
    if (await File('$logDir/prev-4.log').exists()) {
      await File('$logDir/prev-4.log').delete();
    }
    // Shift other logs
    if (await File('$logDir/prev-3.log').exists()) {
      await File('$logDir/prev-3.log').rename('$logDir/prev-4.log');
    }
    if (await File('$logDir/prev-2.log').exists()) {
      await File('$logDir/prev-2.log').rename('$logDir/prev-3.log');
    }
    if (await File('$logDir/prev.log').exists()) {
      await File('$logDir/prev.log').rename('$logDir/prev-2.log');
    }
    if (await File('$logDir/current.log.old').exists()) {
      await File('$logDir/current.log.old').rename('$logDir/prev.log');
    }
    logger.i("Finished rotating log files");
  }

  Future<void> exportLogs() async {
    final zipEncoder = ZipFileEncoder();
    final logsDir = await getApplicationSupportDirectory();
    final logsDirPath = Directory('${logsDir.path}/logs');
    final tempDir = await getTemporaryDirectory();
    final tempDirPath = Directory("${tempDir.path}/log-export");

    if (!logsDirPath.existsSync() || logsDirPath.listSync().isEmpty) {
      logger.w("Logs directory not found or empty, nothing was exported");
      throw Exception(
          "Logs directory not found or empty, nothing was exported");
    }

    logger.d("Deleting and recreating temp dir at ${tempDirPath.path}");
    if (tempDirPath.existsSync()) {
      tempDirPath.deleteSync(recursive: true);
    }
    await tempDirPath.create(recursive: true);

    // Create a temporary file for the zip
    final zipFilePath = '${tempDirPath.path}/logs.zip';
    zipEncoder.create(zipFilePath);
    logger.d("Adding logs to zip");
    for (var file in logsDirPath.listSync()) {
      if (file is File) {
        zipEncoder.addFile(file);
      }
    }
    zipEncoder.close();

    logger.d("Exporting logs");
    final shareResult = await Share.shareXFiles([XFile(zipFilePath)]);
    if (shareResult.status != ShareResultStatus.success) {
      logger.e("Failed to share logs");
      throw Exception("Failed to share logs");
    }
  }

  @override
  List<String> log(LogEvent event) {
    var messageStr = _stringifyMessage(event.message);
    var errorStr = event.error != null ? '  ERROR: ${event.error}' : '';
    String timeStr =
        "${event.time.hour}:${event.time.minute}:${event.time.second}.${event.time.millisecond}";
    var logStr = '${levelPrefixes[event.level]!} $timeStr $messageStr$errorStr';

    // Make sure to wait for log to be written as otherwise most messages will be lost
    logFile?.writeAsStringSync('$logStr\n', mode: FileMode.append, flush: true);

    return [levelColors[event.level]!(logStr)];
  }

  String _stringifyMessage(dynamic message) {
    final finalMessage = message is Function ? message() : message;
    if (finalMessage is Map || finalMessage is Iterable) {
      var encoder = const JsonEncoder.withIndent(null);
      return encoder.convert(finalMessage);
    } else {
      return finalMessage.toString();
    }
  }
}
