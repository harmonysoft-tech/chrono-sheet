import 'package:chrono_sheet/generated/app_localizations.dart';
import 'package:chrono_sheet/logging/logging.dart';
import 'package:chrono_sheet/main.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/src/client.dart' as http;
import '../http/AuthenticatedHttpClient.dart';
import '../util/rich_text_util.dart';

final _logger = getNamedLogger();

final signIn = GoogleSignIn(scopes: [sheets.SheetsApi.spreadsheetsScope, sheets.SheetsApi.driveFileScope]);
http.Client? _clientOverride;

void setClientOverride(http.Client client) {
  _clientOverride = client;
}

Future<http.Client> getAuthenticatedGoogleApiHttpClient() async {
  final client = _clientOverride;
  if (client != null) {
    return client;
  }
  _logger.fine("trying to sign in silently");
  var googleAccount = await signIn.signInSilently();
  if (googleAccount == null) {
    _logger.fine("failed to sign in silently, signing in normally");
    await showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          content: buildRichText(AppLocalizations.of(context).textPermissionsRationale, theme.textTheme),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).textOk),
            ),
          ],
        );
      },
    );
    googleAccount = await signIn.signIn();
  } else {
    _logger.fine("successfully signed in silently");
  }
  if (googleAccount == null) {
    throw StateError("can not login into google");
  }
  final headers = await googleAccount.authHeaders;
  return AuthenticatedHttpClient(headers);
}
