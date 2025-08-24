// ignore_for_file: avoid_print

import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/google/login/state/google_helper.dart';
import 'package:chrono_sheet/google/login/state/google_login_state.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/sheet/parser/sheet_parser.dart';
import 'package:chrono_sheet/sheet/updater/update_service.dart';
import 'package:chrono_sheet/util/date_util.dart' as date;
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v2.dart' as drive;
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/src/service_account_credentials.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../test_common/google/service/google_service_test_common.dart';

final List<_TestContext> _contexts = [];
int _contextCounter = 0;
final _gDirectories = {
  1: "1e7oHNJN7GHozelAlnHHtggFIFb8xTv4Q",
  2: "1zwe-uJNlz08Aj5ecWlHGqoxpy_1SgC1o",
};

_TestContext get _context => _contexts[_contextCounter];
final _sheetTitle = "Sheet1";
final SheetUpdateService _service = SheetUpdateService();
DateTime _today = date.fallbackDateFormat.parse("2024-12-29");
String _todayUs = _Format.us.format(_today);
DateTime _yesterday = _today.subtract(Duration(days: 1));
String _yesterdayUs = _Format.us.format(_yesterday);

Future<void> _clearDocument(_TestContext context) async {
  await context.api.spreadsheets.values.clear(ClearValuesRequest(), context.file.id, _sheetTitle);
}

Future<void> _setSheetState(String raw) async {
  final values = _parse(raw);
  await setSheetCellValues(
    values: values,
    sheetTitle: _sheetTitle,
    sheetDocumentId: _context.file.id,
    sheetFileName: _context.file.name,
    api: _context.api,
  );
}

Future<void> _verifyDocumentState(String rawExpected) async {
  final expectedValues = _parse(rawExpected);

  final valueRange = await _context.api.spreadsheets.values.get(_context.file.id, _sheetTitle, majorDimension: "ROWS");
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

class _Category {
  static final one = "category1";
  static final two = "category2";
}

class _TestContext {
  final GoogleFile file;
  final SheetsApi api;
  final drive.DriveApi driveApi;
  final AutoRefreshingAuthClient client;

  _TestContext({
    required this.file,
    required this.api,
    required this.driveApi,
    required this.client,
  });
}

Future<void> prepareContexts() async {
  for (int i = 1; i <= 2; i++) {
    final client = await getTestGoogleClient(i, "test_common");
    final format = DateFormat("yyyy-MM-dd-HH:mm:ss'");
    final documentTitle = "${format.format(DateTime.now())}-${Uuid().v4()}";
    final fileMetaData = drive.File()
      ..title = documentTitle
      ..mimeType = sheetMimeType
      ..parents = [drive.ParentReference(id: _gDirectories[i]!)];
    final driveApi = drive.DriveApi(client);
    final gFile = await driveApi.files.insert(fileMetaData);
    _contexts.add(_TestContext(
      file: GoogleFile(gFile.id!, documentTitle),
      api:  SheetsApi(client),
      driveApi: driveApi,
      client: client,
    ));
  }
}

void main() async {
  await prepareContexts();

  group("all tests", () {
    tearDownAll(() async {
      for (final context in _contexts) {
        print("deleting google file ${context.file.id}");
        await context.driveApi.files.delete(context.file.id);
        print("deleted google file ${context.file.id}");
      }
    });

    setUp(() {
      date.overrideNow(_today);
      _contextCounter = (_contextCounter + 1) % _contexts.length;
      setDataOverride(CachedGoogleIdentity(id: "dummy-id", email: "dummy-email"), _context.client);
    });

    tearDown(() async {
      await _clearDocument(_context);
      date.reset();
    });

    _runTests();
  });
}

void _runTests() {
  _emptySheet();
  _updateToday();
  _existingTableNoTodayRow();
  _existingTableNoTotalColumn();
  _noTableNonEmptySheet();
  _customFormat();
  _renameCategory();
}

void _emptySheet() {
  group("empty sheet", () {
    test("empty sheet", () async {
      final duration = 2;
      await _service.saveMeasurement(duration, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | $duration       | $duration         
      """);
    });
  });
}

void _updateToday() {
  group("existing 'today' row", () {
    test("new category", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 1               | 1
      """);
      await _service.saveMeasurement(2, _Category.two, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 3               | 1                | 2         
      """);
    });

    test("existing category", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 1               | 1
      """);
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 3               | 3                          
      """);
    });

    test("non-standard  table location", () async {
      _setSheetState("""
        |   |  |                |                 |
        |   |  | ${Column.date} | ${Column.total} | ${_Category.one}
        |   |  | $_todayUs      | 1               | 1
      """);
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        |   |  |                |                 |
        |   |  | ${Column.date} | ${Column.total} | ${_Category.one}
        |   |  | $_todayUs      | 3               | 3                          
      """);
    });

    test("historical records", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 3               | 1                | 2          
        $_yesterdayUs  | 5               |                  | 5
      """);
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 5               | 3                | 2          
        $_yesterdayUs  | 5               |                  | 5                          
      """);
    });
  });
}

