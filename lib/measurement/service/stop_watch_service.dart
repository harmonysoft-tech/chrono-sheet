import 'dart:async';

import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../category/state/categories_state.dart';
import '../../sheet/updater/sheet_updater.dart';
import '../../util/date_util.dart';
import '../model/measurement.dart';
import '../model/measurements_state.dart';

part 'stop_watch_service.g.dart';

final _logger = getNamedLogger();

class StopWatchState {
  bool running;
  Duration measuredDuration;

  StopWatchState({bool? running, Duration? measuredDuration})
    : running = running ?? false,
      measuredDuration = measuredDuration ?? Duration.zero;

  StopWatchState copyWith({bool? running, Duration? measuredDuration}) {
    return StopWatchState(
      running: running ?? this.running,
      measuredDuration: measuredDuration ?? this.measuredDuration,
    );
  }
}

@Riverpod(keepAlive: true)
class StopWatchService extends _$StopWatchService {
  static const _preferencesKey = "measurement.duration.ongoing";
  static final _storeFrequency = Duration(seconds: 15);

  final _prefs = SharedPreferencesAsync();
  Timer? _timer;
  DateTime _lastMeasurementTime = clockProvider.now();
  DateTime _lastStoreTime = clockProvider.now();

  @override
  StopWatchState build() {
    _prefs.getString(_preferencesKey).then((storedValue) {
      if (storedValue == null || storedValue.isEmpty) {
        _logger.fine("no cached stop watch state is found for the preferences key '$_preferencesKey'");
        return;
      }
      _logger.fine(
        "found the following cached stop watch state for the preferences key '$_preferencesKey': $storedValue",
      );
      final i = storedValue.indexOf(":");
      if (i <= 0 || i >= storedValue.length) {
        return;
      }
      final storedDurationMillis = int.tryParse(storedValue.substring(0, i));
      if (storedDurationMillis == null) {
        return;
      }
      Duration storedDuration = Duration(milliseconds: storedDurationMillis);

      final storedLastMeasurementTimeMillis = int.tryParse(storedValue.substring(i + 1));
      DateTime? storedLastMeasurementTime;
      if (storedLastMeasurementTimeMillis != null) {
        storedLastMeasurementTime = DateTime.fromMillisecondsSinceEpoch(storedLastMeasurementTimeMillis);
      }
      _logger.fine("found stored duration $storedDuration, last measurement time: $storedLastMeasurementTime");

      final now = clockProvider.now();

      Duration runInBackgroundDuration = Duration();
      if (storedLastMeasurementTime != null) {
        runInBackgroundDuration = now.difference(storedLastMeasurementTime);
      }

      _lastMeasurementTime = now;

      state = StopWatchState(
        measuredDuration: storedDuration + runInBackgroundDuration,
        running: storedLastMeasurementTime != null,
      );
      _startTimerIfNecessary();
    });
    return StopWatchState();
  }

  void _startTimerIfNecessary() {
    _timer ??= Timer.periodic(Duration(milliseconds: 100), _tick);
  }

  void _tick(Timer _) {
    final Duration measuredDuration;
    if (state.running) {
      final now = clockProvider.now();
      measuredDuration = state.measuredDuration + now.difference(_lastMeasurementTime);
      _lastMeasurementTime = now;
      if (now.difference(_lastStoreTime) > _storeFrequency) {
        final valueToStore = "${measuredDuration.inMilliseconds}:${now.millisecondsSinceEpoch}";
        _prefs.setString(_preferencesKey, valueToStore).then((_) {
          _logger.fine("stored last stop watch measurement:  $valueToStore");
          _lastStoreTime = now;
        });
      }
    } else {
      measuredDuration = state.measuredDuration;
    }

    // we want to update the state even if the stopwatch is not running because the measured time should blink then
    state = state.copyWith(measuredDuration: measuredDuration);
  }

  String format(Duration duration) {
    String t(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final milliseconds = duration.inMilliseconds.remainder(1000) ~/ 10;
    if (hours > 0) {
      return "${t(hours)}:${t(minutes)}:${t(seconds)}.${t(milliseconds)}";
    } else if (minutes > 0) {
      return "${t(minutes)}:${t(seconds)}.${t(milliseconds)}";
    } else {
      return "${t(seconds)}.${t(milliseconds)}";
    }
  }

  void toggle() {
    final running = !state.running;
    if (running) {
      final now = clockProvider.now();
      _lastMeasurementTime = now;
      _lastStoreTime = _lastMeasurementTime;
      _prefs.setString(_preferencesKey, "${state.measuredDuration.inMilliseconds}:${now.millisecondsSinceEpoch}");
    } else {
      _prefs.setString(_preferencesKey, "${state.measuredDuration.inMilliseconds}:");
    }

    if (running || hasMeasurement()) {
      _startTimerIfNecessary();
    } else {
      // we need to show UI changes only if the stopwatch is running
      // or if it's stopped and some duration is already measured
      // (the duration blinks in this case)
      _timer?.cancel();
      _timer = null;
    }

    state = state.copyWith(running: running);
  }

  bool hasMeasurement() {
    return state.measuredDuration > Duration.zero;
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _prefs.setString(_preferencesKey, "");
    state = StopWatchState();
  }

  Future<SaveMeasurementState> saveMeasurement() async {
    final duration = state.measuredDuration;
    if (state.measuredDuration <= Duration.zero) {
      _logger.fine("skipped a request to store non-positive measurement $duration");
      state = StopWatchState();
      return SaveMeasurementState.success;
    }

    state = StopWatchState();
    _timer?.cancel();
    _timer = null;
    _prefs.setString(_preferencesKey, "");

    return ref.read(sheetUpdaterProvider.notifier).prepareToStore(duration).then((fileAndCategoryResult) {
      return fileAndCategoryResult.match(
        (error) => error,
        (fileAndCategory) => _saveMeasurement(duration, fileAndCategory),
      );
    });
  }

  Future<SaveMeasurementState> _saveMeasurement(Duration duration, FileAndCategory fileAndCategory) async {
    final durationToStore = duration.inMinutes;
    if (durationToStore <= 0) {
      _logger.fine("skipped a request to store non-positive rounded measurement $duration");
      state = StopWatchState();
      ref.read(categoryStateManagerProvider.notifier).onMeasurement(fileAndCategory.category);
      return SaveMeasurementState.success;
    }

    await ref.read(categoryStateManagerProvider.notifier).onMeasurement(fileAndCategory.category);

    await ref
        .read(measurementsProvider.notifier)
        .save(
          Measurement(file: fileAndCategory.file, category: fileAndCategory.category, durationSeconds: durationToStore),
        );
    return await ref.read(sheetUpdaterProvider.notifier).storeUnsavedMeasurements();
  }
}
