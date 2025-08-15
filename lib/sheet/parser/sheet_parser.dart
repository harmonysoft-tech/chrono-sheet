import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:chrono_sheet/google/login/state/google_helper.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:intl/intl.dart';

import '../../log/util/log_util.dart';
import '../../util/date_util.dart';
import '../model/sheet_model.dart';
import '../util/sheet_util.dart';

final _logger = getNamedLogger();

Future<GoogleSheetInfo> parseSheetDocument(GoogleFile file) async {
  final data = await getGoogleClientData();
  final api = SheetsApi(data.authenticatedClient);
  final document = await api.spreadsheets.get(file.id);
  final sheets = document.sheets;
  if (sheets == null || sheets.isEmpty) {
    return GoogleSheetInfo.empty;
  }
  final locale = document.properties?.locale;
  final List<DateFormat> dateFormats = getDateFormats(locale);
  GoogleSheetInfo result = GoogleSheetInfo.empty;
  int resultScore = -1;
  for (final sheet in sheets) {
    final candidate = await _parseSheet(
      sheet: sheet,
      dateFormats: dateFormats,
      file: file,
      api: api,
      locale: locale,
    );
    final candidateScore = _score(candidate);
    if (candidateScore > resultScore) {
      result = candidate;
      resultScore = candidateScore;
    }
  }
  return result;
}

Future<GoogleSheetInfo> _parseSheet({
  required Sheet sheet,
  required List<DateFormat> dateFormats,
  required GoogleFile file,
  required SheetsApi api,
  String? locale,
}) async {
  final sheetId = sheet.properties?.sheetId;
  if (sheetId == null) {
    return GoogleSheetInfo.empty;
  }
  final sheetTitle = sheet.properties?.title;
  if (sheetTitle == null) {
    return GoogleSheetInfo.empty;
  }

  final valueRange = await api.spreadsheets.values.get(
    file.id,
    sheetTitle,
    majorDimension: "ROWS"
  );
  final size = _parseSize(valueRange, file);
  final values = valueRange.values;
  DateFormat dateFormat = fallbackDateFormat;
  if (locale != null) {
    dateFormat = DateFormat.yMMMd(locale);
  }
  if (values == null || values.isEmpty) {
    return GoogleSheetInfo(
      id: sheetId,
      title: sheetTitle,
      dateFormat: dateFormat,
      rowsNumber: size.rows,
      columnsNumber: size.columns
    );
  }

  final basedOnExistingData = _tryParseExistingData(
      values: values, dateFormats: dateFormats, size: size, sheetId: sheetId, sheetTitle: sheetTitle, locale: locale);
  if (basedOnExistingData == null) {
    return GoogleSheetInfo(
      id: sheetId,
      title: sheetTitle,
      rowsNumber: size.rows,
      columnsNumber: size.columns,
      values: parseSheetValues(values),
      dateFormat: dateFormat,
    );
  } else {
    return basedOnExistingData;
  }
}

_Size _parseSize(ValueRange range, GoogleFile file) {
  final rangeString = _getRangeString(range, file);
  if (rangeString == null) {
    return _Size.empty;
  }

  // assuming that the range is defined as <sheet-name>!<top-left-cell>:<bottom-right-cell>
  final sheetStartCellSeparatorIndex = _getSheetStartCellSeparatorIndex(rangeString, file);
  if (sheetStartCellSeparatorIndex == null) {
    return _Size.empty;
  }

  final rowColumnSeparatorIndex = _getRowColumnSeparatorIndex(rangeString, file);
  if (rowColumnSeparatorIndex == null) {
    return _Size.empty;
  }

  if (rangeString.indexOf(":", rowColumnSeparatorIndex + 1) >= 0) {
    _logger.warning(
      "unexpected range format is detected for google sheet file '${file.name}' range value '$rangeString' "
      "- it has more than two ':' symbols"
    );
    return _Size.empty;
  }
  final topLeftAddress = _getTopLeftAddress(sheetStartCellSeparatorIndex, rowColumnSeparatorIndex, rangeString, file);
  if (topLeftAddress == null) {
    return _Size.empty;
  }

  final bottomRightAddress = _getBottomRightAddress(rowColumnSeparatorIndex, rangeString, file);
  if (bottomRightAddress == null) {
    return _Size.empty;
  }

  return _Size(bottomRightAddress.row - topLeftAddress.row + 1, bottomRightAddress.column - topLeftAddress.column + 1);
}

String? _getRangeString(ValueRange range, GoogleFile file) {
  final result = range.range;
  if (result == null) {
    _logger.warning(
        "no range info is provided for google sheet file '${file.name}'"
    );
  }
  return result;
}

int? _getSheetStartCellSeparatorIndex(String range, GoogleFile file) {
  final result = range.indexOf("!");
  if (result <= 0) {
    _logger.warning(
      "unexpected range format is detected for google sheet file '${file.name}' range value '$range' "
      "- it doesn't have '!'"
    );
    return null;
  } else {
    return result;
  }
}

