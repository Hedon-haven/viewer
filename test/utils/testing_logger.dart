import 'dart:convert';

import 'package:logger/logger.dart';

/// This is a simplified version of the main BetterSimplePrinter for testing
/// purposes
/// It does not create any files and does not import any additional external
/// packages
class TestingPrinter extends LogPrinter {
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

  @override
  List<String> log(LogEvent event) {
    var messageStr = _stringifyMessage(event.message);
    var errorStr = event.error != null ? '  ERROR: ${event.error}' : '';
    // Timestamp with leading zeros
    String timeStr = "${event.time.hour.toString().padLeft(2, '0')}"
        ":${event.time.minute.toString().padLeft(2, '0')}"
        ":${event.time.second.toString().padLeft(2, '0')}"
        ".${event.time.millisecond.toString().padLeft(3, '0')}";
    var logStr = '${levelPrefixes[event.level]!} $timeStr $messageStr$errorStr';
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
