import 'dart:io';

import 'package:chrono_sheet/google/drive/service/google_drive_service.dart';
import 'package:chrono_sheet/google/login/state/google_helper.dart';
import 'package:chrono_sheet/google/login/state/google_login_state.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:chrono_sheet/sheet/updater/update_service.dart';
import 'package:fpdart/fpdart.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

import '../../context/test_context.dart';
import '../../verification/verification_util.dart';

final _logger = getNamedLogger();

class GoogleTestUtil {
  static int _contextCounter = 0;

  static Future<void> setUp([String? rootLocalDirPath]) async {
    final rootLocalDirPathToUse = rootLocalDirPath ?? TestContext.current.rootLocalDirPath;
    final googleClient = await getTestGoogleClient(
      ++_contextCounter,
      rootLocalDirPathToUse,
    );
    setDataOverride(CachedGoogleIdentity(id: "dummy-id", email: "dummy-email"), googleClient);
  }

  static Future<void> tearDown() async {
    final service = GoogleDriveService();

    final remoteDirId = await service.getDirectoryId(TestContext.current.rootRemoteDataDirPath);
    if (remoteDirId != null) {
      await service.delete(remoteDirId);
    }
    resetOverride();
  }

  static Future<AutoRefreshingAuthClient> getTestGoogleClient(int counter, String rootLocalPath) async {
    final filePath = "$rootLocalPath/auto-test-service-account$counter.json";
    final file = File(filePath);
    if (!await file.exists()) {
      if (counter > 1) {
        return await getTestGoogleClient(1, rootLocalPath);
      } else {
        throw AssertionError("file ${file.path} doesn't exist");
      }
    }
    _logger.info("using test google credentials from file '$filePath'");
    final json = await file.readAsString();
    final credentials = ServiceAccountCredentials.fromJson(json);
    final scopes = [SheetsApi.spreadsheetsScope, SheetsApi.driveFileScope];
    return await clientViaServiceAccount(credentials, scopes);
  }

  static Future<String> getGoogleFileId(String path) async {
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

  static Future<void> clearSheet(String remoteFileId, String sheetTitle) async {
    final gData = await getGoogleClientData();
    final sheetsApi = SheetsApi(gData.authenticatedClient);
    await sheetsApi.spreadsheets.values.clear(ClearValuesRequest(), remoteFileId, sheetTitle);
  }

  static Future<void> verifySheetState(String fileId, String expectedSheetContent) async {
    final expectedValues = _parse(expectedSheetContent);

    final gData = await getGoogleClientData();
    final sheetsApi = SheetsApi(gData.authenticatedClient);
    final gSheet = await sheetsApi.spreadsheets.get(fileId);
    final sheetName = gSheet.sheets?.firstOrNull?.properties?.title;
    if (sheetName == null) {
      throw AssertionError("google file '$fileId' does not have sheets");
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
          "detected expectation mismatch at address $address - expected: '$expected', actual: $actual",
        );
      }
    });
  }

  static Future<void> setSheetState(String remoteFileId, String remoteFileName, String sheetTitle, String raw) async {
    final values = _parse(raw);
    final gData = await getGoogleClientData();
    final sheetsApi = SheetsApi(gData.authenticatedClient);
    await setSheetCellValues(
      values: values,
      sheetTitle: sheetTitle,
      sheetDocumentId: remoteFileId,
      sheetFileName: remoteFileName,
      api: sheetsApi,
    );
  }

  static Map<CellAddress, String> _parse(String rawContent) {
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
