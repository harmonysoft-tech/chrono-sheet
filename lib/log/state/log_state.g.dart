// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LogStateManager)
const logStateManagerProvider = LogStateManagerProvider._();

final class LogStateManagerProvider
    extends $NotifierProvider<LogStateManager, List<String>> {
  const LogStateManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logStateManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logStateManagerHash();

  @$internal
  @override
  LogStateManager create() => LogStateManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$logStateManagerHash() => r'd05feab14ece36fc55768b1cce61c358e4aa95d4';

abstract class _$LogStateManager extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>, List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
