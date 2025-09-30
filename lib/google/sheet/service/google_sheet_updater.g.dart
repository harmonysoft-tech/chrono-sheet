// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_sheet_updater.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SheetUpdater)
const sheetUpdaterProvider = SheetUpdaterProvider._();

final class SheetUpdaterProvider
    extends $NotifierProvider<SheetUpdater, SaveMeasurementState> {
  const SheetUpdaterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sheetUpdaterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sheetUpdaterHash();

  @$internal
  @override
  SheetUpdater create() => SheetUpdater();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveMeasurementState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveMeasurementState>(value),
    );
  }
}

String _$sheetUpdaterHash() => r'f25c38b2ca7cbd2af033c8ff776b35dcd0330018';

abstract class _$SheetUpdater extends $Notifier<SaveMeasurementState> {
  SaveMeasurementState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SaveMeasurementState, SaveMeasurementState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SaveMeasurementState, SaveMeasurementState>,
              SaveMeasurementState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
