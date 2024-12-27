import 'package:chrono_sheet/file/model/google_file.dart';
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

  void _onFileSelected(GoogleFile file, WidgetRef ref) {
    ref.read(filesInfoHolderProvider.notifier).select(file);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(filesInfoHolderProvider);
    final localization = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide()
        ),
      ),
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _selectFile(context),
              // we use Container here in order for it to fill all the
              // available space occupied by Expanded. Otherwise
              // GestureDetector reacts only on taps on the nested Text.
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: asyncData.when(
                    data: (data) => Text(
                      data.selected?.name ?? localization.hintSelectFile,
                      style: data.selected == null
                          ? TextStyle(color: theme.disabledColor)
                          : null,
                    ),
                    error: (_, __) => Text(
                      localization.hintSelectFile,
                      style: TextStyle(color: theme.disabledColor),
                    ),
                    loading: () => Text(
                      localization.hintSelectFile,
                      style: TextStyle(color: theme.disabledColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
          asyncData.when(
            data: (data) => PopupMenuButton<GoogleFile>(
              icon: Icon(Icons.arrow_drop_down),
              onSelected: (file) => _onFileSelected(file, ref),
              itemBuilder: (context) => data.recent.map((file) {
                return PopupMenuItem(
                  value: file,
                  child: Text(file.name),
                );
              }).toList(),
            ),
              error: (_, __) => PopupMenuButton(
                icon: Icon(Icons.arrow_drop_down),
                itemBuilder: (context) => [],
              ),
              loading: () =>  PopupMenuButton(
                icon: Icon(Icons.arrow_drop_down),
                itemBuilder: (context) => [],
              ),
          ),
        ],
      )
    );
  }
}
