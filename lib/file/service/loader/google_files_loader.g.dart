// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_files_loader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GoogleFilesLoader)
const googleFilesLoaderProvider = GoogleFilesLoaderProvider._();

final class GoogleFilesLoaderProvider
    extends $NotifierProvider<GoogleFilesLoader, PaginatedFilesState> {
  const GoogleFilesLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleFilesLoaderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleFilesLoaderHash();

  @$internal
  @override
  GoogleFilesLoader create() => GoogleFilesLoader();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaginatedFilesState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaginatedFilesState>(value),
    );
  }
}

String _$googleFilesLoaderHash() => r'b6a97c692e9cdc65ffbb105d4e347ed044d6529e';

abstract class _$GoogleFilesLoader extends $Notifier<PaginatedFilesState> {
  PaginatedFilesState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PaginatedFilesState, PaginatedFilesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PaginatedFilesState, PaginatedFilesState>,
              PaginatedFilesState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
