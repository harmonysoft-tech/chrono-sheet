// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_sheet_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(googleSheetService)
const googleSheetServiceProvider = GoogleSheetServiceProvider._();

final class GoogleSheetServiceProvider
    extends
        $FunctionalProvider<
          GoogleSheetService,
          GoogleSheetService,
          GoogleSheetService
        >
    with $Provider<GoogleSheetService> {
  const GoogleSheetServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleSheetServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleSheetServiceHash();

  @$internal
  @override
  $ProviderElement<GoogleSheetService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GoogleSheetService create(Ref ref) {
    return googleSheetService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoogleSheetService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoogleSheetService>(value),
    );
  }
}

String _$googleSheetServiceHash() =>
    r'0d0ea683b679237fb9b52351eea3ba9784cedbd9';
