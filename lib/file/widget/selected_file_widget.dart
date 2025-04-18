import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/file/service/creator/google_file_creator.dart';
import 'package:chrono_sheet/router/router.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../generated/app_localizations.dart';
import '../state/file_state.dart';

class SelectedFileWidget extends ConsumerWidget {
  const SelectedFileWidget({super.key});

  void _selectFile(BuildContext context) async {
    context.push(AppRoute.chooseSheet);
  }

  void _onFileSelected(GoogleFile file, WidgetRef ref) {
    ref.read(fileStateManagerProvider.notifier).select(file);
  }

  void _createFile(BuildContext widgetContext, WidgetRef ref) {
    final controller = TextEditingController();
    final hasNameNotifier = ValueNotifier(false);
    controller.addListener(() => hasNameNotifier.value = controller.text.trim().isNotEmpty);
    final l10n = AppLocalizations.of(widgetContext);
    showDialog(
      context: widgetContext,
      builder: (context) => AlertDialog(
        title: Text(l10n.titleAddNewFile),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.labelFileName,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          ValueListenableBuilder(
            valueListenable: hasNameNotifier,
            builder: (context, enabled, child) => ElevatedButton(
              onPressed: enabled
                  ? () {
                      ref.read(createServiceProvider).create(controller.text).then((result) {
                        GoogleFile? file;
                        switch (result) {
                          case Created():
                            file = result.file;
                            break;
                          case AlreadyExists():
                            file = result.file;
                            break;
                          case Error():
                            break;
                        }
                        if (file != null) {
                          ref.read(fileStateManagerProvider.notifier).select(file);
                        }
                      });
                      Navigator.of(context).pop();
                    }
                  : null,
              child: Text(l10n.actionAdd),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(fileStateManagerProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide()),
          ),
          child: Row(
            children: [
              asyncData.maybeWhen(
                data: (data) => data.operationInProgress == FileOperation.creation
                    ? CircularProgressIndicator()
                    : IconButton(
                        onPressed: () => _createFile(context, ref),
                        icon: Icon(
                          Icons.add,
                          key: AppWidgetKey.createFile,
                        ),
                      ),
                orElse: () => IconButton(
                  onPressed: () => _createFile(context, ref),
                  icon: Icon(
                    key: AppWidgetKey.createFile,
                    Icons.add,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _selectFile(context),
                icon: Icon(
                  Icons.search,
                  key: AppWidgetKey.selectFile,
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: asyncData.when(
                      data: (data) => Text(
                        data.operationInProgress == FileOperation.none
                            ? data.selected?.name ?? ""
                            : "",
                        style: (data.selected == null || data.operationInProgress != FileOperation.none)
                            ? TextStyle(color: theme.disabledColor)
                            : null,
                      ),
                      error: (_, __) => Text(
                        "",
                        style: TextStyle(color: theme.disabledColor),
                      ),
                      loading: () => Text(
                        "",
                        style: TextStyle(color: theme.disabledColor),
                      ),
                    ),
                  ),
                ),
              ),
              asyncData.maybeWhen(
                data: (data) => data.operationInProgress == FileOperation.none
                    ? PopupMenuButton<GoogleFile>(
                        icon: Icon(Icons.arrow_drop_down),
                        onSelected: (file) => _onFileSelected(file, ref),
                        itemBuilder: (context) => data.recent.map((file) {
                          return PopupMenuItem(
                            value: file,
                            child: Text(file.name),
                          );
                        }).toList(),
                      )
                    : DisabledPopupMenuItem(),
                orElse: () => DisabledPopupMenuItem(),
              ),
            ],
          ),
        ),
        SizedBox(height: AppDimension.labelVerticalInset),
        Text(
          l10n.labelFile,
          style: TextStyle(fontSize: theme.textTheme.labelMedium?.fontSize),
        ),
      ],
    );
  }
}

class DisabledPopupMenuItem extends StatelessWidget {
  const DisabledPopupMenuItem({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: Icon(Icons.arrow_drop_down),
      itemBuilder: (context) => [],
    );
  }
}
