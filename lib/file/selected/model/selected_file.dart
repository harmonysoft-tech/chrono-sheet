import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../model/google_file.dart';

part 'selected_file.g.dart';

@riverpod
class SelectedFile extends _$SelectedFile {
  @override
  GoogleFile? build() {
    return null;
  }

  void select(GoogleFile file) {
    state = file;
  }
}