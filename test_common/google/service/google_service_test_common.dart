import 'dart:io';

import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

Future<AutoRefreshingAuthClient> getTestGoogleClient(int counter, String rootPath) async {
  final file = File("$rootPath/auto-test-service-account$counter.json");
  if (!await file.exists()) {
    throw AssertionError("file ${file.path} doesn't exist");
  }
  final json = await file.readAsString();
  final credentials = ServiceAccountCredentials.fromJson(json);
  final scopes = [
    SheetsApi.spreadsheetsScope,
    SheetsApi.driveFileScope,
  ];
  return await clientViaServiceAccount(credentials, scopes);
}