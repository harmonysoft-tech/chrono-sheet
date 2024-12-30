import 'package:chrono_sheet/logging/logging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/src/client.dart' as http;

import '../http/AuthenticatedHttpClient.dart';

final _logger = getNamedLogger();

final signIn = GoogleSignIn(scopes: [
  sheets.SheetsApi.spreadsheetsScope,
  sheets.SheetsApi.driveReadonlyScope
]);
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
  _logger.fine("silent sign-in results in: $googleAccount");
  if (googleAccount == null) {
    _logger.fine("failed to sign in silently, signing in normally");
    await signIn.signIn();
  }
  googleAccount ??= await signIn.signIn();
  if (googleAccount == null) {
    throw StateError("can not login into google");
  }
  _logger.fine("successfully signed in");
  final headers = await googleAccount.authHeaders;
  return AuthenticatedHttpClient(headers);
}