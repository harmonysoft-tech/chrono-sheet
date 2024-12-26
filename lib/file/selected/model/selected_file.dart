import 'package:chrono_sheet/logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../model/google_file.dart';

part 'selected_file.g.dart';

final _logger = getNamedLogger();

@riverpod
class SelectedFile extends _$SelectedFile {
  @override
  GoogleFile? build() {
    return null;
  }

  void select(GoogleFile file) {
    _logger.info("file '${file.name}' is now active");
    state = file;
  }
}