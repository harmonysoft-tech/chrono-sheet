// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_http_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GoogleHttpClient)
const googleHttpClientProvider = GoogleHttpClientProvider._();

final class GoogleHttpClientProvider
    extends $AsyncNotifierProvider<GoogleHttpClient, http.Client?> {
  const GoogleHttpClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleHttpClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleHttpClientHash();

  @$internal
  @override
  GoogleHttpClient create() => GoogleHttpClient();
}

String _$googleHttpClientHash() => r'bf7277f86d3d42dbd3c7ac96379b33e04161f56f';

abstract class _$GoogleHttpClient extends $AsyncNotifier<http.Client?> {
  FutureOr<http.Client?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<http.Client?>, http.Client?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<http.Client?>, http.Client?>,
              AsyncValue<http.Client?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
