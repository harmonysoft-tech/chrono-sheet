import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/main.dart';
import 'package:chrono_sheet/util/rich_text_util.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

class GoogleAccountRationaleWidget {
  static Future<void> show([Set<String> missingScopes = const {}]) async {
    return showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        String title;
        if (missingScopes.isEmpty) {
          title = l10n.titlePermissionsRationale;
        } else {
          title = l10n.errorPermissionsNotGranted;
          for (final scope in missingScopes) {
            title += "\n * **";
            switch (scope) {
              case drive.DriveApi.driveScope:
                title += l10n.permissionDrive;
                break;
              case sheets.SheetsApi.spreadsheetsScope:
                title += l10n.permissionSheets;
                break;
              default:
                title += scope;
            }
            title += "**";
          }
        }
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: theme.textTheme.headlineLarge?.fontSize ?? 32.0),
              SizedBox(width: 16),
              Expanded(child: buildRichText(title, theme.textTheme)),
            ],
          ),
          content: buildRichText(AppLocalizations.of(context).textPermissionsRationale, theme.textTheme),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).actionOk),
            ),
          ],
        );
      },
    );
  }
}
