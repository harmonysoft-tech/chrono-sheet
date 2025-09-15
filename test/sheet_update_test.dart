// ignore_for_file: avoid_print

import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/google/drive/service/google_drive_service.dart';
import 'package:chrono_sheet/sheet/model/sheet_model.dart';
import 'package:chrono_sheet/sheet/updater/update_service.dart';
import 'package:chrono_sheet/util/date_util.dart' as date;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../test_common/context/test_context.dart';
import '../test_common/google/service/google_service_test_common.dart';

final gService = GoogleDriveService();

final _sheetTitle = "Sheet1";
final SheetUpdateService _sheetService = SheetUpdateService();
DateTime _today = date.fallbackDateFormat.parse("2024-12-29");
String _todayUs = _Format.us.format(_today);
DateTime _yesterday = _today.subtract(Duration(days: 1));
String _yesterdayUs = _Format.us.format(_yesterday);
late GoogleFile file;

class _Format {
  static final us = DateFormat.yMMMd("en_US");
}

class _Category {
  static final one = "category1";
  static final two = "category2";
}

void main() async {
  group("[all tests]", () {
    setUp(() async {
      TestContext("test");
      date.overrideNow(_today);
      await GoogleTestUtil.setUp("test_common/resources");
      final fileName = "data";
      final remoteDirId = await gService.getOrCreateDirectory(TestContext.current.rootRemoteDataDirPath);
      final remoteFileId = await gService.getOrCreateSheetFile(remoteDirId, fileName);
      file = GoogleFile(remoteFileId, fileName);
    });

    tearDown(() async {
      date.reset();
      await GoogleTestUtil.tearDown();
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
  group("[empty sheet]", () {
    test("[empty sheet]", () async {
      final duration = 2;
      await _sheetService.saveMeasurement(duration, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | $duration       | $duration         
      """);
    });
  });
}

void _updateToday() {
  group("[existing 'today' row]", () {
    test("[new category]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 1               | 1
      """);
      await _sheetService.saveMeasurement(2, _Category.two, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 3               | 1                | 2         
      """);
    });

    test("[existing category]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 1               | 1
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 3               | 3                          
      """);
    });

    test("[non-standard  table location]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        |   |  |                |                 |
        |   |  | ${Column.date} | ${Column.total} | ${_Category.one}
        |   |  | $_todayUs      | 1               | 1
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        |   |  |                |                 |
        |   |  | ${Column.date} | ${Column.total} | ${_Category.one}
        |   |  | $_todayUs      | 3               | 3                          
      """);
    });

    test("[historical records]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 3               | 1                | 2          
        $_yesterdayUs  | 5               |                  | 5
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 5               | 3                | 2          
        $_yesterdayUs  | 5               |                  | 5                          
      """);
    });
  });
}

void _existingTableNoTodayRow() {
  group("[existing table, no 'today' row]", () {
    test("[new category]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_yesterdayUs  | 5               | 5                 
      """);
      await _sheetService.saveMeasurement(2, _Category.two, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 2               |                  | 2          
        $_yesterdayUs  | 5               | 5                |                           
      """);
    });

    test("[existing category]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_yesterdayUs  | 5               | 5                 
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 2               | 2
        $_yesterdayUs  | 5               | 5
      """);
    });
  });
}

void _existingTableNoTotalColumn() {
  group("[existing table, no 'total time' column]", () {
    test("[existing table, no 'total time' column]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        ${Column.date} | ${_Category.one} | ${_Category.two}
        $_yesterdayUs  | 5                | 3
      """);
      await _sheetService.saveMeasurement(2, _Category.two, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 2               |                  | 2          
        $_yesterdayUs  | 8               | 5                | 3          
      """);
    });
  });
}

void _noTableNonEmptySheet() {
  group("[no table, non-empty sheet]", () {
    test("[data in the first row and first column]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        abc                 
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 2               | 2
        
        abc                            
      """);
    });

    test("[data in the first row second column]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        | abc                 
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 2               | 2
                       |                 |
                       | abc             |                            
      """);
    });

    test("[data in the first row and fourth column]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        |   |  | abc                 
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one} |
        $_todayUs      | 2               | 2                    |
                       |                 |                      |                            
                       |                 |                      | abc                            
      """);
    });

    test("[data in the first row and fifth column]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        |   |   |   |  abc                 
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one} |   |
        $_todayUs      | 2               | 2                    |   |
                       |                 |                      |   |                            
                       |                 |                      |   | abc                            
      """);
    });

    test("[data in the second row second column]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        |
        | abc                 
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 2               | 2
                       |                 |
                       | abc             |                            
      """);
    });

    test("[data in the third row third column]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        |   |
        |   |
        |   | abc                 
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $_todayUs      | 2               | 2
                       |                 |
                       |                 | abc                            
      """);
    });
  });
}

void _customFormat() {
  group("[custom format]", () {
    test("[custom format is preserved]", () async {
      final yesterday = date.fallbackDateFormat.format(_yesterday);
      final today = date.fallbackDateFormat.format(_today);
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $yesterday     | 1               | 1
      """);
      await _sheetService.saveMeasurement(2, _Category.one, file);
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${Column.total} | ${_Category.one}
        $today         | 2               | 2         
        $yesterday     | 1               | 1         
      """);
    });
  });
}

void _renameCategory() {
  group("[rename category]", () {
    test("[existing category]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        ${Column.date} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 5                | 3
      """);

      final newName = "newCategory";
      final result = await _sheetService.renameCategory(
        from: _Category.one,
        to: newName,
        file: file,
      );
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | $newName | ${_Category.two}
        $_todayUs      | 5        | 3          
      """);
      expect(result, equals(true));
    });

    test("[non existing category]", () async {
      await GoogleTestUtil.setSheetState(file.id, file.name, _sheetTitle, """
        ${Column.date} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 5                | 3
      """);
      final result = await _sheetService.renameCategory(
        from: "nonExistingCategory",
        to: "something",
        file: file,
      );
      await GoogleTestUtil.verifySheetState(file.id, """
        ${Column.date} | ${_Category.one} | ${_Category.two}
        $_todayUs      | 5                | 3          
      """);
      expect(result, equals(false));
    });
  });
}
