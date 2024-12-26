import 'package:chrono_sheet/file/model/google_file.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../logging/logging.dart';

part 'files_state.g.dart';

final _logger = getNamedLogger();

class FilesInfo {

  final GoogleFile? selected;
  final List<GoogleFile> recent;

  const FilesInfo(this.selected, [this.recent = const []]);
}

@riverpod
class FilesInfoHolder extends _$FilesInfoHolder {
  @override
  FilesInfo build() {
    return FilesInfo(null);
  }

  void select(GoogleFile file) {
    _logger.info("file '${file.name}' is now active");
    List<GoogleFile> recent = List.from(state.recent);
    recent.removeWhere((recentFile) => recentFile.id == file.id);
    state = FilesInfo(file, recent);
  }
}