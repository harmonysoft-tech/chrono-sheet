import 'package:chrono_sheet/measurement/service/stop_watch_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../google/sheet/service/google_sheet_updater.dart';

part "stop_watch_controls_ui_state.g.dart";

class StopWatchControlsUiState {
  final StopWatchResetState reset;
  final StopWatchPlayPauseState playPause;
  final StopWatchRecordState record;

  StopWatchControlsUiState({
    required this.reset,
    required this.playPause,
    required this.record,
  });
}

class StopWatchResetState {
  final void Function()? onPressed;
  final bool active;

  StopWatchResetState({
    required this.onPressed,
    required this.active,
  });
}

class StopWatchPlayPauseState {
  final void Function()? onPressed;
  final bool running;

  StopWatchPlayPauseState({
    required this.onPressed,
    required this.running,
  });
}

class StopWatchRecordState {
  final Future<SaveMeasurementState> Function()? onPressed;
  final bool active;

  StopWatchRecordState({
    required this.onPressed,
    required this.active,
  });
}

@riverpod
class StopWatchControlUiStateManager extends _$StopWatchControlUiStateManager {
  @override
  StopWatchControlsUiState build() {
    final state = ref.watch(stopWatchServiceProvider);
    final service = ref.read(stopWatchServiceProvider.notifier);
    return StopWatchControlsUiState(
      reset: _buildResetState(state, service),
      playPause: _buildPlayPauseState(state, service),
      record: _buildRecordState(state, service),
    );
  }

  StopWatchResetState _buildResetState(StopWatchState state, StopWatchService service) {
    final active = state.running || service.hasMeasurement();
    return StopWatchResetState(
      onPressed: service.hasMeasurement() ? service.reset : null,
      active: active,
    );
  }

  StopWatchPlayPauseState _buildPlayPauseState(StopWatchState state, StopWatchService service) {
    return StopWatchPlayPauseState(
      onPressed: () => ref.read(stopWatchServiceProvider.notifier).toggle(),
      running: state.running,
    );
  }

  StopWatchRecordState _buildRecordState(StopWatchState state, StopWatchService service) {
    return StopWatchRecordState(
      onPressed: service.hasMeasurement() ? service.saveMeasurement : null,
      active: service.hasMeasurement(),
    );
  }
}
