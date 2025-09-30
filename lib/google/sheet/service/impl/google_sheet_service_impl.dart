import 'package:chrono_sheet/google/drive/model/google_file.dart';
import 'package:chrono_sheet/google/sheet/model/google_sheet_model.dart';
import 'package:chrono_sheet/google/sheet/service/google_sheet_service.dart';
import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/util/collection_util.dart';
import 'package:chrono_sheet/util/date_util.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:intl/intl.dart';

final _logger = getNamedLogger();

class GoogleSheetServiceImpl implements GoogleSheetService {

  final SheetsApi? _api;

  GoogleSheetServiceImpl(this._api);

  @override
  Future<GoogleSheetInfo> parseSheetDocument(GoogleFile file) async {
    final document = await _api!.spreadsheets.get(file.id);
    final sheets = document.sheets;
    if (sheets == null || sheets.isEmpty) {
      return GoogleSheetInfo.empty;
    }
    final locale = document.properties?.locale;
    final List<DateFormat> dateFormats = getDateFormats(locale);
    GoogleSheetInfo result = GoogleSheetInfo.empty;
    int resultScore = -1;
    for (final sheet in sheets) {
      final candidate = await _parseSheet(sheet: sheet, dateFormats: dateFormats, file: file, locale: locale);
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

    final valueRange = await _api!.spreadsheets.values.get(file.id, sheetTitle, majorDimension: "ROWS");
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
        columnsNumber: size.columns,
      );
    }

    final basedOnExistingData = _tryParseExistingData(
      values: values,
      dateFormats: dateFormats,
      size: size,
      sheetId: sheetId,
      sheetTitle: sheetTitle,
      locale: locale,
    );
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
        "- it has more than two ':' symbols",
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

