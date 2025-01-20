import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'log_state.g.dart';

@Riverpod(keepAlive: true)
class LogStateManager extends _$LogStateManager {

  static const _maxLogRecords = 100;

  @override
  List<String> build() {
    return [];
  }

  void onLogRecord(String record) {
    final newLogRecords = List.of(state);
    if (newLogRecords.length >= _maxLogRecords) {
      newLogRecords.removeLast();
    }
    newLogRecords.insert(0, record);
    state = newLogRecords;
  }

  void clear() {
    if (state.isNotEmpty) {
      state = [];
    }
  }
}