void _existingTableNoTodayRow() {
  group("existing table, no 'today' row", () {
    test("new category", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_yesterdayUs  | 5               | 5                 
      """);
      await _service.saveMeasurement(2, _Category.two, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 2               |                  | 2          
        $_yesterdayUs  | 5               | 5                |                           
      """);
    });

    test("existing category", () async {
      _setSheetState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_yesterdayUs  | 5               | 5                 
      """);
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 2               | 2
        $_yesterdayUs  | 5               | 5
      """);
    });
  });
}

void _existingTableNoTotalColumn() {
  group("existing table, no 'total time' column", () {
    test("existing table, no 'total time' column", () async {
      _setSheetState("""
        ${Column.date} | ${_Category.one} | ${_Category.two}
        $_yesterdayUs  | 5                | 3
      """);
      await _service.saveMeasurement(2, _Category.two, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 2               |                  | 2          
        $_yesterdayUs  | 8               | 5                | 3          
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
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 2               | 2
        
        abc                            
      """);
    });

    test("data in the first row second column", () async {
      _setSheetState("""
        | abc                 
      """);
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 2               | 2
                       |                 |
                       | abc             |                            
      """);
    });

    test("data in the first row and fourth column", () async {
      _setSheetState("""
        |   |  | abc                 
      """);
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one} |
        $_todayUs      | 2               | 2                    |
                       |                 |                      |                            
                       |                 |                      | abc                            
      """);
    });

    test("data in the first row and fifth column", () async {
      _setSheetState("""
        |   |   |   |  abc                 
      """);
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one} |   |
        $_todayUs      | 2               | 2                    |   |
                       |                 |                      |   |                            
                       |                 |                      |   | abc                            
      """);
    });

    test("data in the second row second column", () async {
      _setSheetState("""
        |
        | abc                 
      """);
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
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
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
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
        ${Column.date} | ${Column.total} | ${_Category.one}
        $yesterday     | 1               | 1
      """);
      await _service.saveMeasurement(2, _Category.one, _context.file);
      await _verifyDocumentState("""
        ${Column.date} | ${Column.total} | ${_Category.one}
        $today         | 2               | 2         
        $yesterday     | 1               | 1         
      """);
    });
  });
}

void _renameCategory() {
  group("rename category", () {
    test("existing category", () async {
      _setSheetState("""
        ${Column.date} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 5                | 3
      """);

      final newName = "newCategory";
      final result = await _service.renameCategory(
        from: _Category.one,
        to: newName,
        file: _context.file,
      );
      await _verifyDocumentState("""
        ${Column.date} | $newName | ${_Category.two}
        $_todayUs      | 5        | 3          
      """);
      expect(result, equals(true));
    });

    test("non existing category", () async {
      _setSheetState("""
        ${Column.date} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 5                | 3
      """);
      final result = await _service.renameCategory(
        from: "nonExistingCategory",
        to: "something",
        file: _context.file,
      );
      await _verifyDocumentState("""
        ${Column.date} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 5                | 3          
      """);
      expect(result, equals(false));
    });
  });
}
