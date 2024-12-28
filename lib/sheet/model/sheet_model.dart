import 'package:intl/intl.dart';

import '../util/date_util.dart';

class Column {
  static const date = "Date";
  static const total = "Total Duration (minutes)";
}

class CellAddress {
  final int row;
  final int column;

  const CellAddress(this.row, this.column);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellAddress && runtimeType == other.runtimeType && row == other.row && column == other.column;

  @override
  int get hashCode => row.hashCode ^ column.hashCode;

  @override
  String toString() {
    return "[$row:$column]";
  }
}

class GoogleSheetInfo {

  static GoogleSheetInfo empty = GoogleSheetInfo(dateFormat: defaultDateFormat);

  final int rowsNumber;
  final int columnsNumber;
  final Map<String, CellAddress> columns;
  final Map<CellAddress, String> values;
  final DateFormat dateFormat;
  final int? id;
  final String? title;
  final String? locale;
  final int? todayRow;

  GoogleSheetInfo({
    required this.dateFormat,
    this.rowsNumber = 0,
    this.columnsNumber = 0,
    this.id,
    this.title,
    this.locale,
    this.columns = const {},
    this.values = const {},
    this.todayRow,
  });

  GoogleSheetInfo copyWith({
    int? rowsNumber,
    int? columnsNumber,
    Map<String, CellAddress>? columns,
    Map<CellAddress, String>? values,
    DateFormat? dateFormat,
    int? id,
    String? title,
    String? locale,
    int? todayRow
  }) {
    return GoogleSheetInfo(
      rowsNumber: rowsNumber ?? this.rowsNumber,
      columnsNumber: columnsNumber ?? this.columnsNumber,
      columns: columns ?? this.columns,
      values: values ?? this.values,
      dateFormat: dateFormat ?? this.dateFormat,
      id: id ?? this.id,
      title: title ?? this.title,
      locale: locale ?? this.locale,
      todayRow: todayRow ?? this.todayRow,
    );
  }

  void onRowsInserted(int rowToInsertAfter, int rowsCount) {
    final newColumns = columns.map((column, address) {
      if (address.row > rowToInsertAfter) {
        return MapEntry(column, CellAddress(address.row + rowsCount, address.column));
      } else {
        return MapEntry(column, address);
      }
    });
    columns.clear();
    columns.addAll(newColumns);

    final newValues = values.map((address, value) {
      if (address.row > rowToInsertAfter) {
        return MapEntry(CellAddress(address.row + rowsCount, address.column), value);
      } else {
        return MapEntry(address, value);
      }
    });
    values.clear();
    values.addAll(newValues);
  }
}