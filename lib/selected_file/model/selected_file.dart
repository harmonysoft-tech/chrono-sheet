import 'package:googleapis/drive/v3.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_file.g.dart';

@riverpod
class SelectedFile extends _$SelectedFile {
  @override
  File? build() {
    return null;
  }

  void select(File file) {
    state = file;
  }
}