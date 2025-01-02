import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/file/state/files_state.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = getNamedLogger();

class ViewSelectedFileWidget extends ConsumerWidget {
  const ViewSelectedFileWidget({super.key});

  Future<void> _viewFile(GoogleFile file, BuildContext context) async {
    final appUri = Uri.parse("google-sheets://docs.google.com/spreadsheets/d/${file.id}/edit");
    final browserUri = Uri.parse("https://docs.google.com/spreadsheets/d/${file.id}/edit");
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      // we experienced that canLaunchUrl() returns 'false' for all urls under android. That is due to the fact
      // that by default applications are not allowed to query information about other applications.
      // It's possible to overcome that by configuring 'android.intent.action.VIEW' intent action query
      // and/or requesting 'android.permission.QUERY_ALL_PACKAGES' permission. However, it looks easier to
      // just try to launch and handle an exception (if any).
      // More details can be found at https://developer.android.com/training/package-visibility
      await launchUrl(appUri);
      return;
    } catch (_) {
      _logger.info("failed to open the sheet document '${file.name}' in the google sheets application");
      try {
        await launchUrl(browserUri);
      } catch (_) {
        _logger.info("failed to open the sheet document '${file.name}' in the browser");
        messenger.showSnackBar(SnackBar(content: Text(l10n.errorCanNotOpenFile)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(filesInfoHolderProvider);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: filesAsync.maybeWhen(
        data: (files) => files.selected == null
            ? DisabledViewFileButton()
            : ElevatedButton.icon(
                onPressed: () => _viewFile(files.selected!, context),
                icon: Icon(Icons.open_in_new),
                label: Text(l10n.actionViewSelectedFile),
              ),
        orElse: () => DisabledViewFileButton(),
      ),
    );
  }
}

class DisabledViewFileButton extends StatelessWidget {
  const DisabledViewFileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ElevatedButton.icon(
      onPressed: null,
      icon: Icon(Icons.open_in_new),
      label: Text(l10n.actionViewSelectedFile),
    );
  }
}
