import 'dart:io';

import 'package:chrono_sheet/google/drive/service/google_drive_service.dart';
import 'package:chrono_sheet/google/login/state/google_helper.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:fpdart/fpdart.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

import '../../verification/verification_util.dart';

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

Future<String> getGoogleFileId(String path) async {
  final service = GoogleDriveService();
  return await VerificationUtil.getDataWithWaiting("get id of google file '$path'", () async {
    final result = await service.getFileId(path);
    if (result == null) {
      return Either.left("the file is not found");
    } else {
      return Either.right(result);
    }
  });
}

Future<void> verifySheetState(String googleFilePath, String expectedSheetContent) async {
  final expectedValues = _parse(expectedSheetContent);

  final service = GoogleDriveService();
  final fileId = await service.getFileId(googleFilePath);
  if (fileId == null) {
    throw AssertionError("google file '$googleFilePath' does not exist");
  }

  final gData = await getGoogleClientData();
  final sheetsApi = SheetsApi(gData.authenticatedClient);
  final gSheet = await sheetsApi.spreadsheets.get(fileId);
  final sheetName = gSheet.sheets?.firstOrNull?.properties?.title;
  if (sheetName == null) {
    throw AssertionError("google file '$googleFilePath' does not have sheets");
  }

  final valueRange = await sheetsApi.spreadsheets.values.get(fileId, sheetName, majorDimension: "ROWS");
  final actualValues = parseSheetValues(valueRange.values!);

  // google sheet api doesn't return values for empty rows, that's why we need to do custom comparison here
  expectedValues.forEach((address, expected) {
    final actual = actualValues[address];
    if (actual == null && expected.isEmpty) {
      return;
    }
    if (actual != expected) {
      throw AssertionError(
          "detected expectation mismatch at address $address - expected: '$expected', actual: $actual");
    }
  });
}

Map<CellAddress, String> _parse(String rawContent) {
  final context = _ParsingContext(rawContent.trim());
  while (context.parsingOffset < context.raw.length) {
    int columnSeparatorIndex = context.raw.indexOf("|", context.parsingOffset);
    int lineEndIndex = context.raw.indexOf("\n", context.parsingOffset);
    if (columnSeparatorIndex >= 0 && lineEndIndex >= 0) {
      if (columnSeparatorIndex < lineEndIndex) {
        context.onColumnSeparator(columnSeparatorIndex);
      } else {
        context.onNewLine(lineEndIndex);
      }
    } else if (lineEndIndex >= 0) {
      context.onNewLine(lineEndIndex);
    } else if (columnSeparatorIndex >= 0) {
      context.onColumnSeparator(columnSeparatorIndex);
    } else {
      break;
    }
  }
  if (context.parsingOffset < context.raw.length) {
    context.parsed[CellAddress(context.row, context.column)] = context.raw.substring(context.parsingOffset).trim();
  }
  if (context.raw.endsWith("|")) {
    // to handle situations like below:
    //  date | total | category1
    //  d    | 1     |
    context.parsed[CellAddress(context.row, context.column)] = "";
  }
  return context.parsed;
}


class _ParsingContext {
  final String raw;
  int parsingOffset = 0;
  final Map<CellAddress, String> parsed = {};
  int row = 0;
  int column = 0;

  _ParsingContext(this.raw);

  void onColumnSeparator(int columnSeparatorIndex) {
    final value = raw.substring(parsingOffset, columnSeparatorIndex).trim();
    parsingOffset = columnSeparatorIndex + 1;
    parsed[CellAddress(row, column++)] = value;
  }

  void onNewLine(int lineEndIndex) {
    final value = raw.substring(parsingOffset, lineEndIndex).trim();
    parsingOffset = lineEndIndex + 1;
    parsed[CellAddress(row++, column)] = value;
    column = 0;
  }
}
