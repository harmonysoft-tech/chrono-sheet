import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final regex = RegExp(r'package:([^:]+)');

final _logger = getNamedLogger();

Logger getNamedLogger() {
  final stackTrace = StackTrace.current.toString();
  final matches = regex.allMatches(stackTrace).toList();
  var name = '';
  if (matches.length > 1) {
    name = matches[1][0] ?? '';
    final i = name.lastIndexOf('/');
    if (i > 0) {
      name = name.substring(i + 1);
    }
  }
  return Logger(name);
}

void setupLogging() {
  var level = Level.INFO;
  if (kDebugMode) {
    level = Level.ALL;
  }
  Logger.root.level = level;
  Logger.root.onRecord.listen((record) {
    var message = record.message;
    if (record.error != null) {
      message += "\n";
      message += record.error.toString();
    }
    if (record.stackTrace != null) {
      message += "\n";
      message += record.stackTrace.toString();
    }
    // ignore: avoid_print
    print('${record.time} [${record.level}] ${record.loggerName}: $message');

    if (record.level.compareTo(Level.INFO) > 0) {
      if (record.error == null) {
        FirebaseCrashlytics.instance.recordError(message, record.stackTrace);
      } else {
        FirebaseCrashlytics.instance.recordError(
          record.error,
          record.stackTrace,
          reason: "[${record.level}] ${record.message}"
        );
      }
    }
  });
  _logger.info("configured level $level for logging");
}
