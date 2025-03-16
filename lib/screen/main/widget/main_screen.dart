import 'package:chrono_sheet/file/widget/file_widget.dart';
import 'package:chrono_sheet/file/widget/view_selected_file_widget.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/google/state/google_login_state.dart';
import 'package:chrono_sheet/hint/widget/hint_widget.dart';
import 'package:chrono_sheet/measurement/widget/stop_watch_widget.dart';
import 'package:chrono_sheet/screen/main/state/main_hint_positions.dart';
import 'package:chrono_sheet/screen/main/widget/menu_menu_button.dart';
import 'package:chrono_sheet/sheet/updater/sheet_updater.dart';
import 'package:chrono_sheet/ui/color.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../category/widget/categories_widget.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  bool _needToShowHint(HintPositionsState state) {
    return _needToDefineFile(state) || _needToHintCategoryCreation(state);
  }

  bool _needToDefineFile(HintPositionsState state) {
    return state.selectFile != null || state.createFile != null;
  }

  bool _needToHintCategoryCreation(HintPositionsState state) {
    return !_needToDefineFile(state) && state.createCategory != null;
  }

  bool _needToHintCategorySelection(HintPositionsState state) {
    return !_needToDefineFile(state) && state.selectCategory != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hintPositions = ref.watch(hintPositionsProvider);
    final l10n = AppLocalizations.of(context);

    return Stack(
      key: AppWidgetKey.mainScreenCanvas,
      children: [
        Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text(AppLocalizations.of(context).appName),
                Spacer(),
                FileWidget(),
                MainMenuButton(),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppDimension.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                StopWatchWidget(),
                SizedBox(height: AppDimension.columnVerticalInset),
                // SelectedFileWidget(),
                // SizedBox(height: AppDimension.columnVerticalInset),
                Expanded(child: CategoriesWidget()),
                SizedBox(height: AppDimension.columnVerticalInset),
                ViewSelectedFileWidget(),
              ],
            ),
          ),
        ),
        if (_needToShowHint(hintPositions)) ...[
          GestureDetector(
            onTap: () => ref.read(sheetUpdaterProvider.notifier).reset(),
            child: Container(
              color: AppColor.hintBelow,
            ),
          )
        ],
        if (hintPositions.createFile != null) ...[
          HintWidget(
            text: l10n.hintCreateFile,
            hintBounds: hintPositions.createFile!,
          ),
        ],
        if (hintPositions.selectFile != null) ...[
          HintWidget(
            text: l10n.hintSelectFile,
            hintBounds: hintPositions.selectFile!,
          ),
        ],
        if (_needToHintCategoryCreation(hintPositions)) ...[
          HintWidget(
            text: l10n.hintCreateCategory,
            hintBounds: hintPositions.createCategory!,
          ),
        ],
        if (_needToHintCategorySelection(hintPositions)) ...[
          HintWidget(
            text: l10n.hintSelectCategory,
            hintBounds: hintPositions.selectCategory!,
          ),
        ],
      ],
    );
  }
}

class LoginWidget extends ConsumerWidget {
  const LoginWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => ref.read(loginStateManagerProvider.notifier).login(),
      icon: Icon(Icons.login),
    );
  }
}
