import 'package:intl/intl.dart';

final fallbackDateFormat = DateFormat("yyyy-MM-dd");

final ClockProvider clockProvider = ClockProviderImpl();
DateTime? _overrideForNow;

List<DateFormat> getDateFormats(String? locale) {
  final result = [fallbackDateFormat];
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

abstract interface class ClockProvider {
  DateTime now();
}

class ClockProviderImpl implements ClockProvider {

  @override
  DateTime now() {
    return _overrideForNow ?? DateTime.now();
  }
}

void overrideNow(DateTime now) {
  _overrideForNow = now;
}

void reset() {
  _overrideForNow = null;
}