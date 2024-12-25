import 'package:chrono_sheet/selected_file/model/selected_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedFileWidget extends ConsumerWidget {
  const SelectedFileWidget({super.key});

  void _selectFile() async {
    print('file selection starts');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(selectedFileProvider);
    return GestureDetector(
      onTap: _selectFile,
      child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  selectedFile?.name ?? 'tap to select a file',
                  style: TextStyle(
                      color: selectedFile?.name == null
                          ? Colors.grey
                          : Colors.black),
                ),
              )
          )
      ),
    );
  }
}
