import 'package:chrono_sheet/util/date_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../file/model/google_file.dart';
import '../../google/google_helper.dart';
import '../../log/util/log_util.dart';
import '../../util/collection_util.dart';
import '../model/sheet_model.dart';
import '../parser/sheet_parser.dart';
import '../util/sheet_util.dart';

part 'update_service.g.dart';

final _logger = getNamedLogger();

@riverpod
SheetUpdateService updateService(Ref ref) {
  return SheetUpdateService();
}

class SheetUpdateService {
  Future<bool> renameCategory({
    required String from,
    required String to,
    required GoogleFile file,
  }) async {
    final data = await getGoogleClientData();
    final api = SheetsApi(data.authenticatedClient);
    GoogleSheetInfo sheetInfo = await parseSheetDocument(file);
    final address = sheetInfo.columns[from];
    if (address == null) {
      return false;
    }

    await setSheetCellValues(
      values: {
        address: to,
      },
      sheetTitle: sheetInfo.title!,
      sheetDocumentId: file.id,
      sheetFileName: file.name,
      api: api,
    );
    return true;
  }

  Future<void> saveMeasurement(
    int duration,
    String category,
    GoogleFile file,
  ) async {
    _logger.info("saving measurement of $duration in category '$category' in file '${file.name}'");
    final data = await getGoogleClientData();
    final api = SheetsApi(data.authenticatedClient);
    GoogleSheetInfo sheetInfo = await parseSheetDocument(file);
    sheetInfo = await _createSheetIfNecessary(sheetInfo, file, api);
    final context = _SaveMeasurementContext(
      durationToStore: duration,
      file: file,
      category: category,
      api: api,
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

  Future<GoogleSheetInfo> _createSheetIfNecessary(GoogleSheetInfo info, GoogleFile file, SheetsApi api) async {
    final sheetName = info.title;
    if (sheetName != null) {
      return info;
    }

    final newSheetName = "Sheet1";
    final request = BatchUpdateSpreadsheetRequest(requests: [
      Request(
        addSheet: AddSheetRequest(
            properties: SheetProperties(
                title: newSheetName,
                gridProperties: GridProperties(
                  rowCount: 1000,
                  columnCount: 26,
                ))),
      ),
    ]);
    final batchResponse = await api.spreadsheets.batchUpdate(request, file.id);
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
    final batchUpdateRequest = BatchUpdateSpreadsheetRequest(requests: [
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
      )
    ]);

    try {
      await context.api.spreadsheets.batchUpdate(batchUpdateRequest, context.file.id);
      _onRowsInserted(rowToInsertAfter, rowsCount, context);
    } catch (e, stack) {
      _logger.warning(
          "can not insert $rowsCount row(s) at index $rowToInsertAfter into google sheet document '${context.file.name}'",
          e,
          stack);
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
      api: context.api,
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
    await context.api.spreadsheets.batchUpdate(
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
      (column, address) => MapEntry(
        column,
        address.column >= totalColumn ? address.shiftColumn(1) : address,
      ),
    );
    final totalCellAddress = CellAddress(dateColumnCell.row, totalColumn);
    newColumns[Column.total] = totalCellAddress;

    final newValues = context.values.map(
      (address, value) {
        if (address.column < totalColumn) {
          return MapEntry(address, value);
        } else {
          final current = row2totalValue[address.row] ?? 0;
          final cellValue = int.tryParse(value) ?? 0;
          row2totalValue[address.row] = current + cellValue;
          return MapEntry(address.shiftColumn(1), value);
        }
      },
    );
    newValues[totalCellAddress] = Column.total;
    context.columns = newColumns;
    context.values = newValues;
    final result = row2totalValue.map(
      (row, totalValue) => MapEntry(
        CellAddress(row, totalColumn),
        totalValue.toString(),
      ),
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
}

Future<void> setSheetCellValues({
  required Map<CellAddress, String> values,
  required String sheetTitle,
  required String sheetDocumentId,
  required String sheetFileName,
  required SheetsApi api,
}) async {
  final valueRanges = values.entries.map((entry) {
    return ValueRange(
      range: "$sheetTitle!${getCellAddress(entry.key.row, entry.key.column)}",
      values: [
        [entry.value]
      ],
    );
  }).toList();
  final request = BatchUpdateValuesRequest(
    valueInputOption: "RAW",
    data: valueRanges,
  );
  try {
    await api.spreadsheets.values.batchUpdate(request, sheetDocumentId);
  } catch (e, stack) {
    _logger.warning("failed to set values $values in google sheet document '$sheetFileName'", e, stack);
    rethrow;
  }

  try {
    // align the text horizontally inside the cells
    await api.spreadsheets.batchUpdate(
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
                  cell: CellData(
                    userEnteredFormat: CellFormat(
                      horizontalAlignment: 'CENTER',
                    ),
                  ),
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
        "failed to align cells ${values.keys.toList()} in google sheet document '$sheetFileName'", e, stack);
  }
}

class _Addresses {
  static final Set<CellAddress> secondRow = {
    CellAddress(1, 0),
    CellAddress(1, 1),
    CellAddress(1, 2),
    CellAddress(1, 3)
  };
  static final Set<CellAddress> thirdRow = {
    CellAddress(2, 0),
    CellAddress(2, 1),
    CellAddress(2, 2),
  };
}

class _SaveMeasurementContext {
  final int durationToStore;
  final GoogleFile file;
  final String category;
  final SheetsApi api;
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
    required this.api,
    required this.sheetInfo,
    required this.columns,
    required this.values,
  });
}
