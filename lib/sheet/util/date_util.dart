import 'package:intl/intl.dart';

final defaultDateFormat = DateFormat("yyyy-MM-dd");

List<DateFormat> getDateFormats(String? locale) {
  final result = [defaultDateFormat];
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