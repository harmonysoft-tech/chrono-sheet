import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/src/client.dart' as http;

import '../http/AuthenticatedHttpClient.dart';

http.Client? _clientOverride;

void setClientOverride(http.Client client) {
  _clientOverride = client;
}

Future<http.Client> getAuthenticatedGoogleApiHttpClient() async {
  final client = _clientOverride;
  if (client != null) {
    return client;
  }
  final signIn = GoogleSignIn(scopes: [
    sheets.SheetsApi.spreadsheetsScope,
    sheets.SheetsApi.driveReadonlyScope
  ]);
  var googleAccount = await signIn.signInSilently();
  if (googleAccount == null) {
    throw StateError("can not login into google");
  }
  final headers = await googleAccount.authHeaders;
  return AuthenticatedHttpClient(headers);
}