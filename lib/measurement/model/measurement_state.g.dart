// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurement_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MeasurementState)
const measurementStateProvider = MeasurementStateProvider._();

final class MeasurementStateProvider
    extends $NotifierProvider<MeasurementState, Duration> {
  const MeasurementStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'measurementStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$measurementStateHash();

  @$internal
  @override
  MeasurementState create() => MeasurementState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Duration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Duration>(value),
    );
  }
}

String _$measurementStateHash() => r'93c4accd49e47fa46cfee58816e9ed275e5b7d85';

abstract class _$MeasurementState extends $Notifier<Duration> {
  Duration build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Duration, Duration>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Duration, Duration>,
              Duration,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
