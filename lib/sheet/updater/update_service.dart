import 'package:chrono_sheet/logging/logging.dart';
import 'package:chrono_sheet/util/date_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../util/collection_util.dart';
import '../../category/model/category.dart';
import '../../file/model/google_file.dart';
import '../../google/google_helper.dart';
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
  Future<void> saveMeasurement(
    int duration,
    Category category,
    GoogleFile file,
  ) async {
    final http = await getAuthenticatedGoogleApiHttpClient();
    final api = SheetsApi(http);
    GoogleSheetInfo sheetInfo = await parseSheetDocument(file);
    sheetInfo = await _createSheetIfNecessary(sheetInfo, file, api);
    final context = _Context(
      durationToStore: duration,
      file: file,
      category: category,
      api: api,
      sheetInfo: sheetInfo,
    );
    if (sheetInfo.columns.isEmpty) {
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

  Future<void> _createColumnsAndStore(_Context context) async {
    int rowsToCreate = _calculateNumberOfRowsToCreateForSheetWithoutPreviousData(context);
    if (rowsToCreate > 0) {
      await _insertRows(0, rowsToCreate, context);
    }
    await _setValues(context, {
      CellAddress(0, 0): Column.date,
      CellAddress(0, 1): Column.total,
      CellAddress(0, 2): context.category.name,
      CellAddress(1, 0): context.sheetInfo.dateFormat.format(clockProvider.now()),
      CellAddress(1, 1): context.durationToStore.toString(),
      CellAddress(1, 2): context.durationToStore .toString(),
    });
  }

  int _calculateNumberOfRowsToCreateForSheetWithoutPreviousData(_Context context) {
    if (context.sheetInfo.rowsNumber <= 0) {
      // the sheet has no rows, we just need to create two empty rows then
      return 2;
    }

    final firstRowCells = {CellAddress(0, 0), CellAddress(0, 1), CellAddress(0, 2)};
    if (context.sheetInfo.rowsNumber == 1) {
      final firstRowValues = _getValues(firstRowCells, context);
      final hasDataInFirstRow = firstRowValues.entries.any((entry) => entry.value.isNotEmpty);
      if (hasDataInFirstRow) {
        // one row is to hold the headers, another row to hold today's data and one empty buffer row between
        // the application data and existing data
        return 3;
      } else {
        // the google sheet has only one empty row, so, we need to create one more
        return 1;
      }
    }

    // the google sheet document has at least two rows
    final secondRowCells = {CellAddress(1, 0), CellAddress(1, 1), CellAddress(1, 2)};
    final values = _getValues(firstRowCells.union(secondRowCells), context);
    final hasDataInFirstRow = firstRowCells.any((address) {
      final cellValue = values[address];
      return cellValue != null && cellValue.isNotEmpty;
    });
    if (hasDataInFirstRow) {
      // the top sheet row already has some unrelated data, we need to create one row for our headers,
      // another row for data and one row as a buffer between our data and unrelated data
      return 3;
    }

    final hasDataInSecondRow = secondRowCells.any((address) {
      final cellValue = values[address];
      return cellValue != null && cellValue.isNotEmpty;
    });
    if (hasDataInSecondRow) {
      return 2;
    } else {
      return 0;
    }
  }

  Future<void> _insertRows(int rowToInsertAfter, int rowsCount, _Context context) async {
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
      context.sheetInfo.onRowsInserted(rowToInsertAfter, rowsCount);
    } catch (e, stack) {
      _logger.warning(
          "can not insert $rowsCount row(s) at index $rowToInsertAfter into google sheet document '${context.file.name}'",
          e,
          stack);
      rethrow;
    }
  }

  String? _getValue(CellAddress address, _Context context) {
    final values = _getValues({address}, context);
    if (values.isNotEmpty) {
      return values.values.first;
    } else {
      return null;
    }
  }

  Map<CellAddress, String> _getValues(Set<CellAddress> addresses, _Context context) {
    final result = <CellAddress, String>{};
    for (final address in addresses) {
      final value = context.sheetInfo.values[address];
      if (value != null) {
        result[address] = value;
      }
    }
    return result;

    // final ranges = addresses.map((address) {
    //   return "${context.sheetInfo.title}!${getCellAddress(address.row, address.column)}";
    // }).toList();
    // final response = await context.api.spreadsheets.values.batchGet(context.file.id, ranges: ranges);
    //
    // final result = <CellAddress, String>{};
    // response.valueRanges?.forEach((range) {
    //   final responseRange = range.range;
    //   if (responseRange == null) {
    //     _logger.severe(
    //         "can not parse response to the 'get value' request made to the google sheet '${context.sheetInfo.title}' "
    //         "- expected 'range' response property to be not empty. Full response: ${response.toJson()}");
    //     return;
    //   }
    //
    //   final i = responseRange.indexOf("!");
    //   String addressString = responseRange;
    //   if (i > 0) {
    //     addressString = responseRange.substring(i + 1);
    //   }
    //   final address = parseCellAddress(addressString);
    //   if (address == null) {
    //     _logger.severe(
    //         "can not parse response to the 'get value' request made to the google sheet '${context.sheetInfo.title}' "
    //         "- failed to parse cell address from '$addressString'. Full response: ${response.toJson()}");
    //     return;
    //   }
    //   final values = range.values;
    //   String? value;
    //   if (values != null) {
    //     if (values.length > 1) {
    //       _logger.warning("expected that a google sheet data is [[<data>]] but got '$values'");
    //     }
    //     if (values.isNotEmpty) {
    //       final subValues = values.first;
    //       if (subValues.length > 1) {
    //         _logger.warning("expected that a google sheet data is [[<data>]] but got '$values'");
    //       }
    //       if (subValues.isNotEmpty) {
    //         value = subValues.first?.toString();
    //       }
    //     }
    //   }
    //   result[address] = value ?? "";
    // });
    // return result;
  }

  Future<void> _setValues(_Context context, Map<CellAddress, String> values) async {
    await setSheetCellValues(
      values: values,
      sheetTitle: context.sheetInfo.title!,
      sheetDocumentId: context.file.id,
      sheetFileName: context.file.name,
      api: context.api,
    );
  }

  Future<void> _storeInExistingTable(_Context context) async {
    final updates = <CellAddress, String>{};
    int? todayRow = context.sheetInfo.todayRow;
    final dateHeaderCell = context.sheetInfo.columns[Column.date]!;
    if (todayRow == null) {
      await _insertRows(dateHeaderCell.row, 1, context);
      todayRow = dateHeaderCell.row + 1;
      updates[CellAddress(todayRow, dateHeaderCell.column)] = context.sheetInfo.dateFormat.format(clockProvider.now());
    }

    int currentTotalTime = _calculateTotalDuration(todayRow, context);
    int? totalColumn = context.sheetInfo.columns[Column.total]?.column;
    int? categoryColumn = context.sheetInfo.columns[context.category.name]?.column;

    int newColumnShift = 0;

    if (totalColumn == null) {
      totalColumn = _calculateNewColumn(context) + newColumnShift++;
      updates[CellAddress(dateHeaderCell.row, totalColumn)] = Column.total;
    }
    updates[CellAddress(todayRow, totalColumn)] = (currentTotalTime + context.durationToStore).toString();

    if (categoryColumn == null) {
      categoryColumn = _calculateNewColumn(context) + newColumnShift++;
      updates[CellAddress(dateHeaderCell.row, categoryColumn)] = context.category.name;
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

  int _calculateTotalDuration(int row, _Context context) {
    int result = 0;
    context.sheetInfo.columns.forEach((column, address) {
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

  int _calculateNewColumn(_Context context) {
    int currentMax = -1;
    for (final address in context.sheetInfo.columns.values) {
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
}

class _Context {
  final int durationToStore;
  final GoogleFile file;
  final Category category;
  final SheetsApi api;
  final GoogleSheetInfo sheetInfo;

  _Context(
      {required this.durationToStore,
      required this.file,
      required this.category,
      required this.api,
      required this.sheetInfo});
}
