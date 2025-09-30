// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_drive_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(googleDriveService)
const googleDriveServiceProvider = GoogleDriveServiceProvider._();

final class GoogleDriveServiceProvider
    extends
        $FunctionalProvider<
          GoogleDriveService,
          GoogleDriveService,
          GoogleDriveService
        >
    with $Provider<GoogleDriveService> {
  const GoogleDriveServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleDriveServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleDriveServiceHash();

  @$internal
  @override
  $ProviderElement<GoogleDriveService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GoogleDriveService create(Ref ref) {
    return googleDriveService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoogleDriveService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoogleDriveService>(value),
    );
  }
}

String _$googleDriveServiceHash() =>
    r'4ac9e7215550e5da5879b9e0c5f1cdd6ee4a1160';
