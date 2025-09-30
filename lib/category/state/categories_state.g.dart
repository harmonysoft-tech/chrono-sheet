// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categories_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CategoriesStateManager)
const categoriesStateManagerProvider = CategoriesStateManagerProvider._();

final class CategoriesStateManagerProvider
    extends $AsyncNotifierProvider<CategoriesStateManager, CategoriesState> {
  const CategoriesStateManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoriesStateManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoriesStateManagerHash();

  @$internal
  @override
  CategoriesStateManager create() => CategoriesStateManager();
}

String _$categoriesStateManagerHash() =>
    r'2af5aa74e391e814d7c6054e4a7f5d8a31c06044';

abstract class _$CategoriesStateManager
    extends $AsyncNotifier<CategoriesState> {
  FutureOr<CategoriesState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<CategoriesState>, CategoriesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CategoriesState>, CategoriesState>,
              AsyncValue<CategoriesState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
