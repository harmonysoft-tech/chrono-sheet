import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../http/AuthenticatedHttpClient.dart';

Future<AuthenticatedHttpClient> getAuthenticatedGoogleApiHttpClient() async {
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