// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop_watch_controls_ui_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StopWatchControlUiStateManager)
const stopWatchControlUiStateManagerProvider =
    StopWatchControlUiStateManagerProvider._();

final class StopWatchControlUiStateManagerProvider
    extends
        $NotifierProvider<
          StopWatchControlUiStateManager,
          StopWatchControlsUiState
        > {
  const StopWatchControlUiStateManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stopWatchControlUiStateManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stopWatchControlUiStateManagerHash();

  @$internal
  @override
  StopWatchControlUiStateManager create() => StopWatchControlUiStateManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StopWatchControlsUiState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StopWatchControlsUiState>(value),
    );
  }
}

String _$stopWatchControlUiStateManagerHash() =>
    r'8ca62689fa9031a9f8cf5a3419c7dad98d145410';

abstract class _$StopWatchControlUiStateManager
    extends $Notifier<StopWatchControlsUiState> {
  StopWatchControlsUiState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<StopWatchControlsUiState, StopWatchControlsUiState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StopWatchControlsUiState, StopWatchControlsUiState>,
              StopWatchControlsUiState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
