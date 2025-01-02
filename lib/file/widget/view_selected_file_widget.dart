import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/file/state/files_state.dart';
import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewSelectedFileWidget extends ConsumerWidget {
  const ViewSelectedFileWidget({super.key});

  Future<void> _viewFile(GoogleFile file, BuildContext context) async {
    final appUri = Uri.parse("google-sheets://docs.google.com/spreadsheets/d/${file.id}/edit");
    final browserUri = Uri.parse("https://docs.google.com/spreadsheets/d/${file.id}/edit");
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else if (await canLaunchUrl(browserUri)) {
      await launchUrl(browserUri);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorCanNotOpenFile)));
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
