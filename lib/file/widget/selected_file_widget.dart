import 'package:chrono_sheet/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../generated/app_localizations.dart';
import '../state/files_state.dart';

class SelectedFileWidget extends ConsumerWidget {
  const SelectedFileWidget({super.key});

  void _selectFile(BuildContext context) async {
    context.push(AppRoute.chooseSheet);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFiles = ref.watch(filesInfoHolderProvider);
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
                child: asyncFiles.when(
                    data: (data) => _fileWidget(data.selected?.name, context),
                    error: (_, __) => _fileWidget(null, context),
                    loading: () => _fileWidget(null, context)
                ),
              )
          )
      ),
    );
  }

  Widget _fileWidget(String? text, BuildContext context) {
    return Text(
      text ?? AppLocalizations.of(context).hintSelectFile,
      style: TextStyle(
        // TODO implement use theme
          color:text == null ? Colors.grey : Colors.black
      ),
    );
  }
}