    return _Size(
      bottomRightAddress.row - topLeftAddress.row + 1,
      bottomRightAddress.column - topLeftAddress.column + 1,
    );
  }

  String? _getRangeString(ValueRange range, GoogleFile file) {
    final result = range.range;
    if (result == null) {
      _logger.warning("no range info is provided for google sheet file '${file.name}'");
    }
    return result;
  }

  int? _getSheetStartCellSeparatorIndex(String range, GoogleFile file) {
    final result = range.indexOf("!");
    if (result <= 0) {
      _logger.warning(
        "unexpected range format is detected for google sheet file '${file.name}' range value '$range' "
        "- it doesn't have '!'",
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
        "- it doesn't have the second ':'",
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
        "cell address '$addressString'",
      );
    }
    return result;
  }

  CellAddress? _getBottomRightAddress(int rowColumnSeparatorIndex, String range, GoogleFile file) {
    final addressString = range.substring(rowColumnSeparatorIndex + 1);
    final result = parseCellAddress(addressString);
    if (result == null) {
      _logger.warning(
        "can not parse address of the bottom-right cell of google sheet file '${file.name}', range value '$range', "
        "cell address '$addressString'",
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

  bool _canBeDateCell(int row, int column, List<List<Object?>> values, List<DateFormat> dateFormats) {
    final cellValue = values[row][column]?.toString();
    if (Column.date.toLowerCase() != cellValue?.toLowerCase()) {
      return false;
    }
    _logger.fine(
      "found a '${Column.date}' cell with value '$cellValue' in "
      "a gsheet position [$row][$column]",
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
          "at [$row][$column] to be a valid column header",
        );
        // a cell at the next row of the date column has a valid date string
        return true;
      } catch (_) {}
    }
    // cell value of the next row of the date column can't be parsed as a date
    return false;
  }

  Map<String, CellAddress> _parseColumns(int dateCellRow, int dateCellColumn, List<List<Object?>> values) {
    final Map<String, CellAddress> result = {Column.date: CellAddress(dateCellRow, dateCellColumn)};
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

  int? _parseTodayRow(int dateCellRow, int dateCellColumn, List<List<Object?>> values, List<DateFormat> dateFormats) {
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
        if (date.year == today.year && date.month == today.month && date.day == today.day) {
          return dateCellRow + 1;
        }
      } catch (_) {}
    }
    return null;
  }

  DateFormat _parseDateFormatToUse({
    required int dateCellRow,
    required int dateCellColumn,
    required List<List<Object?>> values,
    String? locale,
  }) {
    if (values.length > dateCellRow + 1 && values[dateCellRow + 1].length > dateCellColumn) {
      final dateCellValue = values[dateCellRow + 1][dateCellColumn]?.toString();
      if (dateCellValue != null && dateCellValue.isNotEmpty) {
        final formats = getDateFormats(locale);
        for (final format in formats) {
          try {
            format.parse(dateCellValue);
            return format;
          } catch (_) {}
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
            locale: locale,
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

  @override
  Future<bool> renameCategory({required String from, required String to, required GoogleFile file}) async {
    GoogleSheetInfo sheetInfo = await parseSheetDocument(file);
    final address = sheetInfo.columns[from];
    if (address == null) {
      return false;
    }

    await setSheetCellValues(
      values: {address: to},
      sheetTitle: sheetInfo.title!,
      sheetDocumentId: file.id,
      sheetFileName: file.name,
    );
    return true;
  }

  @override
  Future<void> saveMeasurement(int duration, String category, GoogleFile file) async {
    _logger.info("saving measurement of $duration in category '$category' in file '${file.name}'");
    GoogleSheetInfo sheetInfo = await parseSheetDocument(file);
    sheetInfo = await _createSheetIfNecessary(sheetInfo, file);
    final context = _SaveMeasurementContext(
      durationToStore: duration,
      file: file,
      category: category,
      sheetInfo: sheetInfo,
      columns: Map.of(sheetInfo.columns),
      values: Map.of(sheetInfo.values),
    );
    if (context.columns.isEmpty) {
      await _createColumnsAndStore(context);
    } else {
      await _storeInExistingTable(context);
    }
  }

  Future<GoogleSheetInfo> _createSheetIfNecessary(GoogleSheetInfo info, GoogleFile file) async {
    final sheetName = info.title;
    if (sheetName != null) {
      return info;
    }

    final newSheetName = "Sheet1";
    final request = BatchUpdateSpreadsheetRequest(
      requests: [
        Request(
          addSheet: AddSheetRequest(
            properties: SheetProperties(
              title: newSheetName,
              gridProperties: GridProperties(rowCount: 1000, columnCount: 26),
            ),
          ),
        ),
      ],
    );
    final batchResponse = await _api!.spreadsheets.batchUpdate(request, file.id);
    final addSheetResponse = batchResponse.replies?.mapFirstNotNull((e) {
      return e.addSheet;
    });
    if (addSheetResponse == null) {
      final error = "can not create new sheet in google sheet document '${file.name}'";
      _logger.warning("$error, response: ${batchResponse.toJson()}");
      throw Exception(error);
    }
    final createdSheetId = addSheetResponse.properties?.sheetId;
    if (createdSheetId == null) {
      final error = "no id is returned for newly created sheet '$newSheetName'";
      _logger.warning("$error, response: ${batchResponse.toJson()}");
      throw Exception(error);
    }
    return info.copyWith(id: createdSheetId, title: newSheetName);
  }

  Future<void> _createColumnsAndStore(_SaveMeasurementContext context) async {
    int rowsToCreate = _calculateNumberOfRowsToCreateForSheetWithoutPreviousData(context);
    if (rowsToCreate > 0) {
      await _insertRows(-1, rowsToCreate, context);
    }
    await _setValues(context, {
      CellAddress(0, 0): Column.date,
      CellAddress(0, 1): Column.total,
      CellAddress(0, 2): context.category,
      CellAddress(1, 0): context.sheetInfo.dateFormat.format(clockProvider.now()),
      CellAddress(1, 1): context.durationToStore.toString(),
      CellAddress(1, 2): context.durationToStore.toString(),
    });
  }

  int _calculateNumberOfRowsToCreateForSheetWithoutPreviousData(_SaveMeasurementContext context) {
    if (context.sheetInfo.rowsNumber <= 0) {
      // the sheet has no rows, we just need to create two empty rows then
      return 2;
    }

    final hasDataInFirstRow = context.values.entries.any((e) {
      return e.key.row == 0 && e.value.isNotEmpty;
    });
    if (hasDataInFirstRow) {
      // we can't keep any data at the headers row because more categories might be added in future and
      // this old data might be treated as a column
      return 3;
    }

    if (context.sheetInfo.rowsNumber == 1) {
      // the google sheet has only one empty row, so, we need to create one more
      return 1;
    }

    // the google sheet document has at least two rows
    final secondRowValues = _getValues(_Addresses.secondRow, context);
    final hasDataInSecondRow = _Addresses.secondRow.any((address) {
      final cellValue = secondRowValues[address];
      return cellValue != null && cellValue.isNotEmpty;
    });
    if (hasDataInSecondRow) {
      // the first row is empty but there some unrelated data at the second rows, we need to create one row
      // for our headers, another row for data. Existing empty first row will be a buffer between our data
      // and with the row which hold the unrelated data
      return 2;
    }

    if (context.sheetInfo.rowsNumber == 2) {
      // the sheet has two rows and they don't have data in important cells
      return 0;
    }

    final thirdRowValues = _getValues(_Addresses.thirdRow, context);
    final hasDataInThirdRow = _Addresses.thirdRow.any((address) {
      final cellValue = thirdRowValues[address];
      return cellValue != null && cellValue.isNotEmpty;
    });
    if (hasDataInThirdRow) {
      // first and second rows are empty, so, we just create one more empty row as a buffer
      return 1;
    }

    return 0;
  }

  Future<void> _insertRows(int rowToInsertAfter, int rowsCount, _SaveMeasurementContext context) async {
    final batchUpdateRequest = BatchUpdateSpreadsheetRequest(
      requests: [
        Request(
          insertDimension: InsertDimensionRequest(
            range: DimensionRange(
              sheetId: context.sheetInfo.id!,
              dimension: "ROWS",
              startIndex: rowToInsertAfter + 1, // we use zero-based indexing ang google sheet uses 1-based
              endIndex: rowToInsertAfter + 1 + rowsCount,
            ),
            inheritFromBefore: false,
          ),
        ),
      ],
    );

    try {
      await _api!.spreadsheets.batchUpdate(batchUpdateRequest, context.file.id);
      _onRowsInserted(rowToInsertAfter, rowsCount, context);
    } catch (e, stack) {
      _logger.warning(
        "can not insert $rowsCount row(s) at index $rowToInsertAfter into google sheet document '${context.file.name}'",
        e,
        stack,
      );
      rethrow;
    }
  }

  void _onRowsInserted(int rowToInsertAfter, int rowsCount, _SaveMeasurementContext context) {
    final newColumns = context.columns.map((column, address) {
      if (address.row > rowToInsertAfter) {
        return MapEntry(column, CellAddress(address.row + rowsCount, address.column));
      } else {
        return MapEntry(column, address);
      }
    });
    context.columns = newColumns;

    context.values = _calculateNewValuesOnRowsInserted(rowToInsertAfter, rowsCount, context.values);
  }

  Map<CellAddress, String> _calculateNewValuesOnRowsInserted(
      int rowToInsertAfter,
      int rowsCount,
      Map<CellAddress, String> values,
      ) {
    return values.map((address, value) {
      if (address.row > rowToInsertAfter) {
        return MapEntry(CellAddress(address.row + rowsCount, address.column), value);
      } else {
        return MapEntry(address, value);
      }
    });
  }

  String? _getValue(CellAddress address, _SaveMeasurementContext context) {
    final values = _getValues({address}, context);
    if (values.isNotEmpty) {
      return values.values.first;
    } else {
      return null;
    }
  }

  Map<CellAddress, String> _getValues(Set<CellAddress> addresses, _SaveMeasurementContext context) {
    final result = <CellAddress, String>{};
    for (final address in addresses) {
      final value = context.values[address];
      if (value != null) {
        result[address] = value;
      }
    }
    return result;
  }

  Future<void> _setValues(_SaveMeasurementContext context, Map<CellAddress, String> values) async {
    await setSheetCellValues(
      values: values,
      sheetTitle: context.sheetInfo.title!,
      sheetDocumentId: context.file.id,
      sheetFileName: context.file.name,
    );
  }

  Future<void> _storeInExistingTable(_SaveMeasurementContext context) async {
    final totalColumnValues = await _ensureThatTotalDurationColumnExists(context);
    Map<CellAddress, String> updates = Map.of(totalColumnValues);
    int? todayRow = context.sheetInfo.todayRow;
    final dateHeaderCell = context.columns[Column.date]!;
    if (todayRow == null) {
      await _insertRows(dateHeaderCell.row, 1, context);
      todayRow = dateHeaderCell.row + 1;
      updates = _calculateNewValuesOnRowsInserted(dateHeaderCell.row, 1, updates);
      updates[CellAddress(todayRow, dateHeaderCell.column)] = context.sheetInfo.dateFormat.format(clockProvider.now());
    }

    int currentTotalTime = _calculateTotalDuration(todayRow, context);
    int? totalColumn = context.columns[Column.total]?.column;
    int? categoryColumn = context.columns[context.category]?.column;

    int newColumnShift = 0;

    if (totalColumn == null) {
      totalColumn = _calculateNewColumn(context) + newColumnShift++;
      updates[CellAddress(dateHeaderCell.row, totalColumn)] = Column.total;
    }
    updates[CellAddress(todayRow, totalColumn)] = (currentTotalTime + context.durationToStore).toString();

    if (categoryColumn == null) {
      categoryColumn = _calculateNewColumn(context) + newColumnShift++;
      updates[CellAddress(dateHeaderCell.row, categoryColumn)] = context.category;
    }
    final categoryValueCellAddress = CellAddress(todayRow, categoryColumn);
    final currentCategoryStringValue = _getValue(categoryValueCellAddress, context);
    int currentCategoryValue = 0;
    if (currentCategoryStringValue != null) {
      final v = int.tryParse(currentCategoryStringValue);
      if (v != null) {
        currentCategoryValue = v;
      }
    }
    updates[CellAddress(todayRow, categoryColumn)] = (currentCategoryValue + context.durationToStore).toString();

    await _setValues(context, updates);
  }

  Future<Map<CellAddress, String>> _ensureThatTotalDurationColumnExists(_SaveMeasurementContext context) async {
    if (context.columns.containsKey(Column.total)) {
      return {};
    }
    final dateColumnCell = context.columns[Column.date];
    if (dateColumnCell == null) {
      return {};
    }
    final row2totalValue = <int, int>{};
    final totalColumn = dateColumnCell.column + 1;
    await _api!.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(
        requests: [
          Request(
            insertDimension: InsertDimensionRequest(
              range: DimensionRange(
                sheetId: 0,
                dimension: "COLUMNS",
                startIndex: totalColumn,
                endIndex: totalColumn + 1,
              ),
            ),
          ),
        ],
      ),
      context.file.id,
    );

    final newColumns = context.columns.map(
          (column, address) => MapEntry(column, address.column >= totalColumn ? address.shiftColumn(1) : address),
    );
    final totalCellAddress = CellAddress(dateColumnCell.row, totalColumn);
    newColumns[Column.total] = totalCellAddress;

    final newValues = context.values.map((address, value) {
      if (address.column < totalColumn) {
        return MapEntry(address, value);
      } else {
        final current = row2totalValue[address.row] ?? 0;
        final cellValue = int.tryParse(value) ?? 0;
        row2totalValue[address.row] = current + cellValue;
        return MapEntry(address.shiftColumn(1), value);
      }
    });
    newValues[totalCellAddress] = Column.total;
    context.columns = newColumns;
    context.values = newValues;
    final result = row2totalValue.map(
          (row, totalValue) => MapEntry(CellAddress(row, totalColumn), totalValue.toString()),
    );
    result[totalCellAddress] = Column.total;
    return result;
  }

  int _calculateTotalDuration(int row, _SaveMeasurementContext context) {
    int result = 0;
    context.columns.forEach((column, address) {
      if (column != Column.date && column != Column.total) {
        final stringValue = _getValue(CellAddress(row, address.column), context);
        if (stringValue != null) {
          final duration = int.tryParse(stringValue);
          if (duration != null) {
            result += duration;
          }
        }
      }
    });
    return result;
  }

  int _calculateNewColumn(_SaveMeasurementContext context) {
    int currentMax = -1;
    for (final address in context.columns.values) {
      if (address.column > currentMax) {
        currentMax = address.column;
      }
    }
    return currentMax + 1;
  }

  @override
  String getCellAddress(int row, int col) {
    String columnLetter = '';
    int tempCol = col + 1;
    while (tempCol > 0) {
      tempCol--;
      columnLetter = String.fromCharCode(tempCol % 26 + 65) + columnLetter;
      tempCol ~/= 26;
    }
    return '$columnLetter${row + 1}';
  }

  @override
  Future<void> setSheetCellValues({
    required Map<CellAddress, String> values,
    required String sheetTitle,
    required String sheetDocumentId,
    required String sheetFileName,
  }) async {
    final valueRanges = values.entries.map((entry) {
      return ValueRange(
        range: "$sheetTitle!${getCellAddress(entry.key.row, entry.key.column)}",
        values: [
          [entry.value],
        ],
      );
    }).toList();
    final request = BatchUpdateValuesRequest(valueInputOption: "RAW", data: valueRanges);
    try {
      await _api!.spreadsheets.values.batchUpdate(request, sheetDocumentId);
    } catch (e, stack) {
      _logger.warning("failed to set values $values in google sheet document '$sheetFileName'", e, stack);
      rethrow;
    }

    try {
      // align the text horizontally inside the cells
      await _api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(
          requests: values.keys
              .map(
                (address) => Request(
              repeatCell: RepeatCellRequest(
                range: GridRange(
                  sheetId: 0,
                  startRowIndex: address.row,
                  endRowIndex: address.row + 1,
                  startColumnIndex: address.column,
                  endColumnIndex: address.column + 1,
                ),
                cell: CellData(userEnteredFormat: CellFormat(horizontalAlignment: 'CENTER')),
                fields: 'userEnteredFormat(horizontalAlignment)',
              ),
            ),
          )
              .toList(),
        ),
        sheetDocumentId,
      );
    } catch (e, stack) {
      _logger.warning(
        "failed to align cells ${values.keys.toList()} in google sheet document '$sheetFileName'",
        e,
        stack,
      );
    }
  }

  @override
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

  @override
  CellAddress? parseCellAddress(String s) {
    int? rowIndex;
    for (int i = 0; i < s.length; ++i) {
      final c = s.codeUnitAt(i);
      if (c >= "0".codeUnitAt(0) && c <= "9".codeUnitAt(0)) {
        rowIndex = i;
        break;
      }
    }
    if (rowIndex == null) {
      _logger.warning(
          "can not parse cell address from '$s' - didn't find a number there"
      );
      return null;
    }
    final rowString = s.substring(rowIndex);
    final row = int.tryParse(rowString);
    if (row == null) {
      _logger.warning(
          "can not parse cell address from '$s' - row string is not a number ($rowString)"
      );
      return null;
    }
    int column = 0;
    for (int i = 0; i < rowIndex; ++i) {
      final c = s.codeUnitAt(i);
      column = column * 26 + (c - 'A'.codeUnitAt(0));
    }
    return CellAddress(row - 1, column);
  }

}

class _Size {
  static const _Size empty = _Size(0, 0);

  final int rows;
  final int columns;

  const _Size(this.rows, this.columns);
}

class _Addresses {
  static final Set<CellAddress> secondRow = {
    CellAddress(1, 0),
    CellAddress(1, 1),
    CellAddress(1, 2),
    CellAddress(1, 3),
  };
  static final Set<CellAddress> thirdRow = {CellAddress(2, 0), CellAddress(2, 1), CellAddress(2, 2)};
}

class _SaveMeasurementContext {
  final int durationToStore;
  final GoogleFile file;
  final String category;
  final GoogleSheetInfo sheetInfo;

  // we use custom copied of columns and values because when new row is inserted, we need to update coordinates
  // the all cells located below the inserted row. We can't update them directly in the GoogleSheetInfo object,
  // that's why we keep our own copied here
  Map<String, CellAddress> columns;
  Map<CellAddress, String> values;

  _SaveMeasurementContext({
    required this.durationToStore,
    required this.file,
    required this.category,
    required this.sheetInfo,
    required this.columns,
    required this.values,
  });
}