import 'package:chrono_sheet/measurement/widget/stop_watch_widget.dart';
import 'package:chrono_sheet/file/selected/widget/selected_file_widget.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {

  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chrono Sheet'), // TODO implement i18n
      ),
      body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StopWatch(),
              SizedBox(height: 24),
              SelectedFileWidget(),
            ],
          )),
    );
  }
}