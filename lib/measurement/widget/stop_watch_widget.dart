import 'dart:async';

import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/sheet/updater/sheet_updater.dart';
import 'package:chrono_sheet/util/date_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StopWatchWidget extends ConsumerStatefulWidget {

  const StopWatchWidget({super.key});

  @override
  StopWatchState createState() => StopWatchState();
}

class StopWatchState extends ConsumerState<StopWatchWidget> {

  Timer? _timer;
  DateTime _lastMeasurementTime = clockProvider.now();
  Duration _measuredDuration = Duration.zero;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick(Timer _) {
    setState(() {
      if (_running) {
        final now = clockProvider.now();
        _measuredDuration += now.difference(_lastMeasurementTime);
        _lastMeasurementTime = now;
      }
    });
  }

  void _toggle() {
    setState(() {
      _running = !_running;
      if (_running) {
        _lastMeasurementTime = clockProvider.now();
      }
      if (_running || _hasMeasurement()) {
        _timer ??= Timer.periodic(Duration(milliseconds: 100), _tick);
      } else {
        // we need to show UI changes only if the stopwatch is running
        // or if it's stopped and some duration is already measured
        // (the duration blinks in this case)
        _timer?.cancel();
        _timer = null;
      }
    });
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
    });
  }

  void _saveMeasurement() {
    setState(() {
      _running = false;
      final durationToStore = _measuredDuration;
      _measuredDuration = Duration.zero;
      _timer?.cancel();
      _timer = null;
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedOpacity(
              opacity:
              (!_running && _measuredDuration > Duration.zero)
                  ? (clockProvider.now().millisecond % 1000 < 500) ? 0.0 : 1.0
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
            ElevatedButton.icon(
              onPressed: _hasMeasurement() ? _reset : null,
              icon: Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).textReset),
            ),
            SizedBox(width: 20),
            ElevatedButton.icon(
              onPressed: _hasMeasurement() ? _saveMeasurement : null,
              icon: Icon(Icons.save),
              label: Text(AppLocalizations.of(context).textSave)
            ),
          ],
        )
      ],
    );
  }
}