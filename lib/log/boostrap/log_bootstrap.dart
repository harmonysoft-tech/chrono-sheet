import 'package:chrono_sheet/di/di.dart';
import 'package:chrono_sheet/log/state/log_state.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../util/log_util.dart';

final _logger = getNamedLogger();

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
    final messageToPrint = "${record.time} [${record.level}] ${record.loggerName}: $message";
    // ignore: avoid_print
    print(messageToPrint);
    diContainer?.read(logStateManagerProvider.notifier).onLogRecord(messageToPrint);

    if (!kDebugMode) {
      if (record.level.compareTo(Level.INFO) > 0) {
        if (record.error == null) {
          FirebaseCrashlytics.instance.recordError(message, record.stackTrace);
        } else {
          FirebaseCrashlytics.instance
              .recordError(record.error, record.stackTrace, reason: "[${record.level}] ${record.message}");
        }
      }
    }
  });
  _logger.info("configured level $level for logging");
}
