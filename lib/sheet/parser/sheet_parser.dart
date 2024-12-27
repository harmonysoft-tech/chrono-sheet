import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/google/google_helper.dart';
import 'package:chrono_sheet/logging/logging.dart';
import 'package:chrono_sheet/sheet/model/sheet_info.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:intl/intl.dart';

import '../model/sheet_column.dart';

final List<DateFormat> _dateFormats = [DateFormat("yyyy-MM-dd")];
final _logger = getNamedLogger();

Future<GoogleSheetInfo> parseSheetDocument(GoogleFile file) async {
  final http = await getAuthenticatedGoogleApiHttpClient();
  final api = SheetsApi(http);
  final document = await api.spreadsheets.get(file.id);
  final sheets = document.sheets;
  if (sheets == null) {
    return GoogleSheetInfo.empty;
  }
  final List<DateFormat> dateFormats = _getDateFormats(document.properties?.locale);
  GoogleSheetInfo result = GoogleSheetInfo.empty;
  int resultScore = _score(result);
  for (final sheet in sheets) {
    final candidate = await _parseSheet(
        sheet: sheet,
        dateFormats: dateFormats,
        file: file,
        api: api,
    );
    final candidateScore = _score(candidate);
    if (candidateScore > resultScore) {
      result = candidate;
      resultScore = candidateScore;
    }
  }
  return result;
}

List<DateFormat> _getDateFormats(String? locale) {
  final result = List.of(_dateFormats);
  if (locale != null) {
    result.add(DateFormat.yMMMd(locale));
    result.add(DateFormat.yMMMMd(locale));
    result.add(DateFormat.yMd(locale));
    result.add(DateFormat.yMEd(locale));
    result.add(DateFormat.yMMMEd(locale));
    result.add(DateFormat.yMMMMEEEEd(locale));
  }
  return result;
}

Future<GoogleSheetInfo> _parseSheet({
  required Sheet sheet,
  required List<DateFormat> dateFormats,
  required GoogleFile file,
  required SheetsApi api
}) async {
  final title = sheet.properties?.title;
  if (title == null) {
    return GoogleSheetInfo.empty;
  }

  final valueRange = await api.spreadsheets.values.get(file.id, title);
  final values = valueRange.values;
  if (values == null || values.isEmpty) {
    return GoogleSheetInfo(title: title);
  }

  for (int row = 0; row < values.length; ++row) {
    for (int column = 0; column < values[row].length; ++column) {
      if (_canBeDateCell(row, column, values, dateFormats)) {
        final columns = _parseColumns(row, column, values);
        final todayRow = _parseTodayRow(row, column, values, dateFormats);
        return GoogleSheetInfo(
          title: title,
          columns: columns,
          todayRow: todayRow
        );
      }
    }
  }

  return GoogleSheetInfo.empty;
}

int _score(GoogleSheetInfo info) {
  int result = 0;
  if (info.title != null) {
    result += 1000;
  }
  if (info.columns.isNotEmpty) {
    result += 100;
  }
  if (info.todayRow != null) {
    result += 10;
  }
  return result;
}

bool _canBeDateCell(
  int row,
  int column,
  List<List<Object?>> values,
  List<DateFormat> dateFormats,
) {
  final cellValue = values[row][column]?.toString();
  if (Column.date.toLowerCase() != cellValue?.toLowerCase()) {
    return false;
  }
  _logger.fine(
    "found a '${Column.date}' cell with value '$cellValue' in "
    "a gsheet position [$row][$column]"
  );
  if (row >= values.length - 1) {
    // this is the last row in the sheet
    return true;
  }
  if (values[row + 1].length <= column) {
    // there is no value at the next row of the date column
    return true;
  }
  final candidateDateCellValue = values[row + 1][column]?.toString();
  if (candidateDateCellValue == null || candidateDateCellValue.isEmpty) {
    // a cell at the next row of the date column is empty
    return true;
  }
  for (final format in dateFormats) {
    try {
      format.parse(candidateDateCellValue);
      _logger.fine(
          "found date value '$candidateDateCellValue' which conforms to "
              "the format '${format.pattern}' in gsheet cell "
              "[${row + 1}][$column]. Considering a '$cellValue' cell "
              "at [$row][$column] to be a valid column header"
      );
      // a cell at the next row of the date column has a valid date string
      return true;
    } catch (_) {
    }
  }
  // cell value of the next row of the date column can't be parsed as a date
  return false;
}

Map<String, String> _parseColumns(
    int dateCellRow,
    int dateCellColumn,
    List<List<Object?>> values,
) {
  final Map<String, String> result = {
    Column.date: _getCellAddress(dateCellRow, dateCellColumn)
  };
  for (int i = dateCellColumn + 1; i < values[dateCellRow].length; ++i) {
    final cellValue = values[dateCellRow][i]?.toString();
    if (cellValue == null || cellValue.isEmpty) {
      break;
    } else if (cellValue.toLowerCase() == Column.total.toLowerCase()) {
      result[Column.total] = _getCellAddress(dateCellRow, i);
    } else {
      result[cellValue] = _getCellAddress(dateCellRow, i);
    }
  }
  return result;
}

String _getCellAddress(int row, int col) {
  String columnLetter = '';
  int tempCol = col + 1;
  while (tempCol > 0) {
    tempCol--;
    columnLetter = String.fromCharCode(tempCol % 26 + 65) + columnLetter;
    tempCol ~/= 26;
  }
  return '$columnLetter${row + 1}';
}

String? _parseTodayRow(
  int dateCellRow,
  int dateCellColumn,
  List<List<Object?>> values,
  List<DateFormat> dateFormats,
) {
  if (dateCellRow >= values.length - 1) {
    // header row is the last row in the document
    return null;
  }
  if (dateCellColumn >= values[dateCellRow].length) {
    // there is no value at the next cell of the 'date' column
    return null;
  }
  final value = values[dateCellRow + 1][dateCellColumn]?.toString();
  if (value == null || value.isEmpty) {
    // next cell of the 'date' column is empty
    return null;
  }
  for (final format in dateFormats) {
    try {
      final date = format.parse(value);
      final today = DateTime.now();
      if (
        date.year == today.year
        && date.month == today.month
        && date.day == today.day
      ) {
        return _getCellAddress(dateCellRow + 1, dateCellColumn);
      }
    } catch (_) {
    }
  }
  return null;
}