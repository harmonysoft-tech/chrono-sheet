import 'dart:convert';

import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/main.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

import '../../../http/AuthenticatedHttpClient.dart';
import '../../../log/util/log_util.dart';
import '../../../util/rich_text_util.dart';

final _logger = getNamedLogger();

final signIn = GoogleSignIn(scopes: [
  sheets.SheetsApi.spreadsheetsScope,
  drive.DriveApi.driveScope,
]);
GoogleData? _dataOverride;

void setDataOverride(GoogleIdentity identity, http.Client client) {
  _dataOverride = GoogleData(identity, client);
}

class GoogleData {
  final GoogleIdentity identity;
  final http.Client authenticatedClient;

  GoogleData(this.identity, this.authenticatedClient);
}

Future<GoogleData> getGoogleClientData([background = false]) async {
  final client = _dataOverride;
  if (client != null) {
    return client;
  }
  _logger.fine("trying to sign in silently");
  var googleAccount = await signIn.signInSilently();
  while (true) {
    if (googleAccount == null) {
      _logger.info("failed to sign in silently, signing in normally");
      await _showPermissionsRationale();
      googleAccount = await signIn.signIn();
    } else {
      _logger.info("successfully signed in silently");
    }
    if (googleAccount == null) {
      _logger.info("failed to explicitly sign in into google");
      continue;
    }

    Set<String> missingScopes = await _getMissingScopes(googleAccount);
    if (missingScopes.isNotEmpty) {
      _logger.info("detected that the user didn't provide the following scopes during google login: $missingScopes");
      await _showPermissionsRationale(missingScopes);
      final granted = await signIn.requestScopes(missingScopes.toList());
      if (!granted) {
        _logger.info("didn't get required scopes during google login even after explicit request");
        continue;
      }
      googleAccount = await signIn.signInSilently();
    } else {
      final headers = await googleAccount.authHeaders;
      return GoogleData(googleAccount, AuthenticatedHttpClient(headers));
    }
  }
}

Future<void> _showPermissionsRationale([Set<String> missingScopes = const {}]) {
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
        title: Row(children: [
          Icon(Icons.warning, color: Colors.red, size: theme.textTheme.headlineLarge?.fontSize ?? 32.0),
          SizedBox(width: 16),
          Expanded(child: buildRichText(title, theme.textTheme))
        ]),
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

Future<Set<String>> _getMissingScopes(GoogleSignInAccount account) async {
  final auth = await account.authentication;
  final token = auth.accessToken;
  final response = await http.get(
    Uri.parse('https://oauth2.googleapis.com/tokeninfo?access_token=$token'),
  );
  final result = Set.of(signIn.scopes);
  if (response.statusCode == 200) {
    final tokenInfo = json.decode(response.body);
    final scopes = tokenInfo["scope"]?.toString();
    if (scopes != null) {
      for (final scope in signIn.scopes) {
        if (scopes.contains(scope)) {
          result.remove(scope);
        }
      }
    }
  }
  return result;
}
