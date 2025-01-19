import '../../log/util/log_util.dart';
import '../model/sheet_model.dart';

final _logger = getNamedLogger();

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