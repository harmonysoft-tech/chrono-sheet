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
  final Map<String, String> columns; // TODO implement switch values to CellAddress
  final DateFormat dateFormat;
  final int? id;
  final String? title;
  final String? locale;
  final String? todayRow; // TODO switch to int

  GoogleSheetInfo({
    required this.dateFormat,
    this.rowsNumber = 0,
    this.columnsNumber = 0,
    this.id,
    this.title,
    this.locale,
    this.columns = const <String, String>{},
    this.todayRow,
  });

  GoogleSheetInfo copyWith({
    int? rowsNumber,
    int? columnsNumber,
    Map<String, String>? columns,
    DateFormat? dateFormat,
    int? id,
    String? title,
    String? locale,
    String? todayRow
  }) {
    return GoogleSheetInfo(
      rowsNumber: rowsNumber ?? this.rowsNumber,
      columnsNumber: columnsNumber ?? this.columnsNumber,
      columns: columns ?? this.columns,
      dateFormat: dateFormat ?? this.dateFormat,
      id: id ?? this.id,
      title: title ?? this.title,
      locale: locale ?? this.locale,
      todayRow: todayRow ?? this.todayRow,
    );
  }
}