import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'measurement_state.g.dart';

@riverpod
class MeasurementState extends _$MeasurementState {

  final Duration duration = Duration.zero;

  @override
  MeasurementState build() {
    return this;
  }
}