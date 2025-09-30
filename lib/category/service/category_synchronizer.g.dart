// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_synchronizer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(categoryManager)
const categoryManagerProvider = CategoryManagerProvider._();

final class CategoryManagerProvider
    extends
        $FunctionalProvider<
          CategorySynchronizer,
          CategorySynchronizer,
          CategorySynchronizer
        >
    with $Provider<CategorySynchronizer> {
  const CategoryManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryManagerHash();

  @$internal
  @override
  $ProviderElement<CategorySynchronizer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategorySynchronizer create(Ref ref) {
    return categoryManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategorySynchronizer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategorySynchronizer>(value),
    );
  }
}

String _$categoryManagerHash() => r'a30669a18134b384d9bcb705f16e2240e885685d';
