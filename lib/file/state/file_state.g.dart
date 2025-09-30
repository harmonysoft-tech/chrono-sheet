// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FileStateManager)
const fileStateManagerProvider = FileStateManagerProvider._();

final class FileStateManagerProvider
    extends $AsyncNotifierProvider<FileStateManager, FileState> {
  const FileStateManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileStateManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileStateManagerHash();

  @$internal
  @override
  FileStateManager create() => FileStateManager();
}

String _$fileStateManagerHash() => r'3c4c1c013a5aaff1bc5c351b8d5e836daff03f39';

abstract class _$FileStateManager extends $AsyncNotifier<FileState> {
  FutureOr<FileState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<FileState>, FileState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FileState>, FileState>,
              AsyncValue<FileState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
