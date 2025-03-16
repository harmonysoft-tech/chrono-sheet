import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/router.dart';
import '../state/file_state.dart';

class FileWidget extends ConsumerWidget {
  const FileWidget({super.key});

  Future<void> _selectFile(BuildContext context) async {
    context.push(AppRoute.chooseSheet);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileStateAsync = ref.watch(fileStateManagerProvider);
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => _selectFile(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/icon/google-sheet.png",
            width: AppDimension.iconSize,
            height: AppDimension.iconSize,
            fit: BoxFit.contain,
          ),
          SizedBox(width: AppDimension.elementPadding),
          Text(
            fileStateAsync.maybeWhen(
              data: (fileState) => fileState.selected?.name ?? l10n.textNoFileIsSelected,
              orElse: () => l10n.textNoFileIsSelected,
            ),
          )
        ],
      ),
    );
  }
}
