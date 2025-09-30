// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_identity_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GoogleIdentity)
const googleIdentityProvider = GoogleIdentityProvider._();

final class GoogleIdentityProvider
    extends $AsyncNotifierProvider<GoogleIdentity, AppGoogleIdentity?> {
  const GoogleIdentityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'googleIdentityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$googleIdentityHash();

  @$internal
  @override
  GoogleIdentity create() => GoogleIdentity();
}

String _$googleIdentityHash() => r'fbce667659decd568984e92c5e25b9a6ef0ce4f2';

abstract class _$GoogleIdentity extends $AsyncNotifier<AppGoogleIdentity?> {
  FutureOr<AppGoogleIdentity?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<AppGoogleIdentity?>, AppGoogleIdentity?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppGoogleIdentity?>, AppGoogleIdentity?>,
              AsyncValue<AppGoogleIdentity?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
