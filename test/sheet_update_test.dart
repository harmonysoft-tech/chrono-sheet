// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:chrono_sheet/category/model/category.dart';
import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/google/google_helper.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:chrono_sheet/sheet/updater/update_service.dart';
import 'package:chrono_sheet/util/date_util.dart' as date;
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v2.dart' as drive;
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/src/service_account_client.dart';
import 'package:googleapis_auth/src/service_account_credentials.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

late SheetsApi _api;
late GoogleFile _file;
final _sheetTitle = "Sheet1";
final SheetUpdateService _service = SheetUpdateService();
DateTime _today = date.fallbackDateFormat.parse("2024-12-29");
String _todayUs = _Format.us.format(_today);
DateTime _yesterday = _today.subtract(Duration(days: 1));
String _yesterdayUs = _Format.us.format(_yesterday);

Future<AutoRefreshingAuthClient> _getClient() async {
  final file = File("test/auto-test-service-account.json");
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

Future<void> _clearDocument() async {
  await _api.spreadsheets.values.clear(ClearValuesRequest(), _file.id, _sheetTitle);
}

Future<void> _setSheetState(String raw) async {
  final values = _parse(raw);
  await setSheetCellValues(
    values: values,
    sheetTitle: _sheetTitle,
    sheetDocumentId: _file.id,
    sheetFileName: _file.name,
    api: _api,
  );
}

Future<void> _verifyDocumentState(String rawExpected) async {
  final expectedValues = _parse(rawExpected);

  final valueRange = await _api.spreadsheets.values.get(_file.id, _sheetTitle, majorDimension: "ROWS");
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

Map<CellAddress, String> _parse(String raw) {
  final context = _ParsingContext(raw.trim());
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

class _Format {
  static final us = DateFormat.yMMMd("en_US");
}

class _Categories {
  static final one = Category("category1");
  static final two = Category("category2");
}

void main() async {
  final client = await _getClient();
  final format = DateFormat("yyyy-MM-dd-HH:mm:ss'");
  final documentTitle = "${format.format(DateTime.now())}-${Uuid().v4()}";
  final fileMetaData = drive.File()
    ..title = documentTitle
    ..mimeType = "application/vnd.google-apps.spreadsheet"
    ..parents = [drive.ParentReference(id: "1e7oHNJN7GHozelAlnHHtggFIFb8xTv4Q")];
  final driveApi = drive.DriveApi(client);
  final gFile = await driveApi.files.insert(fileMetaData);
  _file = GoogleFile(gFile.id!, documentTitle);
  print("created google sheet file '$documentTitle', id: ${_file.id}");

  _api = SheetsApi(client);
  setClientOverride(client);

  group("all tests", () {
    tearDownAll(() async {
      print("deleting google file ${_file.id}");
      await driveApi.files.delete(_file.id);
      print("deleted google file ${_file.id}");
    });

    setUp(() {
      date.overrideNow(_today);
    });

    tearDown(() async {
      await _clearDocument();
      date.reset();
    });

    _runTests();
  });
}

void _runTests() {
  _emptySheet();
  _updateToday();
  _existingTableNoToday();
  _noTableNonEmptySheet();
  _customFormat();
}

void _emptySheet() {
  group("empty sheet", () {
    test("empty sheet", () async {
      final duration = 2;
      await _service.saveMeasurement(duration, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_todayUs      | $duration       | $duration         
      """);
    });
  });
}

void _updateToday() {
  group("existing 'today' row", () {
    test("new category", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_todayUs      | 1               | 1
      """);
      await _service.saveMeasurement(2, _Categories.two, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one} | ${_Categories.two}
        $_todayUs      | 3               | 1                  | 2         
      """);
    });

    test("existing category", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_todayUs      | 1               | 1
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_todayUs      | 3               | 3                          
      """);
    });

    test("non-standard  table location", () async {
      _setSheetState("""
        |   |  |                |                 |
        |   |  | ${Column.date} | ${Column.total} | ${_Categories.one}
        |   |  | $_todayUs      | 1               | 1
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        |   |  |                |                 |
        |   |  | ${Column.date} | ${Column.total} | ${_Categories.one}
        |   |  | $_todayUs      | 3               | 3                          
      """);
    });

    test("historical records", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Categories.one} | ${_Categories.two}
        $_todayUs      | 3               | 1                  | 2          
        $_yesterdayUs  | 5               |                    | 5
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one} | ${_Categories.two}
        $_todayUs      | 5               | 3                  | 2          
        $_yesterdayUs  | 5               |                    | 5                          
      """);
    });
  });
}

void _existingTableNoToday() {
  group("existing table, no 'today' row", () {
    test("new category", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_yesterdayUs  | 5               | 5                 
      """);
      await _service.saveMeasurement(2, _Categories.two, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one} | ${_Categories.two}
        $_todayUs      | 2               |                    | 2          
        $_yesterdayUs  | 5               | 5                  |                           
      """);
    });

    test("existing category", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_yesterdayUs  | 5               | 5                 
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_todayUs      | 2               | 2
        $_yesterdayUs  | 5               | 5
      """);
    });
  });
}

void _noTableNonEmptySheet() {
  group("no table, non-empty sheet", () {
    test("data in the first row and first column", () async {
      _setSheetState("""
        abc                 
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_todayUs      | 2               | 2
        
        abc                            
      """);
    });

    test("data in the first row second column", () async {
      _setSheetState("""
        | abc                 
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_todayUs      | 2               | 2
                       |                 |
                       | abc             |                            
      """);
    });

    test("data in the first row and fourth column", () async {
      _setSheetState("""
        |   |  | abc                 
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one} |
        $_todayUs      | 2               | 2                  |
                       |                 |                    |                            
                       |                 |                    | abc                            
      """);
    });

    test("data in the first row and fifth column", () async {
      _setSheetState("""
        |   |   |   |  abc                 
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one} |   |
        $_todayUs      | 2               | 2                  |   |
                       |                 |                    |   |                            
                       |                 |                    |   | abc                            
      """);
    });

    test("data in the second row second column", () async {
      _setSheetState("""
        |
        | abc                 
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_todayUs      | 2               | 2
                       |                 |
                       | abc             |                            
      """);
    });

    test("data in the third row third column", () async {
      _setSheetState("""
        |   |
        |   |
        |   | abc                 
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $_todayUs      | 2               | 2
                       |                 |
                       |                 | abc                            
      """);
    });
  });
}

void _customFormat() {
  group("custom format", () {
    test("custom format is preserved", () async {
      final yesterday = date.fallbackDateFormat.format(_yesterday);
      final today = date.fallbackDateFormat.format(_today);
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $yesterday     | 1               | 1
      """);
      await _service.saveMeasurement(2, _Categories.one, _file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Categories.one}
        $today         | 2               | 2         
        $yesterday     | 1               | 1         
      """);
    });
  });
}