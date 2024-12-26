import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'measurement_state.g.dart';

@riverpod
class MeasurementState extends _$MeasurementState {

  @override
  Duration build() {
    return Duration.zero;
  }

  void increment(Duration diff) {
    state = state + diff;
  }

  void reset() => state = Duration.zero;
}