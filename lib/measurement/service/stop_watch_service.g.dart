// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop_watch_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StopWatchService)
const stopWatchServiceProvider = StopWatchServiceProvider._();

final class StopWatchServiceProvider
    extends $NotifierProvider<StopWatchService, StopWatchState> {
  const StopWatchServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stopWatchServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stopWatchServiceHash();

  @$internal
  @override
  StopWatchService create() => StopWatchService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StopWatchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StopWatchState>(value),
    );
  }
}

String _$stopWatchServiceHash() => r'c6639c8835ddcf9efed9e3434f6b9752a827c38f';

abstract class _$StopWatchService extends $Notifier<StopWatchState> {
  StopWatchState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<StopWatchState, StopWatchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StopWatchState, StopWatchState>,
              StopWatchState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
