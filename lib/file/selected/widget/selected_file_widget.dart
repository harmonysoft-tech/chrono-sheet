import 'package:chrono_sheet/router/router.dart';
import 'package:chrono_sheet/file/selected/model/selected_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SelectedFileWidget extends ConsumerWidget {
  const SelectedFileWidget({super.key});

  void _selectFile(BuildContext context) async {
    context.push(AppRoute.chooseSheet);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(selectedFileProvider);
    return GestureDetector(
      onTap: () => _selectFile(context),
      child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  selectedFile?.name ?? 'tap to select a file', // TODO implement i18n
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
