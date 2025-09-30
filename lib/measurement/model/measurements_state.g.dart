// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurements_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Measurements)
const measurementsProvider = MeasurementsProvider._();

final class MeasurementsProvider
    extends $AsyncNotifierProvider<Measurements, List<Measurement>> {
  const MeasurementsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'measurementsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$measurementsHash();

  @$internal
  @override
  Measurements create() => Measurements();
}

String _$measurementsHash() => r'ca1803f1cc231f7b00ffc1cfd0a504b00e25dcaf';

abstract class _$Measurements extends $AsyncNotifier<List<Measurement>> {
  FutureOr<List<Measurement>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<Measurement>>, List<Measurement>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Measurement>>, List<Measurement>>,
              AsyncValue<List<Measurement>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
