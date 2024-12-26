import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../generated/app_localizations.dart';
import '../state/files_state.dart';

class SelectedFileWidget extends ConsumerWidget {

  final GlobalKey _historyButtonKey = GlobalKey();

  SelectedFileWidget({super.key});

  void _selectFile(BuildContext context) async {
    context.push(AppRoute.chooseSheet);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFiles = ref.watch(filesInfoHolderProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
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
                          data: (data) =>
                              _fileWidget(data.selected?.name, context),
                          error: (_, __) => _fileWidget(null, context),
                          loading: () => _fileWidget(null, context)),
                    )
                )
            ),
          ),
        ),
        IconButton(
          key: _historyButtonKey,
          onPressed: asyncFiles.when(
            data: (data) => data.recent.isNotEmpty
                ? () => _showRecent(data.recent, ref)
                : null,
            error: (_, __) => null,
            loading: () => null,
          ),
          icon: Icon(Icons.history),
          iconSize: 40.0,
        )
      ],
    );
  }

  void _showRecent(List<GoogleFile> recent, WidgetRef ref) async {
    final BuildContext context = _historyButtonKey.currentContext!;
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    final x = position.dx + size.width;
    final y = position.dy + size.height;

    final selected = await showMenu(
        context: context,
        position: RelativeRect.fromLTRB(x, y, x, y),
        items: recent.map((file) => PopupMenuItem(
          value: file,
          child: Text(file.name),
        )).toList(),
    );
    if (selected != null) {
      ref.read(filesInfoHolderProvider.notifier).select(selected);
    }
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
