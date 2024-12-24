import 'dart:async';

import 'package:flutter/material.dart';

class AndroidStopWatch extends StatefulWidget {
  const AndroidStopWatch({super.key});

  @override
  AndroidStopWatchState createState()  => AndroidStopWatchState();
}

class AndroidStopWatchState extends State<AndroidStopWatch> {

  late Timer _timer;
  Duration _elapsedTime = Duration.zero;
  DateTime _lastMeasurementTime = DateTime.now();
  bool _running = false;

  void _startStop() {
    if (_running) {
      _timer.cancel();
    } else {
      _lastMeasurementTime = DateTime.now();
      _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
        setState(() {
          final now = DateTime.now();
          _elapsedTime += now.difference(_lastMeasurementTime);
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
      _elapsedTime = Duration.zero;
      _running = false;
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
  void dispose() {
    if (_running) {
      _timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("Stopwatch", style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Text(
              _formatTime(_elapsedTime),
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startStop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _running ? Colors.red : Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  _running ? "Stop" : "Start",
                  style: TextStyle(fontSize: 20),
                ),
              ),
              SizedBox(width: 20),
              ElevatedButton(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  "Reset",
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}