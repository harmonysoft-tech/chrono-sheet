import 'package:chrono_sheet/log/util/log_util.dart';
import 'package:chrono_sheet/measurement/model/measurement.dart';
import 'package:chrono_sheet/util/date_util.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../category/model/category.dart';
import '../../file/model/google_file.dart';

part "measurements_state.g.dart";

final _logger = getNamedLogger();
final _daysToKeepHistory = 7;

class _Key {
  static const first = "measurements.firstIndex";
  static const count = "measurements.count";

  static getId(int i) {
    return "measurements.$i.id";
  }

  static getFilePrefix(int i) {
    return "measurements.$i.file";
  }

  static getCategory(int i) {
    return "measurements.$i.category";
  }

  static getDuration(int i) {
    return "measurements.$i.duration";
  }

  static getSaved(int i) {
    return "measurements.$i.saved";
  }

  static getTime(int i) {
    return "measurements.$i.time";
  }
}

@Riverpod(keepAlive: true)
class Measurements extends _$Measurements {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<List<Measurement>> build() async {
    return _readCachedMeasurements();
  }

  Future<List<Measurement>> _readCachedMeasurements() async {
    int? first = await _prefs.getInt(_Key.first);
    if (first == null) {
      return [];
    }
    int? count = await _prefs.getInt(_Key.count);
    if (count == null) {
      return [];
    }

    List<Measurement> result = [];
    for (int i = first; i < first + count; i++) {
      final measurement = await _readCachedMeasurement(i);
      if (measurement == null) {
        break;
      }
      result.add(measurement);
    }
    _logger.info("loaded ${result.length} cached measurements");
    return result;
  }

  Future<Measurement?> _readCachedMeasurement(int i) async {
    final id = await _prefs.getString(_Key.getId(i));
    if (id == null) {
      return null;
    }
    final categoryName = await _prefs.getString(_Key.getCategory(i));
    if (categoryName == null) {
      return null;
    }
    final durationSeconds = await _prefs.getInt(_Key.getDuration(i));
    if (durationSeconds == null) {
      return null;
    }
    final saved = await _prefs.getBool(_Key.getSaved(i));
    if (saved == null) {
      return null;
    }
    final time = await _prefs.getString(_Key.getTime(i));
    if (time == null) {
      return null;
    }
    final file = await GoogleFile.readFromPrefs(_Key.getFilePrefix(i), _prefs);
    if (file == null) {
      return null;
    }
    var result = Measurement(
        id: id,
        time: DateTime.parse(time),
        file: file,
        category: Category(categoryName),
        durationSeconds: durationSeconds,
        saved: saved);
    _logger.info("loaded cached measurement from index $i: $result");
    return result;
  }

  Future<void> save(Measurement measurement) async {
    return _save(measurement, false);
  }

  Future<void> _save(Measurement measurement, bool nested) async {
    int? first = await _prefs.getInt(_Key.first);
    if (first == null) {
      await _doSave(measurement, 0);
      await _prefs.setInt(_Key.first, 0);
      await _prefs.setInt(_Key.count, 1);
      state = AsyncValue.data([measurement]);
      return;
    }
    int? count = await _prefs.getInt(_Key.count);
    if (count == null) {
      await _doSave(measurement, 0);
      await _prefs.setInt(_Key.first, 0);
      await _prefs.setInt(_Key.count, 1);
      state = AsyncValue.data([measurement]);
      return;
    }
    if (!nested && count + 1 < 0) {
      await _defragmentRecords(first, count);
      return _save(measurement, true);
    }

    int newFirst = await _dropOldSavedRecords(first, count);
    int newCount = count - (newFirst - first);
    await _doSave(measurement, newFirst + newCount);
    newCount++;
    await _prefs.setInt(_Key.first, newFirst);
    await _prefs.setInt(_Key.count, newCount);
    final newMeasurements = await _readCachedMeasurements();
    state = AsyncValue.data(newMeasurements);
  }

