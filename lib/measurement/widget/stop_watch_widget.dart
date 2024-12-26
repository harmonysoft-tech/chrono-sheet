import 'dart:async';

import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/measurement_state.dart';

class StopWatchWidget extends ConsumerStatefulWidget {

  const StopWatchWidget({super.key});

  @override
  StopWatchState createState() => StopWatchState();
}

class StopWatchState extends ConsumerState<StopWatchWidget> {

  late Timer _timer;
  DateTime _lastMeasurementTime = DateTime.now();
  bool _running = false;

  void _toggle() {
    if (_running) {
      _timer.cancel();
    } else {
      _lastMeasurementTime = DateTime.now();
      _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        setState(() {
          final now = DateTime.now();
          ref.read(measurementStateProvider.notifier).increment(
              now.difference(_lastMeasurementTime)
          );
          _lastMeasurementTime = now;
        });
      });
    }
    setState(() {
      _running = !_running;
    });
  }

  void _reset() {
    setState(() {
      _timer.cancel();
      _running = false;
      ref.read(measurementStateProvider.notifier).reset();
    });
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final measurement = ref.watch(measurementStateProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: GestureDetector(
            onTap: _toggle,
            child: Text(
              _formatTime(measurement),
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: measurement != Duration.zero ? _reset : null,
              icon: Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).textReset),
            ),
            SizedBox(width: 20),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.save),
              label: Text(AppLocalizations.of(context).textSave)
            ),
          ],
        )
      ],
    );
  }
}