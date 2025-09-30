import 'dart:io';

import 'package:chrono_sheet/google/account/model/google_account.dart';
import 'package:chrono_sheet/google/account/service/google_http_client_provider.dart';
import 'package:chrono_sheet/google/account/service/google_identity_provider.dart';
import 'package:chrono_sheet/google/drive/service/google_drive_service.dart';
import 'package:chrono_sheet/google/sheet/model/google_sheet_model.dart';
import 'package:chrono_sheet/google/sheet/service/google_sheet_service.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:fpdart/fpdart.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

import '../../context/test_context.dart';
import '../../verification/verification_util.dart';

final _logger = getNamedLogger();

class GoogleTestUtil {
  static int _contextCounter = 0;

  static GoogleSheetService get sheetService => TestContext.current.container.read(googleSheetServiceProvider);

  static Future<void> setUp([String? rootLocalDirPath]) async {
    final rootLocalDirPathToUse = rootLocalDirPath ?? TestContext.current.rootLocalDirPath;
    final googleClient = await getTestGoogleHttpClient(++_contextCounter, rootLocalDirPathToUse);
    GoogleHttpClient.setDataOverride(googleClient);
    GoogleIdentity.setDataOverride(
      AppGoogleIdentity(
        id: "dummy-id",
        email: "dummy-email",
        accessToken: "dummy-token",
        accessTokenExpirationInSeconds: -1,
      )
    );
  }

  static Future<void> tearDown() async {
    final service = TestContext.current.container.read(googleDriveServiceProvider);

    final remoteDirId = await service.getDirectoryId(TestContext.current.rootRemoteDataDirPath);
    if (remoteDirId != null) {
      await service.delete(remoteDirId);
    }
    GoogleIdentity.resetOverride();
    GoogleHttpClient.resetOverride();
  }

  static Future<AutoRefreshingAuthClient> getTestGoogleHttpClient(int counter, String rootLocalPath) async {
    final filePath = "$rootLocalPath/auto-test-service-account$counter.json";
    final file = File(filePath);
    if (!await file.exists()) {
      if (counter > 1) {
        return await getTestGoogleHttpClient(1, rootLocalPath);
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
    final service = TestContext.current.container.read(googleDriveServiceProvider);
    return await VerificationUtil.getDataWithWaiting("get id of google file '$path'", () async {
      final result = await service.getFileId(path);
      if (result == null) {
        return Either.left("the file is not found");
      } else {
        return Either.right(result);
      }
    });
  }

  static Future<SheetsApi> _getApi() async {
    final http = await TestContext.current.container.read(googleHttpClientProvider.future);
    if (http == null) {
      throw StateError("google http client is not set");
    }
    return SheetsApi(http);
  }

  static Future<void> clearSheet(String remoteFileId, String sheetTitle) async {
    final sheetsApi = await _getApi();
    await sheetsApi.spreadsheets.values.clear(ClearValuesRequest(), remoteFileId, sheetTitle);
  }

  static Future<void> verifySheetState(String fileId, String expectedSheetContent) async {
    final expectedValues = _parse(expectedSheetContent);

    final sheetsApi = await _getApi();
    final gSheet = await sheetsApi.spreadsheets.get(fileId);
    final sheetName = gSheet.sheets?.firstOrNull?.properties?.title;
    if (sheetName == null) {
      throw AssertionError("google file '$fileId' does not have sheets");
    }

    final valueRange = await sheetsApi.spreadsheets.values.get(fileId, sheetName, majorDimension: "ROWS");
    final actualValues = sheetService.parseSheetValues(valueRange.values!);

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
    await sheetService.setSheetCellValues(
      values: values,
      sheetTitle: sheetTitle,
      sheetDocumentId: remoteFileId,
      sheetFileName: remoteFileName,
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