int? _getRowColumnSeparatorIndex(String range, GoogleFile file) {
  final result = range.indexOf(":");
  if (result <= 0) {
    _logger.warning(
      "unexpected range format is detected for google sheet file '${file.name}' range value '$range' "
      "- it doesn't have the second ':'"
    );
    return null;
  } else {
    return result;
  }
}

CellAddress? _getTopLeftAddress(
  int sheetStartCellSeparatorIndex,
  int rowColumnSeparatorIndex,
  String range,
  GoogleFile file,
) {
  final addressString = range.substring(sheetStartCellSeparatorIndex + 1, rowColumnSeparatorIndex);
  final result = parseCellAddress(addressString);
  if (result == null) {
    _logger.warning(
      "can not parse address of the top-left cell of google sheet file '${file.name}', range value '$range', "
      "cell address '$addressString'"
    );
  }
  return result;
}

CellAddress? _getBottomRightAddress(
    int rowColumnSeparatorIndex,
    String range,
    GoogleFile file,
    ) {
  final addressString = range.substring(rowColumnSeparatorIndex + 1);
  final result = parseCellAddress(addressString);
  if (result == null) {
    _logger.warning(
      "can not parse address of the bottom-right cell of google sheet file '${file.name}', range value '$range', "
      "cell address '$addressString'"
    );
  }
  return result;
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

Map<String, CellAddress> _parseColumns(
    int dateCellRow,
    int dateCellColumn,
    List<List<Object?>> values,
) {
  final Map<String, CellAddress> result = {
    Column.date: CellAddress(dateCellRow, dateCellColumn)
  };
  for (int i = dateCellColumn + 1; i < values[dateCellRow].length; ++i) {
    final cellValue = values[dateCellRow][i]?.toString();
    if (cellValue == null || cellValue.isEmpty) {
      break;
    } else if (cellValue.toLowerCase() == Column.total.toLowerCase()) {
      result[Column.total] = CellAddress(dateCellRow, i);
    } else {
      result[cellValue] = CellAddress(dateCellRow, i);
    }
  }
  return result;
}

int? _parseTodayRow(
  int dateCellRow,
  int dateCellColumn,
  List<List<Object?>> values,
  List<DateFormat> dateFormats,
) {
  if (dateCellRow >= values.length - 1) {
    // header row is the last row in the document
    return null;
  }
  if (dateCellColumn >= values[dateCellRow + 1].length) {
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
      final today = clockProvider.now();
      if (
        date.year == today.year
        && date.month == today.month
        && date.day == today.day
      ) {
        return dateCellRow + 1;
      }
    } catch (_) {
    }
  }
  return null;
}

DateFormat _parseDateFormatToUse({
  required int dateCellRow,
  required int dateCellColumn,
  required List<List<Object?>> values,
  String? locale
}) {
  if (values.length > dateCellRow + 1 && values[dateCellRow + 1].length > dateCellColumn) {
    final dateCellValue = values[dateCellRow + 1][dateCellColumn]?.toString();
    if (dateCellValue != null && dateCellValue.isNotEmpty) {
      final formats = getDateFormats(locale);
      for (final format in formats) {
        try {
          format.parse(dateCellValue);
          return format;
        } catch (_) {
        }
      }
    }
  }

  // use fallback format
  if (locale == null) {
    return fallbackDateFormat;
  } else {
    return DateFormat.yMMMd(locale);
  }
}

GoogleSheetInfo? _tryParseExistingData({
  required List<List<Object?>> values,
  required List<DateFormat> dateFormats,
  required _Size size,
  required int sheetId,
  required String sheetTitle,
  String? locale,
}) {
  for (int row = 0; row < values.length; ++row) {
    for (int column = 0; column < values[row].length; ++column) {
      if (_canBeDateCell(row, column, values, dateFormats)) {
        final columns = _parseColumns(row, column, values);
        final todayRow = _parseTodayRow(row, column, values, dateFormats);
        final dateFormat = _parseDateFormatToUse(
            dateCellRow: row,
            dateCellColumn: column,
            values: values,
            locale: locale
        );
        return GoogleSheetInfo(
          rowsNumber: size.rows,
          columnsNumber: size.columns,
          id: sheetId,
          title: sheetTitle,
          columns: columns,
          values: parseSheetValues(values),
          todayRow: todayRow,
          dateFormat: dateFormat,
        );
      }
    }
  }
  return null;
}

Map<CellAddress, String> parseSheetValues(List<List<Object?>> values) {
  final result = <CellAddress, String>{};
  for (int row = 0; row < values.length; ++row) {
    for (int column = 0; column < values[row].length; ++column) {
      final value = values[row][column]?.toString();
      if (value != null) {
        result[CellAddress(row, column)] = value;
      }
    }
  }
  return result;
}

class _Size {

  static const _Size empty = _Size(0, 0);

  final int rows;
  final int columns;

  const _Size(this.rows, this.columns);
}