  Future<void> _doSave(Measurement measurement, int i) async {
    await _prefs.setString(_Key.getId(i), measurement.id);
    await _prefs.setString(_Key.getCategory(i), measurement.category.name);
    await _prefs.setInt(_Key.getDuration(i), measurement.durationSeconds);
    await _prefs.setBool(_Key.getSaved(i), measurement.saved);
    await _prefs.setString(_Key.getTime(i), measurement.time.toIso8601String());
    await measurement.file.storeInPrefs(_Key.getFilePrefix(i), _prefs);
    _logger.info("cached measurement $measurement under index $i");
  }

  Future<void> _defragmentRecords(int first, int count) async {
    int firstIndexToKeep = first;
    while (firstIndexToKeep - first < count) {
      final measurement = await _readCachedMeasurement(firstIndexToKeep);
      if (measurement == null || !measurement.saved) {
        break;
      }
    }
    if (firstIndexToKeep <= 0) {
      _logger.info("can not defragment cached measurements records, first=$first, count=$count");
      return;
    }
    int recordsToMove = count - (firstIndexToKeep - first);
    _logger.info("shifting $recordsToMove cached measurement records backwards to defragment them");
    int toIndex = 0;
    int fromIndex = firstIndexToKeep;
    while (--recordsToMove >= 0) {
      final measurement = await _readCachedMeasurement(fromIndex++);
      if (measurement == null) {
        _logger.warning("there should be a cached measurement record at index ${fromIndex - 1}, but there was no");
      } else {
        await _doSave(measurement, toIndex++);
      }
    }
    await _prefs.setInt(_Key.first, 0);
    await _prefs.setInt(_Key.count, toIndex);
    _logger.info("finished cached measurements defragmentation, keeping $toIndex records");
  }

  Future<int> _dropOldSavedRecords(int first, int count) async {
    if (count <= 0) {
      return first;
    }
    final now = DateTime.now();
    final beginningOfToday = getBeginningOfTheDay(now);
    final cutOffDate = beginningOfToday.subtract(Duration(days: _daysToKeepHistory));
    for (int i = first; i - first < count; i++) {
      final measurement = await _readCachedMeasurement(i);
      if (measurement == null) {
        continue;
      }
      if (measurement.time.isBefore(cutOffDate)) {
        continue;
      }
      _logger.info("dropped ${i - first} historical cached measurements by moving the first index from $first to $i. "
          "First measurement to keep: $measurement");
      return i;
    }
    return first + count;
  }

  Future<void> onSaved(Measurement measurement) async {
    _logger.info("got a request to mark measurement as saved: $measurement");
    int? first = await _prefs.getInt(_Key.first);
    if (first == null) {
      _logger.warning("cannot mark measurement as saved - no 'first' marker is stored ($measurement)");
      return;
    }
    int? count = await _prefs.getInt(_Key.count);
    if (count == null) {
      _logger.warning("cannot mark measurement as saved - no 'count' marker is stored ($measurement)");
      return;
    }
    for (int i = first + count - 1; i >= first; i--) {
      final storedMeasurement = await _readCachedMeasurement(i);
      if (storedMeasurement == null) {
        _logger.warning("detected an unexpected situation on attempt to set measurement as saved ($measurement) - "
            "cached measurement should be available in range first=$first, count=$count, but there is no "
            "measurement at index $i");
        continue;
      }
      if (storedMeasurement.id == measurement.id) {
        await _doSave(storedMeasurement.copyWith(saved: true), i);
        _logger.info("updated cached measurement ${measurement.id} as saved");
        final newState = await _readCachedMeasurements();
        state = AsyncValue.data(newState);
        return;
      }
    }
    _logger.severe("cannot update measurement ${measurement.id} as saved - target measurement is not found "
        "in range first=$first, count=$count. Measurement: $measurement");
  }
}
