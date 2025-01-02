import 'dart:async';

import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/logging/logging.dart';
import 'package:chrono_sheet/sheet/updater/sheet_updater.dart';
import 'package:chrono_sheet/util/date_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _logger = getNamedLogger();

class StopWatchWidget extends ConsumerStatefulWidget {
  const StopWatchWidget({super.key});

  @override
  StopWatchState createState() => StopWatchState();
}

class StopWatchState extends ConsumerState<StopWatchWidget> {
  static const _preferencesKey = "measurement.duration.ongoing";
  static final _storeFrequency = Duration(seconds: 15);

  final _prefs = SharedPreferencesAsync();
  Timer? _timer;
  DateTime _lastMeasurementTime = clockProvider.now();
  DateTime _lastStoreTime = clockProvider.now();
  Duration _measuredDuration = Duration.zero;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _prefs.getString(_preferencesKey).then((storedValue) {
      _logger.fine("found the following for preferences key '$_preferencesKey': $storedValue");
      if (storedValue == null || storedValue.isEmpty) {
        return;
      }
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
      setState(() {
        final now = clockProvider.now();

        Duration runInBackgroundDuration = Duration();
        if (storedLastMeasurementTime != null) {
          runInBackgroundDuration = now.difference(storedLastMeasurementTime);
        }

        _lastMeasurementTime = now;
        _measuredDuration = storedDuration + runInBackgroundDuration;
        _running = storedLastMeasurementTime != null;
        _startTimerIfNecessary();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_running && _hasMeasurement()) {
      _prefs.setString(
        _preferencesKey,
        "${_measuredDuration.inMilliseconds}:${clockProvider.now().millisecondsSinceEpoch}",
      );
    }
    super.dispose();
  }

  void _tick(Timer _) {
    setState(() {
      if (_running) {
        final now = clockProvider.now();
        _measuredDuration += now.difference(_lastMeasurementTime);
        _lastMeasurementTime = now;
        if (now.difference(_lastStoreTime) > _storeFrequency) {
          final valueToStore = "${_measuredDuration.inMilliseconds}:${now.millisecondsSinceEpoch}";
          _prefs.setString(_preferencesKey, valueToStore).then((_) {
            _logger.fine("stored last stop watch measurement:  $valueToStore");
            _lastStoreTime = now;
          });
        }
      }
    });
  }

  void _toggle() {
    setState(() {
      _running = !_running;
      if (_running) {
        final now = clockProvider.now();
        _lastMeasurementTime = now;
        _lastStoreTime = _lastMeasurementTime;
        _prefs.setString(_preferencesKey, "${_measuredDuration.inMilliseconds}:${now.millisecondsSinceEpoch}");
      } else {
        _prefs.setString(_preferencesKey, "${_measuredDuration.inMilliseconds}:");
      }
      if (_running || _hasMeasurement()) {
        _startTimerIfNecessary();
      } else {
        // we need to show UI changes only if the stopwatch is running
        // or if it's stopped and some duration is already measured
        // (the duration blinks in this case)
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  void _startTimerIfNecessary() {
    _timer ??= Timer.periodic(Duration(milliseconds: 100), _tick);
  }

  bool _hasMeasurement() {
    return _measuredDuration > Duration.zero;
  }

  void _reset() {
    setState(() {
      _running = false;
      _measuredDuration = Duration.zero;
      _timer?.cancel();
      _timer = null;
      _prefs.setString(_preferencesKey, "");
    });
  }

  void _saveMeasurement() {
    setState(() {
      _running = false;
      final durationToStore = _measuredDuration;
      _measuredDuration = Duration.zero;
      _timer?.cancel();
      _timer = null;
      _prefs.setString(_preferencesKey, "");
      ref.read(sheetUpdaterProvider.notifier).store(durationToStore, AppLocalizations.of(context));
    });
  }

  String _format(Duration duration) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedOpacity(
              opacity: (!_running && _measuredDuration > Duration.zero)
                  ? (clockProvider.now().millisecond % 1000 < 500)
                      ? 0.0
                      : 1.0
                  : 1.0,
              duration: Duration(milliseconds: 200),
              child: Text(
                _format(_measuredDuration),
                style: TextStyle(
                  fontSize: theme.textTheme.displayLarge?.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _running
                ? ElevatedButton.icon(
                    onPressed: _toggle,
                    icon: Icon(Icons.pause),
                    label: Text(l10n.actionPause),
                  )
                : ElevatedButton.icon(
                    onPressed: _toggle,
                    icon: Icon(Icons.play_arrow),
                    label: Text(_hasMeasurement() ? l10n.actionResume : l10n.actionStart),
                  ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _hasMeasurement() ? _reset : null,
              icon: Icon(Icons.refresh),
              label: Text(l10n.actionReset),
            ),
            SizedBox(width: 18),
            ElevatedButton.icon(
              onPressed: _hasMeasurement() ? _saveMeasurement : null,
              icon: Icon(Icons.save),
              label: Text(l10n.actionSave),
            ),
          ],
        )
      ],
    );
  }
}
