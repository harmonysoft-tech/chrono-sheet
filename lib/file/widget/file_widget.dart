import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/google/account/service/google_login_enforcer.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/ui/dimension.dart';
import 'package:chrono_sheet/ui/widget_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/router.dart';
import '../state/file_state.dart';

final _logger = getNamedLogger();

class FileWidget extends ConsumerWidget {
  const FileWidget({super.key});

  Future<void> _selectFile(BuildContext context, WidgetRef ref) async {
    final loginEnforcer = ref.read(googleLoginEnforcer);
    final loggedIn = await loginEnforcer.ensureLogin(context, _logger, (l10n) => l10n.errorNotLoggedInGoogle);
    if (loggedIn && context.mounted) {
      context.push(AppRoute.chooseSheet);
    }
  }

  String _getFileName(String? fileName, AppLocalizations l10n) {
    String result = fileName ?? l10n.textNoFileIsSelected;
    if (result.length > 10) {
      result = "${result.substring(0, 10)}...";
    }
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileStateAsync = ref.watch(fileStateManagerProvider);
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      key: AppWidgetKey.selectFile,
      onTap: () => _selectFile(context, ref),
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
              data: (fileState) => _getFileName(fileState.selected?.name, l10n),
              orElse: () => _getFileName(null, l10n),
            ),
          )
        ],
      ),
    );
  }
}
