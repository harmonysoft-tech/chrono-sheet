// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main_hint_positions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HintPositions)
const hintPositionsProvider = HintPositionsProvider._();

final class HintPositionsProvider
    extends $NotifierProvider<HintPositions, HintPositionsState> {
  const HintPositionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hintPositionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hintPositionsHash();

  @$internal
  @override
  HintPositions create() => HintPositions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HintPositionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HintPositionsState>(value),
    );
  }
}

String _$hintPositionsHash() => r'a225ae2ebd3097e1169651dc5e63cf30ea00b0b7';

abstract class _$HintPositions extends $Notifier<HintPositionsState> {
  HintPositionsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<HintPositionsState, HintPositionsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HintPositionsState, HintPositionsState>,
              HintPositionsState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
